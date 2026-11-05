#requires -Version 7.0
<#
.SYNOPSIS
Runs explicitly trusted migration cases against new working copies, never original fixtures.
.PARAMETER PlanPath
Schema 1 cases[]: id, source (fixture-relative folder), fromVersion, toVersion,
executable, arguments[] using {InputRoot}/{OutputRoot}/{WorkRoot}, expectedExitCodes[],
assertions.jsonFiles[] (path, versionPointer, expectedVersion, preservePointers[], equals{}),
assertions.files[] (path, optional sha256), optional rollback {executable,arguments,expectedExitCodes,assertions}.
.NOTES
New working directories are not a security sandbox. Only run trusted migrators.
Rollback is tested only when explicitly declared; timeout is never reported as migration success.
#>
[CmdletBinding()]param([Parameter(Mandatory)][string]$FixtureRoot,[Parameter(Mandatory)][string]$PlanPath,[Parameter(Mandatory)][string]$Destination,[switch]$ExecuteTrusted,[switch]$Json)
$ErrorActionPreference='Stop';. (Join-Path $PSScriptRoot 'lib\QualityCommon.ps1');$r=New-QResult 'Test-DataMigration' 'TrustedWorkingCopyMigration';$code=125
function Assert-MigrationChecks($Assertions,[string]$OutputRoot,$FrozenInput,$FromVersion,$ToVersion) {
 $findings=[Collections.Generic.List[object]]::new();if($Assertions -isnot [Collections.IDictionary]){throw 'Assertions object required.'}
 if($Assertions.Contains('jsonFiles')){if($Assertions.jsonFiles -isnot [array]){throw 'jsonFiles must be an array.'};foreach($check in $Assertions.jsonFiles){$path=Resolve-QChild $OutputRoot $check.path
  if(-not(Test-Path -LiteralPath $path)){$findings.Add(@{id='json.exists';path=$check.path;status='Fail'});continue};try{$out=Read-QJson $path;$original=$FrozenInput[$check.path]}catch{$findings.Add(@{id='json.parse';path=$check.path;status='Fail'});continue}
  $vp=if($check.Contains('versionPointer')){[string]$check.versionPointer}else{'/schemaVersion'};$observed=Get-QPointer $out $vp;$expected=if($check.Contains('expectedVersion')){$check.expectedVersion}else{$ToVersion};$matches=$observed.exists -and (ConvertTo-QCanonical $observed.value) -ceq (ConvertTo-QCanonical $expected);$findings.Add(@{id='json.version';path=$check.path;status=if($matches){'Pass'}else{'Fail'}})
  if($check.Contains('preservePointers')){if($check.preservePointers -isnot [array]){throw 'preservePointers must be an array.'};foreach($p in $check.preservePointers){$before=Get-QPointer $original $p;$after=Get-QPointer $out $p;$same=$before.exists -and $after.exists -and (ConvertTo-QCanonical $before.value) -ceq (ConvertTo-QCanonical $after.value);$findings.Add(@{id='json.preserved';path=$check.path;pointer=$p;status=if($same){'Pass'}else{'Fail'}})}}
  if($check.Contains('equals')){if($check.equals -isnot [Collections.IDictionary]){throw 'equals must be an object keyed by JSON pointer.'};foreach($p in $check.equals.Keys){$after=Get-QPointer $out $p;$same=$after.exists -and (ConvertTo-QCanonical $after.value) -ceq (ConvertTo-QCanonical $check.equals[$p]);$findings.Add(@{id='json.equals';path=$check.path;pointer=$p;status=if($same){'Pass'}else{'Fail'}})}}
 }}
 if($Assertions.Contains('files')){if($Assertions.files -isnot [array]){throw 'files must be an array.'};foreach($check in $Assertions.files){$p=Resolve-QChild $OutputRoot $check.path;$ok=Test-Path -LiteralPath $p -PathType Leaf;if($check.Contains('sha256')){if($check.sha256 -isnot [string] -or $check.sha256 -notmatch '^[A-Fa-f0-9]{64}$'){throw 'Invalid expected hash.'};if($ok){$ok=(Get-FileHash -LiteralPath $p).Hash -ieq $check.sha256}};$findings.Add(@{id='file.expected';path=$check.path;status=if($ok){'Pass'}else{'Fail'}})}}
 if($findings.Count -eq 0){throw 'At least one actual output assertion is required.'};$findings.ToArray()
}
function Invoke-MigrationPhase($Phase,[string]$CaseRoot,[string]$InputRoot,[string]$OutputRoot,[int]$Timeout) {
 $args=@($Phase.arguments|ForEach-Object{$_.Replace('{InputRoot}',$InputRoot).Replace('{OutputRoot}',$OutputRoot).Replace('{WorkRoot}',$CaseRoot)});Invoke-QProcess $Phase.executable $args $CaseRoot $Timeout 2097152
}
try{
 $root=Assert-QPath $FixtureRoot;if(-not(Get-Item -LiteralPath $root).PSIsContainer){throw 'FixtureRoot must be a directory.'};$dest=Assert-QPath $Destination -New
 if($dest.StartsWith($root.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase) -or $root.StartsWith($dest.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Fixture and destination roots must not overlap.'}
 $plan=Read-QJson $PlanPath;Assert-QSchema $plan;if($plan.cases -isnot [array] -or $plan.cases.Count -lt 1 -or $plan.cases.Count -gt 64){throw 'cases must contain 1..64 cases.'};$seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
 foreach($case in $plan.cases){if($case -isnot [Collections.IDictionary] -or $case.id -isnot [string] -or $case.id -notmatch '^[A-Za-z][A-Za-z0-9_-]{0,63}$' -or -not $seen.Add($case.id)){throw 'Invalid or duplicate case id.'};$source=Resolve-QChild $root $case.source;if(-not(Test-Path -LiteralPath $source -PathType Container)){throw 'Case source must be a fixture directory.'};$null=Get-QFiles $source;$null=Assert-QInteger $case.fromVersion 0 ([long]::MaxValue) 'fromVersion';$null=Assert-QInteger $case.toVersion 0 ([long]::MaxValue) 'toVersion'
  foreach($phase in @($case)+$(if($case.Contains('rollback')){@($case.rollback)}else{@()})){if($phase.arguments -isnot [array] -or $phase.expectedExitCodes -isnot [array] -or $phase.expectedExitCodes.Count -lt 1){throw 'Each phase requires arguments[] and expectedExitCodes[].'};foreach($arg in $phase.arguments){if($arg -isnot [string] -or $arg.Contains([char]0) -or $arg.IndexOf($root,[StringComparison]::OrdinalIgnoreCase) -ge 0){throw 'Invalid argument or original fixture path supplied to child.'}};foreach($exitCode in $phase.expectedExitCodes){$null=Assert-QInteger $exitCode -2147483648 2147483647 'expectedExitCode'};$null=Get-Command -Name $phase.executable -CommandType Application -ErrorAction Stop|Select-Object -First 1}
  $timeout=if($case.Contains('timeoutSeconds')){Assert-QInteger $case.timeoutSeconds 1 300 'timeoutSeconds'}else{20}
  if($case.Contains('expectedInputInvalid') -and $case.expectedInputInvalid -isnot [bool]){throw 'expectedInputInvalid must be Boolean.'};if($case.Contains('expectedInputInvalid') -and $case.expectedInputInvalid -and 0 -in $case.expectedExitCodes){throw 'Explicit invalid-input cases must require a nonzero migration outcome.'}
  foreach($phase in @($case)+$(if($case.Contains('rollback')){@($case.rollback)}else{@()})){
   $a=$phase.assertions;if($a -isnot [Collections.IDictionary]){throw 'Assertions object required.'}
   if(-not $a.Contains('jsonFiles') -or $a.jsonFiles -isnot [array] -or $a.jsonFiles.Count -eq 0){throw 'Plan requires at least one input JSON version check.'}
   $expectedVersion=if([object]::ReferenceEquals($phase,$case)){$case.toVersion}else{$case.fromVersion}
   foreach($group in @('jsonFiles','files')){if($a.Contains($group)){
    if($a[$group] -isnot [array]){throw 'Assertion groups must be arrays.'}
    foreach($entry in $a[$group]){
     if($entry -isnot [Collections.IDictionary] -or $entry.path -isnot [string]){throw 'Assertion requires a path string.'};$null=Resolve-QChild (Join-Path $dest $case.id) $entry.path
     if($group -ceq 'jsonFiles'){
      $sourceFile=Resolve-QChild $source $entry.path;if(-not(Test-Path -LiteralPath $sourceFile -PathType Leaf)){throw 'Selected input JSON evidence is missing.'}
      if($entry.Contains('expectedVersion')){$null=Assert-QInteger $entry.expectedVersion 0 ([long]::MaxValue) 'expectedVersion';if((ConvertTo-QCanonical $entry.expectedVersion) -cne (ConvertTo-QCanonical $expectedVersion)){throw 'expectedVersion contradicts the declared migration or rollback version.'}}
      if($entry.Contains('preservePointers') -and $entry.preservePointers -isnot [array]){throw 'preservePointers must be an array.'}
      if($entry.Contains('equals') -and $entry.equals -isnot [Collections.IDictionary]){throw 'equals must be an object.'}
      $pointers=@($(if($entry.Contains('versionPointer')){$entry.versionPointer}else{'/schemaVersion'}));if($entry.Contains('preservePointers')){$pointers+= $entry.preservePointers};if($entry.Contains('equals')){$pointers+=@($entry.equals.Keys)}
      foreach($pointer in $pointers){if($pointer -isnot [string] -or ($pointer -cne '' -and -not $pointer.StartsWith('/')) -or $pointer -match '~(?![01])'){throw 'Invalid JSON pointer configuration.'}}
      if($entry.Contains('versionPointer') -and $entry.versionPointer -isnot [string]){throw 'versionPointer must be a string.'}
     }elseif($entry.Contains('sha256') -and ($entry.sha256 -isnot [string] -or $entry.sha256 -notmatch '^[A-Fa-f0-9]{64}$')){throw 'Invalid expected hash.'}
    }
   }}
  }
 }
 if(-not $ExecuteTrusted){$r.status='Blocked';$r.error='ExecuteTrusted acknowledgement is required.';$code=3}else{
 $originalHash=Get-QTreeHash $root;$null=New-Item -ItemType Directory -Path $dest;$r.cases=@();$failure=$false;$unknown=$false
 foreach($case in $plan.cases){$caseRoot=Join-Path $dest $case.id;$input=Join-Path $caseRoot 'input';$output=Join-Path $caseRoot 'output';$null=New-Item -ItemType Directory -Path $input,$output; $source=Resolve-QChild $root $case.source
  foreach($file in Get-QFiles $source){$relative=[IO.Path]::GetRelativePath($source,$file.FullName);$to=Resolve-QChild $input $relative;$null=[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($to));[IO.File]::Copy($file.FullName,$to,$false)}
  $inputFindings=@();$inputInvalid=$false;$frozenInput=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
  foreach($check in $case.assertions.jsonFiles){$beforePath=Resolve-QChild $input $check.path;$vp=if($check.Contains('versionPointer')){$check.versionPointer}else{'/schemaVersion'};try{$beforeJson=Read-QJson $beforePath;$frozenInput[$check.path]=$beforeJson;$beforeVersion=Get-QPointer $beforeJson $vp;$match=$beforeVersion.exists -and (ConvertTo-QCanonical $beforeVersion.value) -ceq (ConvertTo-QCanonical $case.fromVersion);if(-not $match){$inputInvalid=$true};$inputFindings+=@{id='input.version';path=$check.path;status=if($match){'Pass'}else{'Fail'}}}catch{$inputInvalid=$true;$inputFindings+=@{id='input.parse';path=$check.path;status='Fail'}}}
  if($case.Contains('rollback')){foreach($check in $case.rollback.assertions.jsonFiles){if(-not $frozenInput.ContainsKey($check.path)){try{$frozenInput[$check.path]=Read-QJson (Resolve-QChild $input $check.path)}catch{}}}}
  $expectedInvalid=$case.Contains('expectedInputInvalid') -and $case.expectedInputInvalid
  if(($inputInvalid -and -not $expectedInvalid) -or ($expectedInvalid -and -not $inputInvalid)){$failure=$true;$r.cases+=@(@{id=$case.id;status='Fail';inputFindings=$inputFindings;migrationExecution='NotPerformed';reason='Input validation does not match the declared valid/invalid-input expectation.'});continue}
  $timeout=if($case.Contains('timeoutSeconds')){[int]$case.timeoutSeconds}else{20};$phase=Invoke-MigrationPhase $case $caseRoot $input $output $timeout;[IO.File]::WriteAllBytes((Join-Path $caseRoot 'migration.stdout.log'),$phase.Output);[IO.File]::WriteAllText((Join-Path $caseRoot 'migration.stderr.log'),$phase.Error)
  $caseResult=[ordered]@{id=$case.id;exitCode=$phase.ExitCode;timedOut=$phase.TimedOut;truncated=$phase.Truncated;status='Unknown';inputFindings=$inputFindings;expectedInputInvalid=$expectedInvalid;assertions=@();rollback=$null};$r.executionEvidence+=@{case=$case.id;phase='Migration';exitCode=$phase.ExitCode;timedOut=$phase.TimedOut;truncated=$phase.Truncated}
  if($phase.TimedOut -or $phase.Truncated){$unknown=$true}else{
   if($phase.ExitCode -notin $case.expectedExitCodes){$caseResult.status='Fail';$failure=$true}else{try{$caseResult.assertions=@(Assert-MigrationChecks $case.assertions $output $frozenInput $case.fromVersion $case.toVersion);$bad=@($caseResult.assertions|Where-Object status -ne 'Pass').Count -gt 0;$caseResult.status=if($bad){'Fail'}else{'Pass'};if($bad){$failure=$true}}catch{$caseResult.status='Fail';$caseResult.error=$_.Exception.Message;$failure=$true}}
  }
  if($case.Contains('rollback')){$back=Invoke-MigrationPhase $case.rollback $caseRoot $input $output $timeout;[IO.File]::WriteAllBytes((Join-Path $caseRoot 'rollback.stdout.log'),$back.Output);[IO.File]::WriteAllText((Join-Path $caseRoot 'rollback.stderr.log'),$back.Error);$checks=@();$state='Unknown';if(-not $back.TimedOut -and -not $back.Truncated){if($back.ExitCode -in $case.rollback.expectedExitCodes){try{$checks=@(Assert-MigrationChecks $case.rollback.assertions $output $frozenInput $case.fromVersion $case.fromVersion);$state=if(@($checks|Where-Object status -ne 'Pass').Count){'Fail'}else{'Pass'}}catch{$state='Fail'}}else{$state='Fail'}};if($state -eq 'Fail'){$failure=$true}elseif($state -eq 'Unknown'){$unknown=$true};$caseResult.rollback=@{status=$state;exitCode=$back.ExitCode;assertions=$checks};$r.executionEvidence+=@{case=$case.id;phase='Rollback';exitCode=$back.ExitCode;timedOut=$back.TimedOut;truncated=$back.Truncated}}
  $r.cases+=@($caseResult)
 }
 $unchanged=(Get-QTreeHash $root) -ceq $originalHash;$r.findings+=@{id='fixture.originalUnchanged';status=if($unchanged){'Pass'}else{'Fail'}};if(-not $unchanged){$failure=$true};$r.status=if($failure){'Fail'}elseif($unknown){'Unknown'}else{'Pass'};$r.valid=$r.status -eq 'Pass';$code=if($failure){2}elseif($unknown){3}else{0};$r.destination=$dest
 $r.limitations=@('Trusted migrators run as the current user; working copies are not a security sandbox.','Only declared output assertions and explicitly configured rollback are checked.','A timed-out migration never becomes a passing migration even when rollback passes.','Logs can contain sensitive child output.');[IO.File]::WriteAllText((Join-Path $dest 'result.json'),(ConvertTo-Json -InputObject $r -Depth 50))
 }
}catch{$r.status='Blocked';$r.error=$_.Exception.Message;$code=125};$global:LASTEXITCODE=$code;Complete-QResult $r -Json:$Json
