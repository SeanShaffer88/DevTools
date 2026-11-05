<#
.SYNOPSIS
Adds, verifies or finds explicitly selected local crash symbol entries without loading targets.
.DESCRIPTION
Add validates up to 128 artifacts (256 MiB each, 512 MiB total), stages copies and atomically
promotes only verified native PE RSDS/native MSF7 PDB GUID+age matches. Missing/unsupported
PDBs and declared Android mappings remain Unknown in staging. Existing entries are never
replaced. Intended for trusted build artifacts; this bounded parser is not a general PDB validator.
Entry SHA256 detects accidental manifest changes, not malicious rewriting of manifest and digest.
No upload, target execution, Git inference or home scanning. Source revision/dirty are declarations.
.PARAMETER Mode
Add, Verify or metadata-only Find. Find does not validate payloads or certify identity.
.PARAMETER VaultRoot
Explicit absolute local vault directory. Add can create this directory.
.PARAMETER BuildManifestPath
Explicit schema1 build manifest with buildId, source revision/dirty, and pe/pdb/mapping artifacts.
PDB binaryFor must name the exact PE artifact path. Missing requested PDBs remain Unknown.
.PARAMETER EntryPath
Explicit entry or preserved staging directory for Verify.
.PARAMETER BuildId
Exact declared build ID for Find.
.PARAMETER Json
Emit schema1 JSON. Exits: 0 Pass, 2 Fail, 3 Unknown, 125 SetupError.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][ValidateSet('Add','Verify','Find')][string]$Mode,[string]$VaultRoot,[string]$BuildManifestPath,[string]$EntryPath,[string]$BuildId,[switch]$Json)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/lib/ReliabilityNativeSymbols.ps1"
$r=New-QResult 'Manage-CrashSymbolVault' $Mode
$r.limitations=@('Hashes and editable digest are integrity checks, not cryptographic attestation.','Source state and mapping correlation are declarations. Static native identity parsing does not validate all PDB streams.','Concurrent hostile filesystem mutation is outside the trusted local build-artifact contract.')
$stage=$null
try {
 if($Mode -eq 'Add'){
 if(-not $VaultRoot -or -not $BuildManifestPath -or $EntryPath -or $BuildId){throw 'Add requires only VaultRoot and BuildManifestPath.'}
 $vault=RV-Path $VaultRoot;$manifest=Read-QJson (RV-Path $BuildManifestPath);RV-Manifest $manifest
 $key=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($manifest.buildId.ToUpperInvariant()))).ToLowerInvariant();$dest=Join-Path $vault $key
 if(Test-Path -LiteralPath $dest){throw 'Build entry already exists.'}
 # All manifest paths, associations and size budgets have passed before the first write.
 $null=[IO.Directory]::CreateDirectory($vault);$stage=Join-Path $vault ('.staging-'+$key+'-'+[Guid]::NewGuid().ToString('N'));$null=[IO.Directory]::CreateDirectory($stage)
 $stored=[ordered]@{schemaVersion=1;buildId=$manifest.buildId;source=$manifest.source;state='Staging';artifacts=@()};$i=0
 foreach($a in $manifest.artifacts){$p=RV-Path $a.path;$file=('payload-{0:000}.{1}' -f $i++,$a.kind);$record=[ordered]@{originalPath=$p;kind=$a.kind;file=$file;binaryFor=$a.binaryFor;declaredBuildId=$a.declaredBuildId;missing=$false;size=$null;originalSha256=$null;sha256=$null}
 if(-not (Test-Path -LiteralPath $p)){$record.missing=$true}else{$record.originalSha256=RV-Hash $p;$copy=Join-Path $stage $file;[IO.File]::Copy($p,$copy,$false);$record.size=(Get-Item -LiteralPath $copy).Length;$record.sha256=RV-Hash $copy;if($record.originalSha256 -cne $record.sha256){throw 'Artifact changed while copying.'}}
 $stored.artifacts+= $record
 }
 $v=RV-Identities $stored.artifacts $stage;$r.status=$v.status;$r.findings=$v.findings;$stored.state=if($v.status -eq 'Pass'){'Verified'}else{'Unverified'+$v.status}
 $mp=Join-Path $stage 'entry.json';$stored|ConvertTo-Json -Depth 30|Set-Content -LiteralPath $mp -Encoding utf8;RV-Hash $mp|Set-Content -LiteralPath (Join-Path $stage 'entry.sha256') -Encoding ascii
 # Re-read persisted evidence before promotion; no replacement operation is used.
 $check=RV-Verify $stage;if($check.status -ne $v.status){throw 'Persisted entry verification changed.'}
 if($r.status -eq 'Pass'){[IO.Directory]::Move($stage,$dest);$stage=$null;$r.artifacts=@(@{path=$dest;state='Verified'})}else{$r.artifacts=@(@{path=$stage;state=$stored.state})}
 }elseif($Mode -eq 'Verify'){
 if(-not $EntryPath -or $VaultRoot -or $BuildManifestPath -or $BuildId){throw 'Verify requires only EntryPath.'};$v=RV-Verify $EntryPath;$r.status=$v.status;$r.findings=$v.findings
 }else{
 if(-not $VaultRoot -or -not $BuildId -or $EntryPath -or $BuildManifestPath){throw 'Find requires only VaultRoot and BuildId.'};$vault=RV-Path $VaultRoot;if($BuildId -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$'){throw 'Invalid buildId.'};$key=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($BuildId.ToUpperInvariant()))).ToLowerInvariant();$dest=RV-Path (Join-Path $vault $key)
 $r.status='Unknown';if(Test-Path -LiteralPath $dest){$m=Read-QJson (RV-Path (Join-Path $dest 'entry.json'));Assert-QSchema $m;if($m.buildId -ieq $BuildId){$r.artifacts=@(@{path=$dest;buildId=$m.buildId;state=$m.state;metadataOnly=$true})}};$r.findings=@(@{status='Unknown';code='MetadataOnlyQuery';found=($r.artifacts.Count -gt 0)})
 }
}catch{$r.status='SetupError';$r.error=$_.Exception.Message;if($stage){$r.artifacts=@(@{path=$stage;state='InterruptedOrFailedStaging'})}}
$r.valid=$r.status -eq 'Pass';Complete-QResult $r -Json:$Json
exit (@{Pass=0;Fail=2;Unknown=3;SetupError=125}[$r.status])
