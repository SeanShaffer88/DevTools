#requires -Version 7.0
<#
.SYNOPSIS
Runs real client-matched Lua syntax checks and optional explicitly trusted harness tests.
.NOTES
No fake parser. Missing interpreter returns 3. Syntax checks loadfile without executing addon code.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$AddonPath,[Parameter(Mandatory)][string]$ProfilePath,[string]$TocPath,[string]$InterpreterPath,[string]$HarnessPath,[switch]$ExecuteTrustedHarness,[ValidateRange(1,120)][int]$TimeoutSeconds=15,[switch]$Json)
$ErrorActionPreference='Stop';. (Join-Path $PSScriptRoot 'lib\PlatformResources.ps1');$r=New-PlatformResult 'Test-WowLua' 'SyntaxAndOptionalMocks';$global:LASTEXITCODE=125
try{
 $profileResult=& (Join-Path $PSScriptRoot 'Manage-WowClientProfile.ps1') -ProfilePath $ProfilePath;if(-not $profileResult.valid){throw "Invalid client profile: $($profileResult.error)"};$profile=$profileResult.profile;$addon=Assert-PlatformPath $AddonPath;$staticArgs=@{AddonPath=$addon;InterfaceVersion=$profile.interfaceVersion};if($TocPath){$staticArgs.TocPath=$TocPath};$static=& (Join-Path $PSScriptRoot 'Test-WowAddon.ps1') @staticArgs;if(-not $static.valid){$global:LASTEXITCODE=2;throw 'Addon structural/interface validation failed.'}
 if($HarnessPath -and -not $ExecuteTrustedHarness){throw 'Harness execution requires ExecuteTrustedHarness acknowledgement.'};if($HarnessPath){$HarnessPath=Assert-PlatformPath $HarnessPath;if(-not(Test-Path -LiteralPath $HarnessPath -PathType Leaf)){throw 'Harness must exist.'}}
 if(-not $InterpreterPath){$local=Join-Path $PSScriptRoot 'tools\lua-5.1.5\bin\lua.exe';if(Test-Path -LiteralPath $local -PathType Leaf){$InterpreterPath=$local}else{$candidate=Get-Command lua.exe,lua51.exe -CommandType Application -ErrorAction SilentlyContinue|Select-Object -First 1;if($candidate){$InterpreterPath=$candidate.Source}}}
 if(-not $InterpreterPath){$global:LASTEXITCODE=3;$r.findings+=@{id='interpreter';status='Blocked';evidence='No compatible installed Lua interpreter selected.'};throw 'Lua syntax and harness execution NotPerformed.'};try{$lua=Resolve-PlatformExe $InterpreterPath}catch{$global:LASTEXITCODE=3;throw 'Selected Lua interpreter is unavailable; execution NotPerformed.'}
 $version=Invoke-PlatformCommand $lua @('-v') $TimeoutSeconds;$versionText=[Text.Encoding]::UTF8.GetString($version.Output)+$version.Error;if($version.ExitCode -ne 0 -or $version.TimedOut -or $version.Truncated -or $versionText -notmatch ('\bLua\s+'+[regex]::Escape($profile.luaVersion)+'(?:\.|\s|$)')){$global:LASTEXITCODE=3;throw 'Interpreter version does not match profile or version probe failed.'}
 $files=@(Get-PlatformFiles $addon|Where-Object{$_.Extension -ieq '.lua'});if($files.Count -gt 1000){throw 'Lua file count limit exceeded.'};$code=0
 foreach($file in $files){if($file.Length -gt 8388608){throw 'Lua file exceeds 8 MiB.'};$cmd=Invoke-PlatformCommand $lua @((Join-Path $PSScriptRoot 'lib\PlatformSyntax.lua'),$file.FullName) $TimeoutSeconds;$status=if($cmd.TimedOut -or $cmd.Truncated){'Unknown'}elseif($cmd.ExitCode -eq 0){'Pass'}else{'Fail'};$r.findings+=@{id=[IO.Path]::GetRelativePath($addon,$file.FullName);status=$status;exitCode=$cmd.ExitCode;stderr=$cmd.Error};if($status -eq 'Fail'){$code=2}elseif($status -eq 'Unknown' -and $code -eq 0){$code=3}}
 if($HarnessPath){$cmd=Invoke-PlatformCommand $lua @($HarnessPath,$addon) $TimeoutSeconds;$status=if($cmd.TimedOut -or $cmd.Truncated){'Unknown'}elseif($cmd.ExitCode -eq 0){'Pass'}else{'Fail'};$r.findings+=@{id='mockHarness';status=$status;exitCode=$cmd.ExitCode;output=[Text.Encoding]::UTF8.GetString($cmd.Output);stderr=$cmd.Error};if($status -eq 'Fail'){$code=2}elseif($status -eq 'Unknown' -and $code -eq 0){$code=3}}
 $r.valid=$code -eq 0;$r.interpreter=$lua;$global:LASTEXITCODE=$code;$r.limitations=@('loadfile compiles syntax but does not execute addon code.','Only explicitly selected harness code executes; a subprocess is not a security sandbox.','Mock APIs/events do not establish real WoW runtime, secure execution or API compatibility.','Every local Lua file is syntax checked, including files not in the selected TOC.')
}catch{$r.error=$_.Exception.Message};Write-PlatformResult $r -Json:$Json
