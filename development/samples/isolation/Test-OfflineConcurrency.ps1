[CmdletBinding()]
param([Parameter(Mandatory)][string]$WorkDirectory)
$ErrorActionPreference='Stop'
$directory=[IO.Path]::GetFullPath($WorkDirectory)
if(Test-Path -LiteralPath $directory){throw 'Concurrency test directory must be new.'}
if(!(Test-Path -LiteralPath (Split-Path -Parent $directory) -PathType Container)){throw 'Test parent must exist.'}
[IO.Directory]::CreateDirectory($directory)|Out-Null
$root=Join-Path $directory 'owned'
& (Join-Path $PSScriptRoot 'Initialize-OfflineRoot.ps1') -Path $root|Out-Null
$tools=Join-Path $root 'tools';$work=Join-Path $root 'work'
New-Item -ItemType Directory -Path $tools,$work|Out-Null
$probe=Join-Path $tools 'NetworkProbe.exe'
& (Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe') /nologo ("/out:"+$probe) (Join-Path $PSScriptRoot 'NetworkProbe.cs')
if($LASTEXITCODE-ne 0){throw 'Probe compile failed.'}
$before=@{};foreach($path in @($root,$tools,$work,$probe)){$before[$path]=(Get-Acl -LiteralPath $path).Sddl}
$config=@{ownedRoot=$root;executable=$probe;arguments=@('hang','0','unused');workingDirectory=$work;readOnlyRoots=@($tools);writableRoots=@($work);timeoutSeconds=8;environment=@{USERPROFILE=$work;APPDATA=$work;LOCALAPPDATA=$work;TEMP=$work;TMP=$work;PATH=(Join-Path $env:WINDIR 'System32')};artifacts=@()}
$request=Join-Path $directory 'request.json';$firstResult=Join-Path $directory 'first.json';$secondResult=Join-Path $directory 'second.json'
$config|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $request
$start=[Diagnostics.ProcessStartInfo]::new((Get-Command pwsh).Source)
$start.UseShellExecute=$false;$start.CreateNoWindow=$true
$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
foreach($arg in @('-NoProfile','-File',(Join-Path $PSScriptRoot 'Invoke-OfflineProcess.ps1'),'-Request',$request,'-Result',$firstResult)){$start.ArgumentList.Add($arg)}
$first=[Diagnostics.Process]::Start($start)
try {
    $wait=[Diagnostics.Stopwatch]::StartNew();$firstLog=$firstResult+'.stdout.txt'
    while(!(Test-Path -LiteralPath $firstLog) -or (Get-Item -LiteralPath $firstLog).Length-eq 0) {
        if($first.HasExited-or $wait.Elapsed.TotalSeconds-gt 15){throw 'First job did not become active.'}
        Start-Sleep -Milliseconds 50
    }
    & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Invoke-OfflineProcess.ps1') -Request $request -Result $secondResult 2> (Join-Path $directory 'second.stderr.txt')
    $secondCode=$LASTEXITCODE
    if($secondCode-eq 0-or (Test-Path -LiteralPath $secondResult)-or (Test-Path -LiteralPath ($secondResult+'.stdout.txt'))){throw 'Overlapping request was not rejected before profile/ACL changes.'}
    if(!$first.WaitForExit(20000)){throw 'First job did not finish its bounded cleanup.'}
    $first.StandardOutput.ReadToEnd()|Set-Content (Join-Path $directory 'first-cli.stdout.txt')
    $first.StandardError.ReadToEnd()|Set-Content (Join-Path $directory 'first-cli.stderr.txt')
    if($first.ExitCode-ne 2){throw 'First timeout was not recorded as failure.'}
    $result=Get-Content -LiteralPath $firstResult -Raw|ConvertFrom-Json
    if(!$result.timedOut-or !$result.descendantsTerminated-or !$result.aclsRestored-or !$result.aclSidAbsentRecursively-or !$result.profileDeleted){throw 'First job cleanup invariant failed.'}
    foreach($path in $before.Keys){if((Get-Acl -LiteralPath $path).Sddl-ne $before[$path]){throw 'Original ACL changed.'}}
    $report=@{valid=$true;overlapRejectedBeforeProfile=$true;secondExitCode=$secondCode;firstExitCode=$first.ExitCode;originalAclsRestored=$true;recursiveSidAbsent=$result.aclSidAbsentRecursively;firstProfileDeleted=$result.profileDeleted;firstResult=$firstResult}
    $report|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $directory 'proof.json')
    $report|ConvertTo-Json
} finally {
    if(!$first.HasExited){$first.WaitForExit(20000)|Out-Null}
    $first.Dispose()
}
