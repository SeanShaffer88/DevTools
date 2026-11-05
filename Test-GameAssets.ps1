#requires -Version 7.0
<#
.SYNOPSIS
Inspects explicitly selected asset files without modification or codec execution.
.PARAMETER ManifestPath
Schema1: {schemaVersion:1,references:[relative paths],budgets?:{maxTotalBytes,maxFileBytes,maxWidth,maxHeight,maxChannels,maxSampleRate,maxBits,maxDurationSeconds},files?:[{path, same optional limits except maxTotalBytes}]}. Limits are user-declared maxima, not hardware recommendations.
.PARAMETER PathPolicy
Windows uses case-insensitive references; Android requires exact case. Case-colliding asset names are refused in both policies.
.NOTES
At most 4096 tree entries, 16 MiB/file and 64 MiB total. Structural media checks do not decode pixels or certify media rights. Exit 0 pass, 2 failure, 3 unsupported evidence, 125 setup.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$AssetRoot,[string]$ManifestPath,[ValidateSet('Windows','Android')][string]$PathPolicy='Windows',[switch]$Json)
$ErrorActionPreference='Stop';. (Join-Path $PSScriptRoot 'lib/QualityGames.ps1');$r=QG-Result 'Test-GameAssets' @{assetRoot=$AssetRoot;pathPolicy=$PathPolicy};$code=125
try{
 $root=QG-Path $AssetRoot;if(-not(Test-Path -LiteralPath $root -PathType Container)){throw 'Asset root must be a directory.'}
 $limits=@('maxFileBytes','maxWidth','maxHeight','maxChannels','maxSampleRate','maxBits','maxDurationSeconds')
 function Check-Budget($b,[switch]$Total){$allowed=$limits;if($Total){$allowed+=@('maxTotalBytes')};QG-Fields $b @() $allowed;foreach($k in $b.Keys){if($k -ceq 'maxDurationSeconds'){QG-Number $b[$k] 0 86400}else{QG-Int $b[$k] 0 1073741824}}}
 $manifest=@{references=@();files=@();budgets=@{}};if($ManifestPath){$manifest=QG-Read $ManifestPath;QG-Fields $manifest @('schemaVersion','references') @('budgets','files');QG-Schema $manifest;if($manifest.references -isnot [array] -or $manifest.references.Count -gt 4096){throw 'References must be bounded array.'};if(-not $manifest.Contains('budgets')){$manifest.budgets=@{}};if(-not $manifest.Contains('files')){$manifest.files=@()};Check-Budget $manifest.budgets -Total;if($manifest.files -isnot [array] -or $manifest.files.Count -gt 4096){throw 'files must be bounded array.'}}
 $pathComparer=if($PathPolicy -ceq 'Android'){[StringComparer]::Ordinal}else{[StringComparer]::OrdinalIgnoreCase}
 $perFile=[Collections.Generic.Dictionary[string,object]]::new($pathComparer);foreach($b in $manifest.files){QG-Fields $b @('path') $limits;if($b.path -isnot [string]){throw 'Budget path must be string.'};$null=QG-Relative $root $b.path;$copy=@{};foreach($k in $b.Keys){if($k -cne 'path'){$copy[$k]=$b[$k]}};Check-Budget $copy;if(-not $perFile.TryAdd($b.path.Replace('\','/'),$copy)){throw 'Duplicate file budget under selected path policy.'}}
 $all=@(QG-Files $root);$total=0L;$hashes=@{};$caseNames=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase);$names=[Collections.Generic.HashSet[string]]::new($pathComparer);$code=0
 foreach($f in $all){$rel=[IO.Path]::GetRelativePath($root,$f.FullName).Replace('\','/');$null=$names.Add($rel);if(-not $caseNames.Add($rel)){QG-Finding $r $rel 'Fail' 'Case-colliding path';$code=2};if($rel -match '[\x00-\x1f<>:"|?*]' -or @($rel.Split('/')|Where-Object{$_ -match '[ .]$|^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|$)'}).Count){QG-Finding $r $rel 'Fail' 'Nonportable file name';$code=2}
  $total+=$f.Length;if($f.Length -gt 16777216 -or $total -gt 67108864){throw 'Asset read budget exceeded (16 MiB/file, 64 MiB total).'}
  $hash=(Get-FileHash -LiteralPath $f.FullName).Hash;if($hashes.ContainsKey($hash)){QG-Finding $r $rel 'Info' @{duplicateOf=$hashes[$hash];sha256=$hash}}else{$hashes[$hash]=$rel}
  try{$media=[DevTools.QualityGames.Media]::Inspect([IO.File]::ReadAllBytes($f.FullName),$f.Extension.ToLowerInvariant());$status=if($media.Kind -ceq 'Unsupported'){'Unknown'}else{'Pass'};QG-Finding $r $rel $status @{bytes=$f.Length;sha256=$hash;media=$media};if($status -ceq 'Unknown' -and $code -eq 0){$code=3}
   $actual=@{maxFileBytes=$f.Length;maxWidth=$media.Width;maxHeight=$media.Height;maxChannels=$media.Channels;maxSampleRate=$media.SampleRate;maxBits=$media.Bits;maxDurationSeconds=$media.Duration}
   foreach($budget in @($manifest.budgets,$(if($perFile.ContainsKey($rel)){$perFile[$rel]}else{@{}}))){foreach($key in $budget.Keys){if($key -ceq 'maxTotalBytes'){continue};if($key -cin @('maxWidth','maxHeight') -and $media.Kind -cnotin @('PNG','BMP','JPEG') -or $key -cin @('maxChannels','maxSampleRate','maxBits','maxDurationSeconds') -and $media.Kind -cne 'WAV PCM'){QG-Finding $r "$rel/$key" 'Unknown' 'Declared budget cannot be measured for this format';if($code -eq 0){$code=3};continue};if($actual[$key] -gt $budget[$key]){QG-Finding $r "$rel/$key" 'Fail' @{actual=$actual[$key];maximum=$budget[$key]};$code=2}}}
  }catch{QG-Finding $r $rel 'Fail' $_.Exception.Message;$code=2}
 }
 foreach($ref in $manifest.references){if($ref -isnot [string]){throw 'Reference must be a string.'};$null=QG-Relative $root $ref;if(-not $names.Contains($ref.Replace('\','/'))){QG-Finding $r $ref 'Fail' 'Missing reference or incorrect case';$code=2}}
 foreach($p in $perFile.Keys){if(-not $names.Contains($p)){QG-Finding $r $p 'Fail' 'Budget names absent asset';$code=2}}
 if($manifest.budgets.Contains('maxTotalBytes') -and $total -gt $manifest.budgets.maxTotalBytes){QG-Finding $r 'totalBytes' 'Fail' @{actual=$total;maximum=$manifest.budgets.maxTotalBytes};$code=2}
 $r.scope=@{assetRoot=$root;pathPolicy=$PathPolicy;files=$all.Count;totalBytes=$total};if($all.Count -eq 0){$code=3;QG-Finding $r 'assets' 'Unknown' 'No assets inspected.'};$r.limitations=@('Structural checks only; no full codec decoding. Unsupported codecs remain Unknown.','SHA256 duplicate identity is informational. Media rights are not inferred.','PNG CRCs cover compressed bytes but IDAT compression/pixel correctness is not validated.')
}catch{$r.error=$_.Exception.Message;$code=125};QG-Finish $r $code -Json:$Json
