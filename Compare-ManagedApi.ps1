#requires -Version 7.1
<#
.SYNOPSIS
Compare declared public/protected metadata API in isolated bounded children; never loads targets.
.DESCRIPTION
Uses installed .NET PEReader/MetadataReader. Compares signatures, nested types, fields,
properties/accessors, events, bases, interfaces and generic constraints. Added/removed rows
are distinct. A removed/changed row fails; additions alone pass. Assembly identity is separate.
Custom attributes, interop layout/ABI and runtime semantics are not compatibility certification.
-TrustMetadata is required: MetadataReader accepts trusted inputs only. Isolation does not make arbitrary malicious assemblies safe. Unsupported metadata is Unknown. Child process isolation is not a security sandbox.
#>
[CmdletBinding()]param([Parameter(Mandatory)][string]$BaselinePath,[Parameter(Mandatory)][string]$CurrentPath,[ValidateRange(1,60)][int]$TimeoutSeconds=20,[switch]$TrustMetadata,[switch]$Json)
. "$PSScriptRoot/lib/QualityNative.ps1"
$r=New-NResult 'Compare-ManagedApi';$code=0
if(-not $TrustMetadata){$r.findings+=@{status='Blocked';reason='Explicit TrustMetadata acknowledgement required before decoding'};Finish-N $r 3 -Json:$Json}
try {
 $old=Test-NFile $BaselinePath;$new=Test-NFile $CurrentPath;$dumps=@()
 foreach($path in @($old,$new)){$p=Invoke-NProcess (Get-Process -Id $PID).Path @('-NoProfile','-NonInteractive','-File',"$PSScriptRoot/lib/QualityNativeMetadataWorker.ps1",'-Path',$path) $TimeoutSeconds 4194304;Add-NEvidence $r 'IsolatedMetadataDecoder' $p
  if($p.ExitCode -ne 0 -or $p.TimedOut -or $p.Truncated){$r.findings+=@{kind='UnsupportedOrMalformedMetadata';status='Unknown'};Finish-N $r 3 -Json:$Json}
  $d=[Text.Encoding]::UTF8.GetString($p.Output)|ConvertFrom-Json -AsHashtable -Depth 10;if($d.surface -isnot [array] -or $d.surface.Count -gt 20000 -or $d.identity -isnot [string]){throw 'Invalid bounded decoder response'};$dumps+=,$d
 }
 $r.assemblyIdentity=@{baseline=$dumps[0].identity;current=$dumps[1].identity;changed=$dumps[0].identity -cne $dumps[1].identity}
 $a=[Collections.Generic.HashSet[string]]::new([string[]]$dumps[0].surface,[StringComparer]::Ordinal);$b=[Collections.Generic.HashSet[string]]::new([string[]]$dumps[1].surface,[StringComparer]::Ordinal)
 foreach($row in $a){if(-not $b.Contains($row)){$code=2;$r.findings+=@{kind='RemovedOrChanged';declaration=$row}}};foreach($row in $b){if(-not $a.Contains($row)){$r.findings+=@{kind='AddedOrChanged';declaration=$row}}}
 $r.limitations=@('Declared metadata comparison, not all runtime compatibility.','Custom attributes including nullable annotations and interop layout semantics not compared.','Forwarders, pinned and function pointer signatures unsupported and return Unknown.','16 MiB input, 100000 rows/table and signature operations, 20000 surface rows, 4 MiB output per child.')
}catch{$r.error='Managed metadata setup or decoder response failed.';$code=125}
Finish-N $r $code -Json:$Json
