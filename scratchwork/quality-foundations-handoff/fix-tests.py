from pathlib import Path
p=Path('tests/fixtures/quality/migrator.ps1');s=p.read_text().replace('$d.schemaVersion=2', '''if($Mode -eq 'MutateBoth'){$d.keep.unicode='changed';$d|ConvertTo-Json -Depth 10|Set-Content -LiteralPath (Join-Path $InputRoot 'settings.json')}
$d.schemaVersion=2''');p.write_text(s)
p=Path('tests/Test-QualityFoundations.ps1');s=p.read_text().replace("'work/quality-foundations-handoff/run-'","'scratchwork/quality-foundations-handoff/run-'")
a=s.index(" Check 'original fixtures unchanged'")
s=s[:a]+''' foreach($regression in @('contradictory','rollback-contradictory','missing-json','bad-pointer','mutate-both')){
  $phase=Phase $(if($regression -ceq 'mutate-both'){'MutateBoth'}else{'Migrate'})
  $case=@{id='regression';source='valid';fromVersion=1;toVersion=2;executable=$phase.executable;arguments=$phase.arguments;expectedExitCodes=@(0);assertions=@{jsonFiles=@(@{path='settings.json';preservePointers=@('/keep')})}}
  $expected=125
  switch($regression){
   'contradictory'{$case.assertions.jsonFiles[0].expectedVersion=1}
   'rollback-contradictory'{$back=Phase 'Rollback';$back.assertions=@{jsonFiles=@(@{path='settings.json';expectedVersion=2})};$case.rollback=$back}
   'missing-json'{$case.assertions=@{files=@(@{path='rejected.txt'})};$case.expectedInputInvalid=$true;$case.expectedExitCodes=@(7)}
   'bad-pointer'{$case.assertions.jsonFiles[0].versionPointer='bad';$case.expectedInputInvalid=$true;$case.expectedExitCodes=@(7)}
   'mutate-both'{$expected=2}
  }
  $regPlan=SaveJson @{schemaVersion=1;cases=@($case)} ($regression+'.plan.json')
  $reg=Run ('migration-'+$regression) 'Test-DataMigration.ps1' @{FixtureRoot=$inputs;PlanPath=$regPlan;Destination=(Join-Path $work $regression);ExecuteTrusted=$true} $expected
  if($expected -eq 125){Check ($regression+' no execution or writes') ($reg.executionEvidence.Count -eq 0 -and -not(Test-Path (Join-Path $work $regression)))}
  if($regression -ceq 'mutate-both'){Check 'frozen preservation rejects mutated copies' (@($reg.cases[0].assertions|Where-Object { $_.id -ceq 'json.preserved' -and $_.status -ceq 'Fail'}).Count -eq 1)}
 }
'''+s[a:]
a=s.index(" $noInstrument=SaveJson")
s=s[:a]+''' $safeExe=Join-Path $work 'asan-safe/fixture.exe'
 foreach($kind in @('fake-runtime','missing-symbols','missing-flag')){
  $bytes=[IO.File]::ReadAllBytes($safeExe)
  $binary=[Text.Encoding]::Latin1.GetString($bytes)
  if($kind -ceq 'fake-runtime'){$binary=$binary.Replace('clang_rt.asan_dynamic-x86_64.dll',('fake_asan.dll'+([string][char]0)*18))}
  if($kind -ceq 'missing-symbols'){$binary=$binary.Replace('__asan_','__fake_')}
  $artifact=Join-Path $work ($kind+'.exe');[IO.File]::WriteAllBytes($artifact,[Text.Encoding]::Latin1.GetBytes($binary))
  $copyArgs=@('-NoProfile','-File',(Join-Path $fixture 'copy-artifact.ps1'),'-Source',$artifact,'-Destination','{WorkRoot}/fixture.exe')
  if($kind -cne 'missing-flag'){$copyArgs+=@('/fsanitize=address')}
  $regPlan=SaveJson @{schemaVersion=1;compilerPath=$pwsh;compileArguments=$copyArgs;executablePath='fixture.exe';runArguments=@();instrumentation='AddressSanitizer'} ($kind+'.plan.json')
  $reg=Run ('asan-'+$kind) 'Invoke-NativeMemoryTest.ps1' @{ProjectPath=$fixture;BuildManifestPath=$regPlan;Destination=(Join-Path $work ('asan-'+$kind));ExecuteTrusted=$true} 3
  Check ($kind+' never executed') ($reg.executionEvidence.Count -eq 1 -and $reg.status -ceq 'Unknown')
 }
'''+s[a:]
a=s.index("  $budget=Run 'ui-worker-budget'")
s=s[:a]+'''  $tabPlan=SaveJson @{schemaVersion=1;checks=$rootAssertions.checks;workflow=@(@{action='Tab'})} 'ui.tab.plan.json'
  $tab=Run 'ui-tab-unsupported' 'Test-WindowsUi.ps1' @{ProcessId=$ui.Id;AssertionsPath=$tabPlan;AllowActions=$true} 3
  Check 'Tab explicitly unsupported' ($tab.status -ceq 'Unknown' -and $tab.error -like 'Unsupported: Tab*')
  Check 'no global keyboard injection' ((Get-Content (Join-Path $root 'lib/QualityUiWorker.ps1') -Raw) -notmatch 'keybd_event|SendInput|SendKeys')
'''+s[a:]
p.write_text(s)
Path('tests/fixtures/quality/copy-artifact.ps1').write_text('''param([string]$Source,[string]$Destination,[Parameter(ValueFromRemainingArguments=$true)]$Flags)
$ErrorActionPreference='Stop'
Copy-Item -LiteralPath $Source -Destination $Destination
''')
