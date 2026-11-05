#requires -Version 7.0
<#
.SYNOPSIS
Verifies an explicit local cache catalog offline; hashes establish identity, not trust or license rights.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$CatalogPath,[switch]$Json)
$ErrorActionPreference='Stop';$tool=Split-Path $PSScriptRoot -Parent;. (Join-Path $tool 'lib\PlatformResources.ps1');$r=New-PlatformResult 'Test-CacheCatalog' 'OfflineIdentity';$global:LASTEXITCODE=125
try{
 $path=Assert-PlatformPath $CatalogPath;$catalog=Read-PlatformJson $path;if($catalog.schemaVersion -ne 1 -or $catalog.entries -isnot [array] -or $catalog.entries.Count -gt 10000){throw 'Invalid cache schema.'};$base=[IO.Path]::GetDirectoryName($path);$seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase);$plan=@()
 foreach($entry in $catalog.entries){$rel=[string]$entry.path;if(-not $rel -or [IO.Path]::IsPathRooted($rel) -or $rel -match '[:*?\x00-\x1f]' -or @($rel.Replace('\','/').Split('/')|Where-Object{$_ -in @('','..','.')}).Count -or -not $seen.Add($rel.Replace('\','/')) -or $entry.sha256 -notmatch '^[0-9a-fA-F]{64}$'){throw 'Unsafe/duplicate cache path or invalid hash.'};$plan+=@{entry=$entry;full=(Assert-PlatformPath (Join-Path $base $rel))}}
 $code=0;foreach($item in $plan){$e=$item.entry;$exists=Test-Path -LiteralPath $item.full -PathType Leaf;$status='Fail';$hash=$null;if($exists){$f=Get-Item -LiteralPath $item.full;if($f.Length -gt 1073741824){throw 'Cache artifact exceeds 1 GiB.'};$hash=(Get-FileHash -LiteralPath $item.full).Hash;$status=if($hash -ieq $e.sha256){'Pass'}else{'Fail'}};if($status -eq 'Fail'){$code=2};$r.findings+=@{id=$e.path;status=$status;observedHash=$hash;expectedHash=$e.sha256}
  $metadata=$true;foreach($field in @('source','version','license','provenance','capturedUtc')){if([string]::IsNullOrWhiteSpace([string]$e[$field]) -or ([string]$e[$field]).Trim() -match '^(Unknown|NOASSERTION|Unverified|NotProvided|NotPerformed|Unspecified|None|N[-/]A)$'){$metadata=$false}};if(-not $metadata){$r.findings+=@{id="$($e.path):provenance";status='Unknown';evidence='Required provenance/license metadata absent or explicitly unknown.'};if($code -eq 0){$code=3}}
 };$r.valid=$code -eq 0;$global:LASTEXITCODE=$code;$r.limitations=@('No network access or downloading.','A matching hash is not a security endorsement; recorded license text is not a redistribution authorization.')
}catch{$r.error=$_.Exception.Message};Write-PlatformResult $r -Json:$Json
