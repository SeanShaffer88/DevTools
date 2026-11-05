#requires -Version 7.0
<#
.SYNOPSIS
Captures bounded metadata and optional normal minidump for an explicitly selected owned process.
.PARAMETER ProcessId
Actual process ID; owner SID is verified against the current user and a handle pins process identity.
.PARAMETER ExpectedStartTimeUtc
Optional ISO UTC creation-time guard from a previous observation.
.PARAMETER IncludeDump
Explicitly capture a normal Windows minidump. Binary dumps can contain sensitive data and are not redacted.
.NOTES
New destination only. No global WER settings or process termination. Logs receive best-effort
text credential redaction only. Exit0 capture completed,3 omissions/unavailable,125 setup/ownership failure.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][ValidateRange(1,2147483647)][int]$ProcessId,[Parameter(Mandatory)][string]$Destination,[datetime]$ExpectedStartTimeUtc,[switch]$IncludeDump,[string[]]$LogPath=@(),[ValidateRange(1,1048576)][int]$MaxLogBytes=262144,[switch]$Json)
$ErrorActionPreference='Stop';. (Join-Path $PSScriptRoot 'lib/WindowsDiagnosticsCommon.ps1')
$result=[ordered]@{schemaVersion=1;observedUtc=[datetime]::UtcNow.ToString('o');tool='Export-CrashDiagnostics';scope='Selected owned process only';valid=$false;destination=$null;process=$null;modules=@();logs=@();dump=$null;findings=@();error=$null;limitations=@('Normal minidumps are binary and can contain sensitive memory; no binary redaction is promised.','Log redaction is best-effort; review all files before sharing.','Metadata/modules identify the selected process; no full crash root-cause analysis is performed.')}
$owned=$null;$findings=[Collections.Generic.List[object]]::new()
try{
    if($LogPath.Count -gt 16){throw 'At most sixteen explicit logs may be captured.'}
    $destinationPath=Assert-DevNewDestination $Destination
    if(-not ('LocalDevTools.OwnedProcess' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'lib/WindowsDiagnosticsNative.cs')}
    $owned=[LocalDevTools.OwnedProcess]::Open($ProcessId)
    if($PSBoundParameters.ContainsKey('ExpectedStartTimeUtc') -and $owned.StartUtc.Ticks -ne $ExpectedStartTimeUtc.ToUniversalTime().Ticks){throw 'Selected process creation time does not match the supplied identity guard.'}
    $result.process=@{id=$ProcessId;ownerSid=$owned.OwnerSid;startTimeUtc=$owned.StartUtc.ToString('o');imagePath=$owned.ImagePath}
    $null=[IO.Directory]::CreateDirectory($destinationPath);$result.destination=$destinationPath
    $modules=[Collections.Generic.List[object]]::new()
    try{$process=[Diagnostics.Process]::GetProcessById($ProcessId);try{if($process.StartTime.ToUniversalTime().Ticks -ne $owned.StartUtc.Ticks){throw 'PID reuse detected while collecting modules.'};$list=$process.Modules;if($list.Count -gt 256){$findings.Add(@{id='ModuleLimit';status='unknown';detail='Module inventory truncated to256.'})};foreach($module in $list | Select-Object -First 256){$entry=@{name=$module.ModuleName;path=$module.FileName;fileVersion=$module.FileVersionInfo.FileVersion;codeView=@()};try{$stream=[IO.File]::OpenRead($module.FileName);try{$pe=[Reflection.PortableExecutable.PEReader]::new($stream);try{$debugs=$pe.ReadDebugDirectory();if($debugs.Length -gt 64){throw 'Debug directory entry bound reached.'};$entry.codeView=@(foreach($debug in $debugs){if($debug.Type -eq [Reflection.PortableExecutable.DebugDirectoryEntryType]::CodeView){$cv=$pe.ReadCodeViewDebugDirectoryData($debug);@{guid=$cv.Guid.ToString();age=$cv.Age;pdbPath=$cv.Path}}})}finally{$pe.Dispose()}}finally{$stream.Dispose()}}catch{$entry.symbolEvidence='Unavailable'};$modules.Add($entry)};if($process.StartTime.ToUniversalTime().Ticks -ne $owned.StartUtc.Ticks){throw 'Process identity changed during collection.'}}finally{$process.Dispose()}}catch{$findings.Add(@{id='ModulesUnavailable';status='unknown';detail=$_.Exception.Message})}
    $result.modules=@($modules.ToArray());$captured=[Collections.Generic.List[object]]::new();$index=0
    foreach($log in $LogPath){$index++;try{$item=Get-Item -LiteralPath $log;if($item.PSIsContainer){throw 'Log must be a file.'};$buffer=[byte[]]::new([math]::Min($item.Length,$MaxLogBytes));$stream=[IO.File]::OpenRead($item.FullName);try{$read=$stream.Read($buffer,0,$buffer.Length)}finally{$stream.Dispose()};$text=[Text.Encoding]::UTF8.GetString($buffer,0,$read);$pattern='(?im)(["\x27]?(?:password|passwd|token|api[_-]?key|secret)["\x27]?\s*[:=]\s*)(?:"(?:\\.|[^"\\])*"|\x27(?:\\.|[^\x27\\])*\x27|[^\s,;}]+)';$text=[regex]::Replace($text,$pattern,'$1"[REDACTED]"',[Text.RegularExpressions.RegexOptions]::None,[TimeSpan]::FromSeconds(1));$text=[regex]::Replace($text,'(?i)Bearer\s+[A-Za-z0-9._~+/-]+=*','Bearer [REDACTED]');$output=Join-Path $destinationPath ("log-$index.txt");[IO.File]::WriteAllText($output,$text);$captured.Add(@{source=$item.FullName;path=$output;truncated=$item.Length -gt $read;redaction='BestEffort'})}catch{$findings.Add(@{id='LogUnavailable';status='unknown';detail=$_.Exception.Message})}}
    $result.logs=@($captured.ToArray());$owned.EnsureRunning()
    if($IncludeDump){$dump=Join-Path $destinationPath 'process.dmp';$owned.Dump($dump);$result.dump=@{path=$dump;size=(Get-Item -LiteralPath $dump).Length;sha256=(Get-FileHash -LiteralPath $dump -Algorithm SHA256).Hash;sensitivity='UnredactedBinary'}}
    $result.findings=@($findings.ToArray());$result.valid=$findings.Count -eq 0;$global:LASTEXITCODE=if($result.valid){0}else{3}
    $result | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $destinationPath 'result.json')
}catch{$result.error=$_.Exception.Message;$global:LASTEXITCODE=125}finally{if($owned){$owned.Dispose()}}
if($Json){$result | ConvertTo-Json -Depth 12}else{[pscustomobject]$result}
