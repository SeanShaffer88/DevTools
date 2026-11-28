#requires -Version 7.0
<#
.SYNOPSIS
Verifies APK manifest decoding, ZIP alignment and signature using existing Android SDK tools.
.NOTES
Never signs, installs or creates keys. Unsigned APKs fail signature verification.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ApkPath,[string]$BuildToolsRoot,[string]$JavaPath='java.exe',[ValidateRange(1,120)][int]$TimeoutSeconds=30,[switch]$Json)
$ErrorActionPreference='Stop';. (Join-Path $PSScriptRoot 'lib\PlatformResources.ps1');$r=New-PlatformResult 'Test-AndroidArtifact' 'OfflineSdkVerification';$global:LASTEXITCODE=125
try{
 try{$apk=Assert-PlatformPath $ApkPath}catch{throw 'APK artifact path rejected: '+$_.Exception.Message};$offline=& (Join-Path $PSScriptRoot 'Get-AndroidDiagnostics.ps1') -ApkPath $apk;if(-not $offline.valid){$global:LASTEXITCODE=2;throw "Invalid APK: $($offline.error)"};$r.apk=$offline.apk
 if(-not $BuildToolsRoot){
  $sdk=$env:ANDROID_HOME
  if([string]::IsNullOrWhiteSpace($sdk)){$sdk=$env:ANDROID_SDK_ROOT}
  if([string]::IsNullOrWhiteSpace($sdk)){$sdk=Join-Path $env:LOCALAPPDATA 'Android\Sdk'}
  $buildTools=Join-Path $sdk 'build-tools'
  $BuildToolsRoot=(Get-ChildItem -LiteralPath $buildTools -Directory -ErrorAction SilentlyContinue|Where-Object{$_.Name -match '^\d+\.\d+\.\d+$'}|Sort-Object {[version]$_.Name} -Descending|Select-Object -First 1).FullName
 }
 if(-not $BuildToolsRoot){$global:LASTEXITCODE=3;throw 'Android SDK build-tools are unavailable.'}
 # The explicitly supplied SDK may be junction-backed; APK inputs still use strict reparse checks.
 $bt=[IO.Path]::GetFullPath($BuildToolsRoot);if($bt.StartsWith('\\')){$global:LASTEXITCODE=3;throw 'Local SDK paths required.'};if(-not(Test-Path -LiteralPath $bt -PathType Container)){$global:LASTEXITCODE=3;throw 'Android SDK build-tools directory is unavailable.'};$aapt2=Join-Path $bt 'aapt2.exe';$aapt1=Join-Path $bt 'aapt.exe';$align=Join-Path $bt 'zipalign.exe';$signer=Join-Path $bt 'lib\apksigner.jar'
 foreach($p in @($aapt2,$align,$signer)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){$global:LASTEXITCODE=3;throw 'Required SDK verification component missing.'}}
 $java=Resolve-PlatformExe $JavaPath;$checks=@(@{id='manifest';exe=$aapt2;args=@('dump','xmltree',$apk,'--file','AndroidManifest.xml')},@{id='alignment';exe=$align;args=@('-c','-P','16','-v','4',$apk)},@{id='signature';exe=$java;args=@('-jar',$signer,'verify','--verbose','--print-certs',$apk)})
 $code=0;if(Test-Path -LiteralPath $aapt1 -PathType Leaf){$checks+=@(@{id='badging';exe=$aapt1;args=@('dump','badging',$apk)},@{id='permissions';exe=$aapt1;args=@('dump','permissions',$apk)})}else{$r.findings+=@(@{id='badging';status='Unknown';exitCode=$null;timedOut=$false;outputTruncated=$false;output='AAPT1 unavailable.';stderr=''},@{id='permissions';status='Unknown';exitCode=$null;timedOut=$false;outputTruncated=$false;output='AAPT1 unavailable.';stderr=''});$code=3};foreach($check in $checks){$cmd=Invoke-PlatformCommand $check.exe $check.args $TimeoutSeconds;$status=if($cmd.TimedOut -or $cmd.Truncated){'Unknown'}elseif($cmd.ExitCode -eq 0){'Pass'}else{'Fail'};$r.findings+=@{id=$check.id;status=$status;exitCode=$cmd.ExitCode;timedOut=$cmd.TimedOut;outputTruncated=$cmd.Truncated;output=[Text.Encoding]::UTF8.GetString($cmd.Output);stderr=$cmd.Error};if($status -eq 'Fail'){$code=2}elseif($status -eq 'Unknown' -and $code -eq 0){$code=3}}
 $r.valid=$code -eq 0;$global:LASTEXITCODE=$code;$r.limitations=@('ZIP alignment does not establish ELF segment 16 KiB compatibility.','No signing, installation, device execution, release-policy or target API eligibility certification.','Native ABI directory names are metadata, not a full native binary compatibility check.')
}catch{$r.error=$_.Exception.Message};Write-PlatformResult $r -Json:$Json
