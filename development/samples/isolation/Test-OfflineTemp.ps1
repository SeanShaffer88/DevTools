[CmdletBinding()]
param([Parameter(Mandatory)][string]$WorkDirectory,[switch]$WithoutDriveAlias)
$ErrorActionPreference='Stop'
$directory=[IO.Path]::GetFullPath($WorkDirectory)
if(Test-Path -LiteralPath $directory){throw 'Temp test directory must be new.'}
if(!(Test-Path -LiteralPath (Split-Path -Parent $directory) -PathType Container)){throw 'Test parent missing.'}
[IO.Directory]::CreateDirectory($directory)|Out-Null
$root=Join-Path $directory 'owned'
& (Join-Path $PSScriptRoot 'Initialize-OfflineRoot.ps1') -Path $root|Out-Null
$tools=Join-Path $root 'tools';$work=Join-Path $root 'work'
New-Item -ItemType Directory -Path $tools,$work|Out-Null
$probe=Join-Path $tools 'NetworkProbe.exe'
& (Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe') /nologo ("/out:"+$probe) (Join-Path $PSScriptRoot 'NetworkProbe.cs')
if($LASTEXITCODE-ne 0){throw 'Probe compile failed.'}
$config=@{ownedRoot=$root;executable=$probe;arguments=@('temp','0','unused');workingDirectory=$work;readOnlyRoots=@($tools);writableRoots=@($work);timeoutSeconds=10;useDriveAlias=(!$WithoutDriveAlias);environment=@{USERPROFILE=$work;APPDATA=$work;LOCALAPPDATA=$work;TEMP=$work;TMP=$work;PATH=(Join-Path $env:WINDIR 'System32')};artifacts=@()}
$request=Join-Path $directory 'request.json';$resultPath=Join-Path $directory 'result.json'
$config|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $request
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Invoke-OfflineProcess.ps1') -Request $request -Result $resultPath
if($LASTEXITCODE-ne 0){throw 'Native temporary-file test failed.'}
$result=Get-Content -LiteralPath $resultPath -Raw|ConvertFrom-Json
$actual=Get-Content -LiteralPath ($resultPath+'.stdout.txt') -Raw|ConvertFrom-Json
$temp=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($actual.tempPathBase64))
if(!$actual.created-or $actual.error-ne 0-or !$result.shadowProfileRemoved-or (!$WithoutDriveAlias-and !$result.driveAliasRemoved)-or !$result.aclSidAbsentRecursively-or (Test-Path -LiteralPath $result.shadowProfilePath)){throw 'Native temp or cleanup invariant failed.'}
$visibleRoot=if($WithoutDriveAlias){$root+'\'}else{$result.driveAlias}
if(!$temp.StartsWith($visibleRoot+'work\Packages\',[StringComparison]::OrdinalIgnoreCase)){throw 'Unexpected redirected temporary path.'}
$config.arguments=@('hang','0','unused');$config.timeoutSeconds=2
$config|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $request
$timeoutPath=Join-Path $directory 'timeout.json'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Invoke-OfflineProcess.ps1') -Request $request -Result $timeoutPath
if($LASTEXITCODE-ne 2){throw 'Timeout test must fail.'}
$timeout=Get-Content -LiteralPath $timeoutPath -Raw|ConvertFrom-Json
if(!$timeout.shadowProfileRemoved-or !$timeout.profileDeleted-or !$timeout.aclSidAbsentRecursively-or (Test-Path -LiteralPath $timeout.shadowProfilePath)){throw 'Timeout shadow cleanup failed.'}
$invalid=Join-Path $tools 'invalid-loader.exe'
[IO.File]::WriteAllText($invalid,'Original inert loader-failure fixture; not a PE image.')
$config.executable=$invalid;$config.arguments=@();$config.timeoutSeconds=10
$config|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $request
$failurePath=Join-Path $directory 'loader-failure.json'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Invoke-OfflineProcess.ps1') -Request $request -Result $failurePath
if($LASTEXITCODE-ne 2){throw 'Loader failure test must fail.'}
$failure=Get-Content -LiteralPath $failurePath -Raw|ConvertFrom-Json
if(!$failure.shadowProfileRemoved-or !$failure.profileDeleted-or !$failure.aclSidAbsentRecursively-or (Test-Path -LiteralPath $failure.shadowProfilePath)-or $failure.error-notmatch 'Create AppContainer process:.*\((193|216)\)'){throw 'Post-profile loader failure cleanup was not verified.'}
$config.environment.LOCALAPPDATA=$env:LOCALAPPDATA
$config|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $request
$outsidePath=Join-Path $directory 'outside.json'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Invoke-OfflineProcess.ps1') -Request $request -Result $outsidePath 2> (Join-Path $directory 'outside.stderr.txt')
if($LASTEXITCODE-eq 0-or (Test-Path -LiteralPath $outsidePath)){throw 'Outside LOCALAPPDATA was accepted.'}
$proof=@{valid=$true;nativeGetTempFileNameSucceeded=$true;actualTempPath=$temp;successShadowRemoved=$true;timeoutShadowRemoved=$true;loaderFailureShadowRemoved=$true;outsideLocalAppDataRejected=$true;result=$resultPath;timeoutResult=$timeoutPath;loaderFailureResult=$failurePath}
$proof|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $directory 'proof.json')
$proof|ConvertTo-Json
