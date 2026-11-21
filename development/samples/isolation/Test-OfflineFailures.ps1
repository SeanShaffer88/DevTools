[CmdletBinding()]
param([Parameter(Mandatory)][string]$WorkDirectory)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath($WorkDirectory)
if(Test-Path -LiteralPath $root){throw 'Failure test directory must be new.'}
$parent=Split-Path -Parent $root
if(!(Test-Path -LiteralPath $parent -PathType Container)){throw 'Test parent missing.'}
[IO.Directory]::CreateDirectory($root)|Out-Null
& (Join-Path $PSScriptRoot 'Initialize-OfflineRoot.ps1') -Path (Join-Path $root 'owned')|Out-Null
$owned=Join-Path $root 'owned';$tools=Join-Path $owned 'tools';$work=Join-Path $owned 'work'
New-Item -ItemType Directory -Path $tools,$work|Out-Null
$probe=Join-Path $tools 'NetworkProbe.exe'
& (Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe') /nologo ("/out:"+$probe) (Join-Path $PSScriptRoot 'NetworkProbe.cs')
if($LASTEXITCODE-ne 0){throw 'Probe compile failed.'}
$config=@{ownedRoot=$owned;executable=$probe;arguments=@('hang','0','unused');workingDirectory=$work;readOnlyRoots=@($tools);writableRoots=@($work);timeoutSeconds=2;environment=@{USERPROFILE=$work;HOME=$work;APPDATA=$work;LOCALAPPDATA=$work;TEMP=$work;TMP=$work;PATH=(Join-Path $env:WINDIR 'System32')};artifacts=@()}
$request=Join-Path $root 'timeout-request.json';$result=Join-Path $root 'timeout-result.json'
$config|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $request
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Invoke-OfflineProcess.ps1') -Request $request -Result $result
if($LASTEXITCODE-ne 2){throw 'Timeout must fail with exit 2.'}
$actual=Get-Content -LiteralPath $result -Raw|ConvertFrom-Json
if(!$actual.timedOut-or !$actual.descendantsTerminated-or !$actual.aclsRestored-or !$actual.profileDeleted){throw 'Timeout cleanup invariant failed.'}
$child=Get-Content -LiteralPath ($result+'.stdout.txt') -Raw|ConvertFrom-Json
if(Get-Process -Id $child.childId -ErrorAction SilentlyContinue){throw 'Timed-out child still exists.'}
$checks=@(@{name='timeout kills descendants and restores ACL/profile';passed=$true})
$expectedArgument='space "quoted" and backslash\ with trailing\\'
$config.arguments=@('echo','0',$expectedArgument);$config.timeoutSeconds=10
$config|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $request
$quoteResult=Join-Path $root 'quote-result.json'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Invoke-OfflineProcess.ps1') -Request $request -Result $quoteResult
if($LASTEXITCODE-ne 0){throw 'Quoted argument run failed.'}
$quoted=Get-Content -LiteralPath ($quoteResult+'.stdout.txt') -Raw|ConvertFrom-Json
if([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($quoted.argumentBase64))-ne $expectedArgument){throw 'Argument quoting changed bytes.'}
$checks+=@{name='native arguments preserve spaces quotes and trailing backslashes';passed=$true}
$config.executable=Join-Path $env:WINDIR 'System32\cmd.exe'
$config|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $request
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Invoke-OfflineProcess.ps1') -Request $request -Result (Join-Path $root 'escape-result.json') 2> (Join-Path $root 'escape.stderr.txt')
if($LASTEXITCODE-eq 0-or (Test-Path -LiteralPath (Join-Path $root 'escape-result.json'))){throw 'Outside executable was accepted.'}
$checks+=@{name='outside executable refused before profile creation';passed=$true}
$outside=Join-Path $root 'outside';New-Item -ItemType Directory -Path $outside|Out-Null
$link=Join-Path $owned 'linked';New-Item -ItemType Junction -Path $link -Target $outside|Out-Null
try {
    $config.executable=$probe;$config.writableRoots=@($link)
    $config|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $request
    & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Invoke-OfflineProcess.ps1') -Request $request -Result (Join-Path $root 'junction-result.json') 2> (Join-Path $root 'junction.stderr.txt')
    if($LASTEXITCODE-eq 0-or (Test-Path -LiteralPath (Join-Path $root 'junction-result.json'))){throw 'Junction was accepted.'}
    $checks+=@{name='junction escape refused before ACL changes';passed=$true}
} finally {[IO.Directory]::Delete($link)}
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Initialize-OfflineRoot.ps1') -Path '\\127.0.0.1\DevTools-Should-Not-Exist\new' 2> (Join-Path $root 'unc.stderr.txt')
if($LASTEXITCODE-eq 0){throw 'UNC initializer was accepted.'}
$checks+=@{name='UNC root refused before directory creation';passed=$true}
$checks|ConvertTo-Json -Depth 4|Set-Content -LiteralPath (Join-Path $root 'checks.json')
$checks|ConvertTo-Json -Depth 4
