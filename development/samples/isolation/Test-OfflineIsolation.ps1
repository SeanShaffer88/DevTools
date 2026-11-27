[CmdletBinding()]
param([Parameter(Mandatory)][string]$WorkDirectory,[switch]$UseDriveAlias)
$ErrorActionPreference='Stop'
$directory=[IO.Path]::GetFullPath($WorkDirectory)
if (Test-Path -LiteralPath $directory) {throw 'Test directory must be new.'}
$parent=Split-Path -Parent $directory
if (!(Test-Path -LiteralPath $parent -PathType Container)) {throw 'Test parent must exist.'}
[IO.Directory]::CreateDirectory($directory)|Out-Null
$root=Join-Path $directory 'owned'
& (Join-Path $PSScriptRoot 'Initialize-OfflineRoot.ps1') -Path $root | Out-Null
$tools=Join-Path $root 'tools';$work=Join-Path $root 'work'
New-Item -ItemType Directory -Path $tools,$work|Out-Null
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (!(Test-Path -LiteralPath $compiler)) {throw 'The host .NET Framework bootstrap compiler is missing.'}
$probe=Join-Path $tools 'NetworkProbe.exe'
& $compiler /nologo ("/out:"+$probe) (Join-Path $PSScriptRoot 'NetworkProbe.cs') 1> (Join-Path $directory 'compile.stdout.txt') 2> (Join-Path $directory 'compile.stderr.txt')
if ($LASTEXITCODE -ne 0) {throw "Canary bootstrap compilation failed: $LASTEXITCODE"}
$beforeAcl=@{};foreach($path in @($root,$tools,$work,$probe)){$beforeAcl[$path]=(Get-Acl -LiteralPath $path).Sddl}
$listener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0)
$listener.Start()
function Receive-Control {
    if (!$listener.Pending()) {throw 'Control connection did not reach the live listener.'}
    $client=$listener.AcceptTcpClient()
    try {$client.ReceiveTimeout=3000;$buffer=[byte[]]::new(256);$count=$client.GetStream().Read($buffer,0,$buffer.Length);[Text.Encoding]::UTF8.GetString($buffer,0,$count)} finally {$client.Dispose()}
}
try {
    $port=$listener.LocalEndpoint.Port
    $nonce=[guid]::NewGuid().ToString('N')
    $beforeText=& $probe child $port ('before-'+$nonce)
    if($LASTEXITCODE-ne 0){throw 'Outside-before probe failed.'}
    $before=$beforeText|ConvertFrom-Json
    $beforeReceipt=Receive-Control
    if($before.isAppContainer-or $before.socketError-ne 0-or $beforeReceipt-ne ('child:before-'+$nonce)){throw 'Outside-before control invalid.'}
    $request=@{ownedRoot=$root;executable=$probe;arguments=@('parent',"$port",('inside-'+$nonce));workingDirectory=$work;readOnlyRoots=@($tools);writableRoots=@($work);timeoutSeconds=20;environment=@{USERPROFILE=$work;HOME=$work;APPDATA=$work;LOCALAPPDATA=$work;TEMP=$work;TMP=$work;PATH=(Join-Path $env:WINDIR 'System32')};artifacts=@()}
    if($UseDriveAlias){$request.useDriveAlias=$true}
    $requestPath=Join-Path $directory 'request.json';$resultPath=Join-Path $directory 'result.json'
    $request|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $requestPath -Encoding utf8
    & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Invoke-OfflineProcess.ps1') -Request $requestPath -Result $resultPath
    if($LASTEXITCODE-ne 0){throw 'AppContainer process or cleanup failed.'}
    $result=Get-Content -LiteralPath $resultPath -Raw|ConvertFrom-Json
    $inside=Get-Content -LiteralPath ($resultPath+'.stdout.txt') -Raw|ConvertFrom-Json
    $unexpected=$listener.Pending()
    $afterText=& $probe child $port ('after-'+$nonce)
    if($LASTEXITCODE-ne 0){throw 'Outside-after probe failed.'}
    $after=$afterText|ConvertFrom-Json
    $afterReceipt=Receive-Control
    if($after.isAppContainer-or $after.socketError-ne 0-or $afterReceipt-ne ('child:after-'+$nonce)){throw 'Outside-after control invalid.'}
    foreach($actual in @($inside,$inside.child)) {
        if(!$actual.isAppContainer-or $actual.capabilityCount-ne 0-or (!$actual.connectTimedOut-and $actual.socketError-notin @(10013,10060))){throw 'Inside token or connection-denial invariant failed.'}
    }
    if($unexpected-or $listener.Pending()){throw 'Unexpected inside/child listener connection.'}
    $changedAcls=@(foreach($path in $beforeAcl.Keys){if((Get-Acl -LiteralPath $path).Sddl-ne $beforeAcl[$path]){$path}})
    if($changedAcls.Count){throw 'Scoped ACLs were not restored.'}
    $report=@{valid=$true;outsideBefore=$before;outsideBeforeReceipt=$beforeReceipt;inside=$inside;outsideAfter=$after;outsideAfterReceipt=$afterReceipt;insideListenerConnections=0;runnerResult=$result;aclSnapshotsRestored=$true;bootstrapCompiler=$compiler;bootstrapCompilerSha256=(Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash;probeSha256=(Get-FileHash -LiteralPath $probe -Algorithm SHA256).Hash}
    $report|ConvertTo-Json -Depth 12|Set-Content -LiteralPath (Join-Path $directory 'proof.json') -Encoding utf8
    $report|ConvertTo-Json -Depth 12
} finally {$listener.Stop()}
