#requires -Version 7.0
<#
.SYNOPSIS
Verifies a bounded offline attribution catalog and optionally writes new plain-text credits.
.NOTES
Catalog schema1 entries: path,sha256,source,license,author,modification,requiredCredits. Metadata is declared, never rights certification. Missing rights fields yield Unknown. Root-relative media only. Credits labels exclude control characters and are <=512 characters. No HTML output or network.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Root,[Parameter(Mandatory)][string]$CatalogPath,[string]$CreditsPath,[switch]$Json)
$ErrorActionPreference='Stop';. (Join-Path $PSScriptRoot '../lib/QualityGames.ps1');$r=QG-Result 'Test-MediaAttribution' @{root=$Root};$code=125
try{$base=QG-Path $Root;if(-not(Test-Path -LiteralPath $base -PathType Container)){throw 'Root must be directory.'};$c=QG-Read $CatalogPath;QG-Fields $c @('schemaVersion','entries');QG-Schema $c;if($c.entries -isnot [array] -or $c.entries.Count -lt 1 -or $c.entries.Count -gt 256){throw 'One to 256 entries required.'};$new=$null;if($CreditsPath){$new=QG-Path $CreditsPath -New};$code=0;$bytes=0L;$lines=[Collections.Generic.List[string]]::new();$seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
 foreach($e in $c.entries){QG-Fields $e @('path','sha256') @('source','license','author','modification','requiredCredits');if($e.path -isnot [string] -or -not $seen.Add($e.path) -or $e.sha256 -isnot [string] -or $e.sha256 -cnotmatch '^[0-9a-fA-F]{64}$'){throw 'Invalid or duplicate path/hash.'};$path=QG-Relative $base $e.path;$status='Pass';$reason='Hash matches; attribution is declared metadata, not rights certification.'
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){$status='Fail';$reason='Media missing'}else{$f=Get-Item -LiteralPath $path;$bytes+=$f.Length;if($f.Length -gt 16777216 -or $bytes -gt 67108864){throw 'Media hash budget exceeded.'};if((Get-FileHash -LiteralPath $path).Hash -ine $e.sha256){$status='Fail';$reason='Hash mismatch'}}
  $missing=$false;foreach($key in @('source','license','author','modification','requiredCredits')){if($key -cnotin @($e.Keys) -or $null -eq $e[$key] -or $e[$key] -ceq '' -or $e[$key] -ceq 'NOASSERTION'){$missing=$true;continue};if($e[$key] -isnot [string] -or $e[$key].Length -gt 512 -or $e[$key] -match '[\x00-\x1f\x7f]' -or $e[$key] -match '(?:[A-Za-z]:[\\/]|\\\\|(?:^|\s)/[^/\s])'){throw 'Attribution labels must be bounded plain text without local absolute paths.'}}
  if($status -ceq 'Fail'){$code=2}elseif($missing){$status='Unknown';$reason='Required rights/provenance metadata missing';if($code -eq 0){$code=3}};QG-Finding $r $e.path $status $reason;if($status -ceq 'Pass'){$lines.Add("$($e.path): $($e.requiredCredits) | Author: $($e.author) | License (declared): $($e.license) | Source: $($e.source) | Modification: $($e.modification)")}
 };if($new -and $code -eq 0){[IO.File]::WriteAllLines($new,$lines);$r.artifacts+=QG-Artifact $new};$r.limitations=@('File identity and metadata presence only; no legal grant, ownership or redistribution certification.','No downloading or HTML generation. Credits are emitted only when every record passes.')
}catch{$code=125;$r.error=$_.Exception.Message};QG-Finish $r $code -Json:$Json
