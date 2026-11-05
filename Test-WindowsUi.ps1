#requires -Version 7.0
<#
.SYNOPSIS
Checks a bounded owned-window UIA snapshot against explicit accessibility assertions.
.PARAMETER ProcessId
Explicit current-user owned process. All provider calls run in an isolated PS5.1 child.
.PARAMETER SnapshotPath
Offline schema1 snapshot with nodes[]; offline checks do not prove live accessibility.
.PARAMETER AssertionsPath
Schema1 context{}, checks[{id,selector:{automationId,name,controlType},name?,enabled?,keyboardFocusable?,patterns?}], workflow[] and optional focusOrder[].
.PARAMETER AllowActions
Explicit acknowledgement for declared Invoke/SetFocus/SetValue workflow only. Tab is Unsupported (exit 3).
.NOTES
Does not certify accessibility. No values/password contents are captured; UI names may still contain sensitive text.
#>
[CmdletBinding(DefaultParameterSetName='Live')]param([Parameter(Mandatory,ParameterSetName='Live')][ValidateRange(1,2147483647)][int]$ProcessId,[Parameter(Mandatory,ParameterSetName='Offline')][string]$SnapshotPath,[Parameter(Mandatory)][string]$AssertionsPath,[switch]$AllowActions,[ValidateRange(1,120)][int]$TimeoutSeconds=20,[ValidateRange(1,10000)][int]$MaxNodes=2000,[ValidateRange(1,40)][int]$MaxDepth=20,[string]$Destination,[switch]$Json)
$ErrorActionPreference='Stop';. (Join-Path $PSScriptRoot 'lib\QualityCommon.ps1');$r=New-QResult 'Test-WindowsUi' $(if($PSCmdlet.ParameterSetName -eq 'Offline'){'OfflineSnapshotAssertions'}else{'LiveOwnedUiAutomation'});$code=125
try{
 $assertions=Read-QJson $AssertionsPath;Assert-QSchema $assertions;if($assertions.checks -isnot [array] -or $assertions.checks.Count -lt 1 -or $assertions.checks.Count -gt 2000){throw 'checks must contain 1..2000 assertions.'}
 foreach($check in $assertions.checks){if($check -isnot [Collections.IDictionary] -or $check.id -isnot [string] -or $check.selector -isnot [Collections.IDictionary]){throw 'Each check requires id and selector object.'};$criteria=@('automationId','name','controlType'|Where-Object {$check.selector.Contains($_)});if(-not $criteria.Count){throw 'Selector must constrain an identity field.'};foreach($key in $criteria){if($check.selector[$key] -isnot [string]){throw 'Selector values must be strings.'}};foreach($key in @('enabled','keyboardFocusable')){if($check.Contains($key) -and $check[$key] -isnot [bool]){throw 'State expectations must be Boolean.'}};if($check.Contains('name') -and $check.name -isnot [string]){throw 'Expected name must be a string.'};if($check.Contains('patterns') -and $check.patterns -isnot [array]){throw 'patterns must be an array.'}}
 if($assertions.Contains('workflow') -and ($assertions.workflow -isnot [array] -or $assertions.workflow.Count -gt 100)){throw 'workflow must be an array of at most 100 actions.'}
 if($Destination){$dest=Assert-QPath $Destination -New}
 if($PSCmdlet.ParameterSetName -eq 'Offline'){$snapshot=Read-QJson $SnapshotPath;Assert-QSchema $snapshot;if($AllowActions -or ($assertions.Contains('workflow') -and $assertions.workflow.Count)){throw 'Offline snapshots cannot execute workflows.'}}else{
  $process=Get-Process -Id $ProcessId -ErrorAction Stop;$start=$process.StartTime.ToUniversalTime().ToString('o');$powershell=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe';$args=@('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-STA','-File',(Join-Path $PSScriptRoot 'lib\QualityUiWorker.ps1'),'-ProcessId',[string]$ProcessId,'-ExpectedStartUtc',$start,'-AssertionsPath',(Assert-QPath $AssertionsPath),'-MaxNodes',[string]$MaxNodes,'-MaxDepth',[string]$MaxDepth);if($AllowActions){$args+='-AllowActions'}
  $worker=Invoke-QProcess $powershell $args $PSScriptRoot $TimeoutSeconds 4194304;$r.executionEvidence+=@{stage='UiAutomationWorker';exitCode=$worker.ExitCode;timedOut=$worker.TimedOut;truncated=$worker.Truncated}
  if($worker.TimedOut -or $worker.Truncated){$r.status='Unknown';$r.error='UI provider worker timed out or exceeded output bounds.';$global:LASTEXITCODE=3;Complete-QResult $r -Json:$Json;return}
  try{$snapshot=[Text.Encoding]::UTF8.GetString($worker.Output)|ConvertFrom-Json -AsHashtable -Depth 40}catch{throw 'UI worker did not return valid JSON.'};if($worker.ExitCode -ne 0 -or -not $snapshot.valid){$r.status='Unknown';$r.error=$snapshot.error;$global:LASTEXITCODE=3;Complete-QResult $r -Json:$Json;return}
 }
 if($snapshot.nodes -isnot [array] -or $snapshot.nodes.Count -gt $MaxNodes){throw 'Invalid or excessive snapshot node array.'};$r.snapshot=$snapshot;$failure=$false;$unknown=$snapshot.Contains('truncated') -and $snapshot.truncated
 foreach($check in $assertions.checks){$matches=@($snapshot.nodes|Where-Object {$node=$_;$same=$true;foreach($key in @('automationId','name','controlType')){if($check.selector.Contains($key)){if(-not $node.Contains($key) -or $node[$key] -isnot [string] -or -not [string]::Equals($node[$key],$check.selector[$key],[StringComparison]::Ordinal)){$same=$false}}};$same})
  if($matches.Count -ne 1){$r.findings+=@{id=$check.id;status='Fail';reason='MissingOrAmbiguousSelector';matchCount=$matches.Count};$failure=$true;continue};$node=$matches[0];$ok=$true
  foreach($key in @('name','enabled','keyboardFocusable')){if($check.Contains($key)){if(-not $node.Contains($key) -or (ConvertTo-QCanonical $node[$key]) -cne (ConvertTo-QCanonical $check[$key])){$ok=$false}}};if($check.Contains('patterns')){if($node.patterns -isnot [array]){$ok=$false}else{foreach($pattern in $check.patterns){if($pattern -isnot [string]){throw 'Expected pattern names must be strings.'};if($pattern -cnotin $node.patterns){$ok=$false}}}}
  $r.findings+=@{id=$check.id;status=if($ok){'Pass'}else{'Fail'}};if(-not $ok){$failure=$true}
 }
 if($assertions.Contains('focusOrder')){if($assertions.focusOrder -isnot [array]){throw 'focusOrder must be an array.'};if($PSCmdlet.ParameterSetName -eq 'Offline' -or -not $snapshot.Contains('workflow')){$unknown=$true;$r.findings+=@{id='focusOrder';status='Unknown'}}else{$actual=@($snapshot.workflow|ForEach-Object {$_.focusAutomationId});$expected=@($assertions.focusOrder|ForEach-Object {if($_ -isnot [Collections.IDictionary] -or -not $_.Contains('automationId')){throw 'focusOrder entries require automationId.'};$_.automationId});$same=(ConvertTo-QCanonical $actual) -ceq (ConvertTo-QCanonical $expected);$r.findings+=@{id='focusOrder';status=if($same){'Pass'}else{'Fail'}};if(-not $same){$failure=$true}}}
 $r.status=if($failure){'Fail'}elseif($unknown){'Unknown'}else{'Pass'};$r.valid=$r.status -eq 'Pass';$code=if($failure){2}elseif($unknown){3}else{0};$r.limitations=@('Automated declared checks do not certify accessibility or screen-reader usability.','Offline snapshots do not establish live provider behavior.','UI names can contain sensitive text; password values are never captured.','Actions require explicit acknowledgement and target identity/focus verification.')
 if($Destination){$null=New-Item -ItemType Directory -Path $dest;$snapshot|ConvertTo-Json -Depth 40|Set-Content -LiteralPath (Join-Path $dest 'snapshot.json') -Encoding utf8;$r.artifacts+=@{path=(Join-Path $dest 'snapshot.json');producingExitCode=if($r.executionEvidence.Count){$r.executionEvidence[0].exitCode}else{$null}};$r|ConvertTo-Json -Depth 50|Set-Content -LiteralPath (Join-Path $dest 'result.json') -Encoding utf8}
}catch{$r.status='Blocked';$r.error=$_.Exception.Message;$code=125};$global:LASTEXITCODE=$code;Complete-QResult $r -Json:$Json
