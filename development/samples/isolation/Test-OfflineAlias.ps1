[CmdletBinding()]
param([Parameter(Mandatory)][string]$WorkDirectory)
$ErrorActionPreference='Stop'
$directory=[IO.Path]::GetFullPath($WorkDirectory)
if(Test-Path -LiteralPath $directory){throw 'Alias test directory must be new.'}
if(!(Test-Path -LiteralPath (Split-Path -Parent $directory) -PathType Container)){throw 'Test parent missing.'}
[IO.Directory]::CreateDirectory($directory)|Out-Null
$reservedRoot=Join-Path $directory 'reserved';$root=Join-Path $directory 'owned'
& (Join-Path $PSScriptRoot 'Initialize-OfflineRoot.ps1') -Path $reservedRoot|Out-Null
& (Join-Path $PSScriptRoot 'Initialize-OfflineRoot.ps1') -Path $root|Out-Null
$tools=Join-Path $root 'tools';$work=Join-Path $root 'work'
New-Item -ItemType Directory -Path $tools,$work|Out-Null
$probe=Join-Path $tools 'NetworkProbe.exe'
& (Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe') /nologo ("/out:"+$probe) (Join-Path $PSScriptRoot 'NetworkProbe.cs')
if($LASTEXITCODE-ne 0){throw 'Probe compile failed.'}
if(!('OfflineNative'-as[type])){Add-Type -Path (Join-Path $PSScriptRoot 'OfflineNative.cs')}
$reservedLock=[IO.File]::Open((Join-Path $reservedRoot '.devtools-offline.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
$reservedAlias=$null
try {
    $reservedAlias=[OfflineNative]::CreateDriveAlias($reservedRoot)
    $reservedTarget=@([OfflineNative]::DriveTargets($reservedAlias))
    $request=@{ownedRoot=$root;executable=$probe;arguments=@('echo','0',(Join-Path $work 'path with spaces.txt'));workingDirectory=$work;readOnlyRoots=@($tools);writableRoots=@($work);timeoutSeconds=10;useDriveAlias=$true;environment=@{USERPROFILE=$work;APPDATA=$work;LOCALAPPDATA=$work;TEMP=$work;TMP=$work;PATH=(Join-Path $env:WINDIR 'System32')};artifacts=@()}
    $requestPath=Join-Path $directory 'request.json';$resultPath=Join-Path $directory 'result.json'
    $request|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $requestPath
    & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Invoke-OfflineProcess.ps1') -Request $requestPath -Result $resultPath
    if($LASTEXITCODE-ne 0){throw 'Alias run failed.'}
    $result=Get-Content -LiteralPath $resultPath -Raw|ConvertFrom-Json
    if(!$result.driveAliasRemoved-or $result.driveAlias.TrimEnd('\')-eq $reservedAlias){throw 'Existing drive was reused or cleanup failed.'}
    $actual=Get-Content -LiteralPath ($resultPath+'.stdout.txt') -Raw|ConvertFrom-Json
    $argument=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($actual.argumentBase64))
    if($argument-ne ($result.driveAlias+'work\path with spaces.txt')){throw 'Declared path argument was not mapped.'}
    if(@([OfflineNative]::DriveTargets($result.driveAlias.TrimEnd('\'))).Count){throw 'Runner alias remains.'}
    $reservedAfter=@([OfflineNative]::DriveTargets($reservedAlias))
    if($reservedAfter.Count-ne 1-or $reservedAfter[0]-ne $reservedTarget[0]){throw 'Existing mapping changed.'}
    $request.arguments=@('hang','0','unused');$request.timeoutSeconds=2
    $request|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $requestPath
    $timeoutPath=Join-Path $directory 'timeout.json'
    & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Invoke-OfflineProcess.ps1') -Request $requestPath -Result $timeoutPath
    if($LASTEXITCODE-ne 2){throw 'Timeout run must fail.'}
    $timeout=Get-Content -LiteralPath $timeoutPath -Raw|ConvertFrom-Json
    if(!$timeout.driveAliasRemoved-or !$timeout.profileDeleted-or !$timeout.aclSidAbsentRecursively){throw 'Timeout alias cleanup failed.'}
    if(@([OfflineNative]::DriveTargets($timeout.driveAlias.TrimEnd('\'))).Count){throw 'Timed-out alias remains.'}
    $proof=@{valid=$true;reservedMappingPreserved=$true;successAliasRemoved=$true;timeoutAliasRemoved=$true;declaredPathMapped=$true;result=$resultPath;timeoutResult=$timeoutPath}
    $proof|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $directory 'proof.json')
    $proof|ConvertTo-Json
} finally {
    try {if($reservedAlias){[OfflineNative]::RemoveDriveAlias($reservedAlias,$reservedRoot)}} finally {$reservedLock.Dispose()}
}
