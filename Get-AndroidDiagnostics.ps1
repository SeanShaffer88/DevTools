#requires -Version 7.0
<#
.SYNOPSIS
Inspects an APK offline or runs finite diagnostics against one explicitly selected device.
.PARAMETER ApkPath
Literal APK file. Offline inspection preflights at most 50,000 central-directory entries and 32 MiB of central-directory metadata. No extraction or ADB execution.
.PARAMETER DeviceSerial
Explicit ADB serial. Device diagnostics may start the local ADB server.
.PARAMETER PackageName
Optional package ID; logcat is filtered using its running PID(s).
.NOTES
No installation, activity launch, log clearing, signature verification or binary manifest decoding.
JSON/object output; LASTEXITCODE 0 success, 2 invalid input, native command failure, 124 timeout.
#>
[CmdletBinding(DefaultParameterSetName='Apk')]
param(
 [Parameter(Mandatory,ParameterSetName='Apk')][string]$ApkPath,
 [Parameter(Mandatory,ParameterSetName='Device')][string]$DeviceSerial,
 [Parameter(ParameterSetName='Device')][string]$PackageName,
 [Parameter(ParameterSetName='Device')][ValidateRange(1,2000)][int]$LogLines=200,
 [Parameter(ParameterSetName='Device')][string]$AdbPath='adb.exe',
 [Parameter(ParameterSetName='Device')][ValidateRange(1,120)][int]$TimeoutSeconds=15,
 [switch]$Json
)
$ErrorActionPreference='Stop'
$result=[ordered]@{schemaVersion=1;observedUtc=[DateTime]::UtcNow.ToString('o');valid=$false;mode=$PSCmdlet.ParameterSetName;apk=$null;device=$null;error=$null;limitations=@('APK signature and runtime behavior are not verified.','Binary Android manifests are identified, not decoded.')}
$global:LASTEXITCODE=2
try {
 if($PSCmdlet.ParameterSetName -eq 'Apk') {
  $file=Get-Item -LiteralPath $ApkPath -ErrorAction Stop
  if($file.PSIsContainer){throw 'ApkPath must be a file.'}
  if(-not ('LocalDevTools.ApkZipDirectory' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'lib/ApkZipDirectory.cs')}
  $apkStream=[IO.File]::Open($file.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
  $archive=$null
  try {
   [LocalDevTools.ApkZipDirectory]::Validate($apkStream)
   $archive=[IO.Compression.ZipArchive]::new($apkStream,[IO.Compression.ZipArchiveMode]::Read,$true)
   $names=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
   $entries=[Collections.Generic.List[object]]::new();$manifest='Missing';$abis=[Collections.Generic.HashSet[string]]::new();$dex=0;$assets=0
   foreach($entry in $archive.Entries){
    $name=$entry.FullName.Replace('\','/')
    if($name.Length -gt 2048 -or $name.StartsWith('/') -or $name -match '[:\x00-\x1f]' -or @($name.Split('/') | Where-Object {$_ -in @('.','..')}).Count -gt 0){throw 'Unsafe archive entry path.'}
    if(-not $names.Add($name)){throw 'Duplicate archive entry path.'}
    $entries.Add([pscustomobject]@{path=$name;size=$entry.Length;compressedSize=$entry.CompressedLength})
    if($name -cmatch '^classes(?:[0-9]+)?\.dex$'){$dex++}
    if($name.StartsWith('assets/',[StringComparison]::Ordinal)){$assets++}
    if($name -cmatch '^lib/([^/]+)/[^/]+\.so$'){$null=$abis.Add($Matches[1])}
    if($name -ceq 'AndroidManifest.xml'){
     $stream=$entry.Open();try{$bytes=[byte[]]::new(256);$count=$stream.Read($bytes,0,$bytes.Length);$prefix=[Text.Encoding]::UTF8.GetString($bytes,0,$count).TrimStart([char]0xfeff,' ',"`t","`r","`n");$manifest=if($prefix.StartsWith('<')){'TextXml'}else{'BinaryOrUnknown'}}finally{$stream.Dispose()}
    }
   }
   if($manifest -eq 'Missing'){throw 'AndroidManifest.xml is missing.'}
   $apkStream.Position=0
   $result.apk=[ordered]@{path=$file.FullName;size=$apkStream.Length;sha256=(Get-FileHash -InputStream $apkStream -Algorithm SHA256).Hash;manifest=$manifest;dexFiles=$dex;assetEntries=$assets;nativeAbis=@($abis | Sort-Object);entries=$entries.ToArray()}
  } finally {
   try {if($null -ne $archive){$archive.Dispose()}} finally {$apkStream.Dispose()}
  }
 } else {
  if($DeviceSerial -notmatch '^[A-Za-z0-9][A-Za-z0-9._:\-]{0,127}$'){throw 'Invalid explicit device serial.'}
  if($PackageName -and $PackageName -notmatch '^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$'){throw 'Invalid package name.'}
  $exe=(Get-Command -Name $AdbPath -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
  if([IO.Path]::GetExtension($exe) -ine '.exe'){throw 'AdbPath must resolve to an executable (.exe), not a shell wrapper.'}
  if(-not ('LocalDevTools.AndroidProcess' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'lib\AndroidProcess.cs')}
  $state=[LocalDevTools.AndroidProcess]::Run($exe,@('-s',$DeviceSerial,'get-state'),$PSScriptRoot,$TimeoutSeconds)
  if($state.ExitCode -ne 0){$global:LASTEXITCODE=$state.ExitCode;throw "ADB state failed ($($state.ExitCode)): $($state.Stderr)"}
  if($state.Stdout.Trim() -cne 'device'){throw 'Selected device is not online and authorized.'}
  $pids=@();$logArgs=[Collections.Generic.List[string]]::new();foreach($a in @('-s',$DeviceSerial,'logcat','-d','-t',"$LogLines",'-v','threadtime')){$logArgs.Add($a)}
  if($PackageName){
   $pidResult=[LocalDevTools.AndroidProcess]::Run($exe,@('-s',$DeviceSerial,'shell','pidof',$PackageName),$PSScriptRoot,$TimeoutSeconds)
   if($pidResult.ExitCode -ne 0){$global:LASTEXITCODE=$pidResult.ExitCode;throw "Package PID lookup failed ($($pidResult.ExitCode))."}
   if($pidResult.Stdout.Trim() -notmatch '^\d+(\s+\d+)*$'){throw 'Package has no valid running PID(s).'}
   $pids=@($pidResult.Stdout.Trim() -split '\s+' | Select-Object -Unique)
   if($pids.Count -gt 8){throw 'Package exceeds the 8-PID diagnostic limit.'}
   foreach($pidValue in $pids){$parsedPid=0;if($pidValue -notmatch '^[1-9][0-9]{0,9}$' -or -not [int]::TryParse($pidValue,[ref]$parsedPid)){throw 'Package returned an invalid PID.'}}
  }
  $logGroups=[Collections.Generic.List[object]]::new();$truncated=$false
  $targets=if($pids.Count){$pids}else{@('')}
  foreach($targetPid in $targets){
   $arguments=$logArgs.ToArray();if($targetPid){$arguments+=@("--pid=$targetPid")}
   $logs=[LocalDevTools.AndroidProcess]::Run($exe,$arguments,$PSScriptRoot,$TimeoutSeconds)
   if($logs.ExitCode -ne 0){$global:LASTEXITCODE=$logs.ExitCode;throw "ADB logcat failed ($($logs.ExitCode)): $($logs.Stderr)"}
   $logGroups.Add([pscustomobject]@{pid=$targetPid;logcat=$logs.Stdout;stderr=$logs.Stderr;outputTruncated=$logs.Truncated});$truncated=$truncated -or $logs.Truncated
  }
  $result.device=[ordered]@{serial=$DeviceSerial;state=$state.Stdout.Trim();package=$PackageName;pids=$pids;logs=$logGroups.ToArray();outputTruncated=$truncated;requestedLinesPerPid=$LogLines;adbServerMayStart=$true}
 }
 $result.valid=$true;$global:LASTEXITCODE=0
} catch {$result.error=$_.Exception.Message}
if($Json){$result | ConvertTo-Json -Depth 10}else{[pscustomobject]$result}
