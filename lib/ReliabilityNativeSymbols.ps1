. "$PSScriptRoot/QualityCommon.ps1"
if(-not ('LocalDevTools.ReliabilityNativeSymbols' -as [type])){Add-Type -Path "$PSScriptRoot/ReliabilityNativeSymbols.cs"}
function RV-Path([string]$Path){
 if([string]::IsNullOrWhiteSpace($Path) -or -not [IO.Path]::IsPathFullyQualified($Path) -or $Path -match '(^\\\\|(^|[\\/])\.\.([\\/]|$)|[\x00-\x1f*?])' -or $Path.Substring(2).Contains(':')){throw 'Explicit local absolute path required; UNC, traversal and ADS refused.'}
 foreach($part in ($Path.Substring(3) -split '[\\/]')){if($part.EndsWith('.') -or $part.EndsWith(' ')){throw 'Ambiguous path component refused.'}}
 Assert-QPath $Path
}
function RV-Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function RV-Manifest($m,[switch]$Stored){
 Assert-QSchema $m
 if($m.buildId -isnot [string] -or $m.buildId -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$' -or $m.buildId.EndsWith('.')){throw 'Invalid buildId.'}
 if($m.source -isnot [Collections.IDictionary] -or -not $m.source.Contains('dirty') -or ($null -ne $m.source.dirty -and $m.source.dirty -isnot [bool]) -or ($null -ne $m.source.revision -and ($m.source.revision -isnot [string] -or $m.source.revision.Length -gt 256))){throw 'Explicit source revision and boolean/null dirty state required.'}
 if($m.artifacts -isnot [array] -or $m.artifacts.Count -lt 1 -or $m.artifacts.Count -gt 128){throw 'Artifacts count must be 1..128.'}
 $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase);$total=0L
 foreach($a in $m.artifacts){if($a -isnot [Collections.IDictionary] -or $a.kind -notin @('pe','pdb','mapping')){throw 'Artifact kind must be pe, pdb or mapping.'};$p=RV-Path $a.path;if(-not $seen.Add($p)){throw 'Duplicate artifact path.'};if($a.binaryFor){$null=RV-Path $a.binaryFor};if($a.declaredBuildId -and ($a.declaredBuildId -isnot [string] -or $a.declaredBuildId.Length -gt 256)){throw 'Invalid declaredBuildId.'};if(Test-Path -LiteralPath $p){$f=Get-Item -LiteralPath $p;if($f.PSIsContainer -or $f.Length -gt 268435456){throw 'Artifact must be a file <=256 MiB.'};$total+=$f.Length}else{if($a.kind -ne 'pdb'){throw 'Required artifact path missing.'}};if($total -gt 536870912){throw 'Total artifacts exceed 512 MiB.'}}
 foreach($a in $m.artifacts){if($a.kind -eq 'pdb' -and (-not $a.binaryFor -or @($m.artifacts|Where-Object {$_.kind -eq 'pe' -and $_.path -ieq $a.binaryFor}).Count -ne 1)){throw 'Each PDB must reference one explicit PE artifact path.'}}
}
function RV-Identities($Artifacts,[string]$Root){
 $findings=@();$status='Pass';$ids=@{}
 foreach($a in $Artifacts){if($a.missing){$findings+=@{status='Unknown';code='MissingPDB';file=$a.file};$status='Unknown';continue};$path=Resolve-QChild $Root $a.file
 if($a.kind -eq 'mapping'){$findings+=@{status='Unknown';code='Declared';declaredBuildId=$a.declaredBuildId;file=$a.file};if($status -ne 'Fail'){$status='Unknown'};continue}
 $id=[LocalDevTools.ReliabilityNativeSymbols]::Inspect($path,$a.kind);$ids[$a.originalPath]=$id;$findings+=@{status=$id.Status;code=$id.Format;identity=$id;file=$a.file};if($id.Status -eq 'Fail'){$status='Fail'}elseif($id.Status -eq 'Unknown' -and $status -ne 'Fail'){$status='Unknown'}
 }
 foreach($a in $Artifacts|Where-Object kind -eq 'pe'){$pairs=@($Artifacts|Where-Object {$_.kind -eq 'pdb' -and $_.binaryFor -ieq $a.originalPath});if($pairs.Count -eq 0){$findings+=@{status='Unknown';code='MissingPDB';file=$a.file};if($status -ne 'Fail'){$status='Unknown'}}}
 foreach($a in $Artifacts|Where-Object kind -eq 'pdb'){if($a.missing){continue};$pe=$ids[$a.binaryFor];$pdb=$ids[$a.originalPath];if($pe -and $pdb -and $pe.Status -eq 'Pass' -and $pdb.Status -eq 'Pass'){$match=$pe.Guid -eq $pdb.Guid -and $pe.Age -eq $pdb.Age;$findings+=@{status=$(if($match){'Pass'}else{'Fail'});code='NativeIdentityMatch';file=$a.file};if(-not $match){$status='Fail'}}}
 @{status=$status;findings=$findings}
}
function RV-Verify([string]$Root){
 $rootPath=RV-Path $Root;$mp=RV-Path (Join-Path $rootPath 'entry.json');$hp=RV-Path (Join-Path $rootPath 'entry.sha256')
 if((Get-Item -LiteralPath $hp).Length -gt 128){throw 'Invalid manifest digest file.'};if((Get-Content -LiteralPath $hp -Raw).Trim() -cne (RV-Hash $mp)){return @{status='Fail';findings=@(@{status='Fail';code='ManifestHashMismatch'})}}
 $m=Read-QJson $mp;Assert-QSchema $m;if($m.artifacts -isnot [array] -or $m.artifacts.Count -lt 1 -or $m.artifacts.Count -gt 128){throw 'Invalid stored inventory.'};$seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase);$total=0L
 foreach($a in $m.artifacts){if($a.file -notmatch '^payload-[0-9]{3}\.(pe|pdb|mapping)$' -or -not $seen.Add($a.file) -or $a.kind -notin @('pe','pdb','mapping') -or $a.sha256 -notmatch '^[A-F0-9]{64}$' -and -not $a.missing){throw 'Invalid stored artifact record.'};if($a.missing){continue};$p=Resolve-QChild $rootPath $a.file;$f=Get-Item -LiteralPath $p;$total+=$f.Length;if($f.Length -gt 268435456 -or $total -gt 536870912){throw 'Stored payload size limit.'};if($f.Length -ne $a.size -or (RV-Hash $p) -cne $a.sha256 -or $a.originalSha256 -cne $a.sha256){return @{status='Fail';findings=@(@{status='Fail';code='PayloadHashMismatch';file=$a.file})}}}
 $v=RV-Identities $m.artifacts $rootPath
 if($m.state -ne 'Verified' -and $v.status -eq 'Pass'){$v.status='Unknown';$v.findings+=@{status='Unknown';code='UnpromotedEntry'}}
 $v
}
