#requires -Version 7.0
<#
.SYNOPSIS
Diagnose supplied operation evidence without executing it or changing settings.
.DESCRIPTION
Reads schemaVersion 1 evidence (operation, exitCode, stderr, stdout, context
with host and sandbox strings). Evidence is limited to 256 KiB; text fields
to 64 KiB, operation/context strings to 256 characters. Optional
context.windowsSandboxConfigured is boolean and never establishes causality.
Reads own execution policy and language mode, and optional selected file
attributes, zone-stream presence and aggregate ACL metadata. No identities,
paths or supplied text are emitted. No global configuration is read.
Pass means diagnostic attribution from supplied evidence, not operation repair.
Exit codes: 0 diagnosis, 2 missing executable, 3 inconclusive, 125 invalid setup.
.PARAMETER EvidencePath
Local bounded JSON evidence file. Supplied text is never executed.
.PARAMETER TargetPath
Optional local file/directory for metadata inspection only.
.PARAMETER ExecutablePath
Optional local executable path for existence inspection only; never launched.
.PARAMETER Json
Emit the schemaVersion 1 result as JSON.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$EvidencePath,[string]$TargetPath,[string]$ExecutablePath,[switch]$Json)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'lib/ReliabilityNativeCommon.ps1')
$r=New-QResult 'Get-PolicyDiagnostics' 'Supplied evidence and own process; selected local metadata only'
$r.limitations=@('Supplied evidence is not independently authenticated.','Diagnostic attribution does not repair or retry the original operation.','ACL metadata does not establish effective access or policy compliance.','Concurrent filesystem changes can invalidate metadata; no target is executed.')
try {
 $p=Assert-RNPath $EvidencePath
 $f=Get-Item -LiteralPath $p -Force
 if($f.PSIsContainer -or $f.Length -gt 262144){throw 'Invalid evidence size.'}
 # Limit the actual read too, including growth after the initial metadata check.
 $stream=[IO.File]::OpenRead($p)
 try {$buffer=[byte[]]::new(262145);$count=0;while($count -lt $buffer.Length){$n=$stream.Read($buffer,$count,$buffer.Length-$count);if(!$n){break};$count+=$n};if($count -gt 262144){throw 'Invalid evidence size.'};$bytes=$buffer[0..($count-1)]}finally{$stream.Dispose()}
 $e=[Text.UTF8Encoding]::new($false,$true).GetString($bytes)|ConvertFrom-Json -AsHashtable -Depth 8
 if($e -isnot [Collections.IDictionary]){throw 'Invalid evidence object.'}
 Assert-QSchema $e
 $null=Assert-QInteger $e.exitCode ([int]::MinValue) ([int]::MaxValue) 'exitCode'
 foreach($key in @('operation','stderr','stdout')){if($e[$key] -isnot [string] -or $e[$key].Length -gt 65536){throw 'Invalid evidence field.'}}
 if([string]::IsNullOrWhiteSpace($e.operation) -or $e.operation.Length -gt 256 -or $e.context -isnot [Collections.IDictionary]){throw 'Invalid context.'}
 foreach($key in @('host','sandbox')){if($e.context[$key] -isnot [string] -or $e.context[$key].Length -gt 256){throw 'Invalid context field.'}}
 if($e.context.Contains('windowsSandboxConfigured') -and $e.context.windowsSandboxConfigured -isnot [bool]){throw 'Invalid sandbox flag.'}
 $target=if($TargetPath){Assert-RNPath $TargetPath}else{$null}
 $executable=if($ExecutablePath){Assert-RNPath $ExecutablePath}else{$null}
 $r.artifacts+=@{id='supplied-evidence';sha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([byte[]]$bytes));bytes=$count}
 $r.executionEvidence+=@{operation='supplied-operation';exitCode=$e.exitCode;executed=$false}
 $policy=@();try {foreach($entry in Get-ExecutionPolicy -List){$policy+=@{scope=[string]$entry.Scope;policy=[string]$entry.ExecutionPolicy}}}catch{$r.limitations+='Own execution policy unavailable.'}
 $r.executionEvidence+=@{operation='own-process-context';languageMode=[string]$ExecutionContext.SessionState.LanguageMode;executionPolicies=$policy}
 if($target){
  $metadata=@{id='selected-target';exists=(Test-Path -LiteralPath $target);attributes=$null;aclStatus='NotPerformed';aclRuleCount=$null;aclProtected=$null;zoneStreamPresent=$null}
  if($metadata.exists){
   $item=Get-Item -LiteralPath $target -Force;$metadata.attributes=[string]$item.Attributes
   try {$acl=Get-Acl -LiteralPath $target;$metadata.aclRuleCount=@($acl.Access).Count;$metadata.aclProtected=$acl.AreAccessRulesProtected;$metadata.aclStatus='Observed'}catch{$metadata.aclStatus='Unavailable'}
   if(!$item.PSIsContainer -and $IsWindows){try {$metadata.zoneStreamPresent=$null -ne (Get-Item -LiteralPath $target -Stream Zone.Identifier -ErrorAction SilentlyContinue)}catch{$metadata.zoneStreamPresent=$null}}
  };$r.artifacts+=$metadata
 }
 $code=3;$category='PolicyUnknown';$confidence='Unknown';$observed=@('supplied-evidence');$next='Collect a specific policy or operating-system diagnostic for the failed operation.';$fix='Review the specific restriction with its owner before changing the operation.'
 $text=$e.stderr+"`n"+$e.stdout
 if($executable -and !(Test-Path -LiteralPath $executable -PathType Leaf)){
  $category='MissingTool';$code=2;$confidence='Observed';$observed=@('selected-executable');$next='Verify the explicitly selected executable location.';$fix='Select the correct existing executable or provision the required tool through the approved workflow.'
 }elseif($e.exitCode -ne 0){
  if($text -match '(?i)running scripts is disabled on this system|cannot be loaded because .*not digitally signed|execution of scripts is disabled'){$category='ScriptPolicyRestriction';$code=0;$confidence='ExplicitSupplied';$next='Compare the script signing requirements with the listed execution policy scopes.';$fix='Use an approved signed script or ask the policy owner for the permitted workflow.'}
  elseif($text -match '(?i)(denied|blocked|forbidden) by (the )?sandbox (configuration|policy)|sandbox (configuration|policy) (explicitly )?(denied|blocked|forbids)'){$category='SandboxConfigurationDenial';$code=0;$confidence='ExplicitSupplied';$next='Review the selected sandbox operation against its declared permissions.';$fix='Use an operation and location permitted by the configured sandbox.'}
  elseif($text -match '(?i)sharing violation|being used by another process|0x80070020'){$category='SharingViolation';$code=0;$confidence='ExplicitSupplied';$next='Identify the owner of the conflicting open handle using an authorized diagnostic.';$fix='Coordinate closure of the conflicting handle with its owner.'}
  elseif($text -match '(?i)access (is )?denied|0x80070005|unauthorizedaccess'){$category='AccessDenied';$next='Collect operation-specific authorization, policy and sharing evidence.';$fix='Ask the resource owner to confirm the permitted operation; generic denial does not prove an ACL cause.'}
  elseif($text -match '(?i)commandnotfoundexception|executable (was )?not found|no such file or directory'){$category='MissingTool';$confidence='SuppliedUnverified';$next='Supply the explicit executable path to verify its presence.';$fix='Confirm the tool location before retrying.'}
 }
 $r.findings+=@{category=$category;confidence=$confidence;observedEvidence=$observed;nextDiagnosticAction=$next;suggestedFix=$fix}
 if($executable){$r.artifacts+=@{id='selected-executable';exists=(Test-Path -LiteralPath $executable -PathType Leaf)}}
 Finish-RN $r $code -Json:$Json
}catch {
 $r.error=@{code='InvalidOrUnreadableInput';message='Input validation or local metadata inspection failed; supplied values are omitted.'}
 Finish-RN $r 125 -Json:$Json
}
