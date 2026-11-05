#requires -Version 7.0
<#
.SYNOPSIS
Runs explicitly selected finite diagnostics against an explicitly named Android device/app.
.NOTES
Launch and Startup start the selected Activity; no installs, log clears or device-setting changes.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._:\-]{0,127}$')][string]$DeviceSerial,[Parameter(Mandatory)][ValidatePattern('^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$')][string]$PackageName,[ValidatePattern('^[A-Za-z][A-Za-z0-9_.]*/[A-Za-z.][A-Za-z0-9_.]*$')][string]$Component,[Parameter(Mandatory)][ValidateSet('State','Launch','Screenshot','Memory','Startup','FrameStats')][string[]]$Tasks,[Parameter(Mandatory)][string]$Destination,[string]$AdbPath='adb.exe',[ValidateRange(1,120)][int]$TimeoutSeconds=20,[switch]$Json)
$ErrorActionPreference='Stop';. (Join-Path $PSScriptRoot 'lib\PlatformResources.ps1');$r=New-PlatformResult 'Invoke-AndroidTest' 'ExplicitDevice';$global:LASTEXITCODE=125
try{
 if(@($Tasks|Select-Object -Unique).Count -ne $Tasks.Count -or $Tasks.Count -eq 0){throw 'Tasks must be nonempty and unique.'};if(@($Tasks|Where-Object{$_ -in @('Launch','Startup')}).Count -and -not $Component){throw 'Launch/Startup requires explicit Component.'};if($Component -and $Component.Split('/')[0] -cne $PackageName){throw 'Component package must match PackageName.'}
 $dest=Assert-PlatformPath $Destination -New;$adb=Resolve-PlatformExe $AdbPath;$null=[IO.Directory]::CreateDirectory($dest);$r.destination=$dest;$r.deviceSerial=$DeviceSerial;$r.package=$PackageName
 $state=Invoke-PlatformCommand $adb @('-s',$DeviceSerial,'get-state') $TimeoutSeconds;if($state.ExitCode -ne 0 -or $state.TimedOut -or $state.Truncated -or [Text.Encoding]::UTF8.GetString($state.Output).Trim() -cne 'device'){$global:LASTEXITCODE=3;throw 'Selected device is not online/authorized or state check failed.'}
 $code=0;foreach($task in $Tasks){$args=switch($task){'State'{@('-s',$DeviceSerial,'get-state')};'Launch'{@('-s',$DeviceSerial,'shell','am','start','-n',$Component)};'Startup'{@('-s',$DeviceSerial,'shell','am','start','-W','-n',$Component)};'Screenshot'{@('-s',$DeviceSerial,'exec-out','screencap','-p')};'Memory'{@('-s',$DeviceSerial,'shell','dumpsys','meminfo',$PackageName)};'FrameStats'{@('-s',$DeviceSerial,'shell','dumpsys','gfxinfo',$PackageName,'framestats')}};$cmd=Invoke-PlatformCommand $adb $args $TimeoutSeconds 16777216;$status=if($cmd.TimedOut -or $cmd.Truncated){'Unknown'}elseif($cmd.ExitCode -eq 0){'Pass'}else{'Fail'};$path=Join-Path $dest ($task+$(if($task -eq 'Screenshot'){'.png'}else{'.txt'}))
  $text=[Text.Encoding]::UTF8.GetString($cmd.Output);$combined=$text+"`n"+$cmd.Error
  if($status -eq 'Pass'){
   if($task -in @('Launch','Startup') -and $combined -match '(?im)^\s*(Error(?:\s+type\s+\d+)?\s*:|SecurityException\b)|java\.lang\.SecurityException'){$status='Fail'}
   elseif($task -eq 'Startup' -and $text -notmatch '(?im)^\s*Status:\s*ok\s*$'){$status='Unknown'}
   elseif($task -eq 'Launch' -and $text -notmatch '(?im)^Starting:\s+Intent'){$status='Unknown'}
   elseif($task -eq 'State' -and $text.Trim() -cne 'device'){$status='Unknown'}
   elseif($task -eq 'Memory' -and $text -notmatch '(?im)\bTOTAL(?:\s+PSS:|\s+\d)'){$status='Unknown'}
   elseif($task -eq 'FrameStats' -and $text -notmatch '(?m)^Flags,IntendedVsync,'){$status='Unknown'}
   elseif($task -eq 'Screenshot' -and ($cmd.Output.Length -lt 8 -or ([BitConverter]::ToString($cmd.Output,0,8)) -cne '89-50-4E-47-0D-0A-1A-0A')){$status='Fail';$cmd.Error+=' Invalid PNG signature.'}
  }
  if($status -eq 'Pass'){[IO.File]::WriteAllBytes($path,$cmd.Output)};$r.findings+=@{id=$task;status=$status;exitCode=$cmd.ExitCode;timedOut=$cmd.TimedOut;outputTruncated=$cmd.Truncated;outputPath=$(if($status -eq 'Pass'){$path}else{$null});stderr=$cmd.Error};if($status -eq 'Fail'){$code=2}elseif($status -eq 'Unknown' -and $code -eq 0){$code=3}
 };$r.valid=$code -eq 0;$global:LASTEXITCODE=$code;$r.limitations=@('ADB may start its local server. Only explicitly selected Launch/Startup changes app state.','Startup reports am start timing without force-stop; warm/cold startup is not inferred.','Memory/FrameStats are raw app diagnostic snapshots, not certified FPS or renderer support.','Screenshot captures the device display and may contain sensitive content.');$r|ConvertTo-Json -Depth 20|Set-Content -LiteralPath (Join-Path $dest 'result.json')
}catch{$r.error=$_.Exception.Message};Write-PlatformResult $r -Json:$Json
