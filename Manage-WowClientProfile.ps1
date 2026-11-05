#requires -Version 7.0
<#
.SYNOPSIS
Creates or verifies a versioned WoW client profile, copying sources as data only.
.NOTES
SourcePath and SavedVariablesPath are explicit directories; never execute their contents.
#>
[CmdletBinding(DefaultParameterSetName='Read')]
param([Parameter(Mandatory,ParameterSetName='Create')][string]$Destination,[Parameter(Mandatory,ParameterSetName='Create')][ValidatePattern('^[A-Za-z][A-Za-z0-9_-]{0,63}$')][string]$Id,[Parameter(Mandatory,ParameterSetName='Create')][ValidateRange(1,9999999)][int]$InterfaceVersion,[Parameter(ParameterSetName='Create')][ValidatePattern('^5\.[1-5]$')][string]$LuaVersion='5.1',[Parameter(ParameterSetName='Create')][string]$SourcePath,[Parameter(ParameterSetName='Create')][string]$SavedVariablesPath,[Parameter(ParameterSetName='Create')][ValidateLength(1,4096)][string]$SourceDescription='User-supplied source; client API completeness not certified',[Parameter(Mandatory,ParameterSetName='Read')][string]$ProfilePath,[switch]$Json)
$ErrorActionPreference='Stop';. (Join-Path $PSScriptRoot 'lib\PlatformResources.ps1');$r=New-PlatformResult 'Manage-WowClientProfile' $PSCmdlet.ParameterSetName;$global:LASTEXITCODE=125
try {
 if($PSCmdlet.ParameterSetName -eq 'Create'){
  $dest=Assert-PlatformPath $Destination -New;$plan=[Collections.Generic.List[object]]::new();$total=0L
  foreach($entry in @(@{root=$SourcePath;kind='apiSources';folder='api'},@{root=$SavedVariablesPath;kind='savedVariablesFixtures';folder='savedvariables'})){
   if(-not $entry.root){continue};$base=Assert-PlatformPath $entry.root;if(-not(Test-Path -LiteralPath $base -PathType Container)){throw 'Import root must be an existing directory.'}
   foreach($file in @(Get-PlatformFiles $base)){if($file.Length -gt 8388608 -or ($total+=$file.Length) -gt 33554432){throw 'Import exceeds file/total size bound.'};$relative=([IO.Path]::GetRelativePath($base,$file.FullName)).Replace('\','/');$plan.Add(@{source=$file.FullName;relativePath="$($entry.folder)/$relative";kind=$entry.kind;sha256=(Get-FileHash -LiteralPath $file.FullName).Hash;sourceDescription=$SourceDescription})}
  }
  $profile=[ordered]@{schemaVersion=1;id=$Id;interfaceVersion=$InterfaceVersion;luaVersion=$LuaVersion;apiSources=@();savedVariablesFixtures=@();capturedUtc=[DateTime]::UtcNow.ToString('o');verification='Copied as data; no client/game API compatibility certification'}
  $null=[IO.Directory]::CreateDirectory($dest)
  foreach($item in $plan){$target=Join-Path $dest $item.relativePath;$null=[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target));[IO.File]::Copy($item.source,$target,$false);$record=@{relativePath=$item.relativePath;sha256=$item.sha256;source=$item.sourceDescription;capturedUtc=$profile.capturedUtc};$profile[$item.kind]+=$record}
  $path=Join-Path $dest 'profile.json';$profile|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $path -Encoding utf8;$r.profilePath=$path
 }else{$path=Assert-PlatformPath $ProfilePath;$profile=Read-PlatformJson $path;$dest=[IO.Path]::GetDirectoryName($path)}
 if($profile.schemaVersion -ne 1 -or $profile.id -notmatch '^[A-Za-z][A-Za-z0-9_-]{0,63}$' -or ($profile.interfaceVersion -isnot [long] -and $profile.interfaceVersion -isnot [int]) -or $profile.interfaceVersion -lt 1 -or $profile.interfaceVersion -gt 9999999 -or $profile.luaVersion -notmatch '^5\.[1-5]$'){throw 'Invalid profile metadata.'}
 $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase);$ok=$true;$verifiedBytes=0L
 foreach($kind in @('apiSources','savedVariablesFixtures')){if($profile[$kind] -isnot [array]){throw 'Profile source lists must be arrays.'};if($profile[$kind].Count -gt 10000){throw 'Too many profile sources.'};foreach($entry in $profile[$kind]){$rel=[string]$entry.relativePath;if(-not $rel -or [IO.Path]::IsPathRooted($rel) -or $rel -match '[:*?\x00-\x1f]' -or @($rel.Replace('\','/').Split('/')|Where-Object{$_ -in @('','..','.')}).Count -or -not $seen.Add($rel.Replace('\','/')) -or $seen.Count -gt 10000 -or $entry.sha256 -notmatch '^[0-9A-Fa-f]{64}$'){throw 'Invalid/duplicate profile path or hash.'};$f=Assert-PlatformPath (Join-Path $dest $rel);$match=$false;if(Test-Path -LiteralPath $f -PathType Leaf){$file=Get-Item -LiteralPath $f;if($file.Length -gt 8388608 -or ($verifiedBytes+=$file.Length) -gt 33554432){throw 'Profile verification size budget exceeded.'};$match=(Get-FileHash -LiteralPath $f).Hash -eq $entry.sha256};$r.findings+=@{id=$rel;status=$(if($match){'Pass'}else{'Fail'});evidence=$f};$ok=$ok -and $match}}
 $r.profile=$profile;$r.profilePath=$path;$r.valid=$ok;$global:LASTEXITCODE=if($ok){0}else{2};$r.limitations=@('Profile files are provenance data, not execution or a complete client API snapshot.')
}catch{$r.error=$_.Exception.Message};Write-PlatformResult $r -Json:$Json
