#requires -Version 7.0
[CmdletBinding()]param([string]$EvidenceDirectory)
$ErrorActionPreference='Stop'
$evidencePath=& (Join-Path $PSScriptRoot 'Resolve-SuiteEvidencePath.ps1') 'validation-quality-foundations.json' $EvidenceDirectory ($PSBoundParameters.ContainsKey('EvidenceDirectory'))
$root=Split-Path $PSScriptRoot
. (Join-Path $root 'lib/QualityCommon.ps1')
$fixture=Join-Path $PSScriptRoot 'fixtures/quality'
$work=Join-Path $root ('scratchwork/quality-foundations-handoff/run-'+[guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $work
$checks=[Collections.Generic.List[object]]::new()
$commands=[Collections.Generic.List[object]]::new()
$blockedGates=[Collections.Generic.List[object]]::new()
function Check([string]$Name,[bool]$Passed){$checks.Add(@{name=$Name;passed=$Passed});Write-Host "$Name : $Passed"}
function SaveJson($Value,[string]$Name){$path=Join-Path $work $Name;$Value|ConvertTo-Json -Depth 40|Set-Content -LiteralPath $path -Encoding utf8;return $path}
function Run([string]$Name,[string]$Tool,[hashtable]$Parameters,[int[]]$Expected){
 $text=& (Join-Path $root $Tool) @Parameters -Json
 $exitCode=$LASTEXITCODE
 $path=Join-Path $work ($Name+'.json');$text|Set-Content -LiteralPath $path -Encoding utf8
 $commands.Add(@{name=$Name;command=$Tool;exitCode=$exitCode;resultPath=$path})
 Check $Name ($exitCode -in $Expected)
 $text|ConvertFrom-Json -AsHashtable
}
try{
 foreach($file in @('Test-WindowsUi.ps1','Invoke-NativeMemoryTest.ps1','Test-DataMigration.ps1','lib/QualityCommon.ps1','lib/QualityUiWorker.ps1','tests/Test-QualityFoundations.ps1')){
  $tokens=$null;$errors=$null;$null=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root $file),[ref]$tokens,[ref]$errors);Check ('parse '+$file) ($errors.Count -eq 0)
 }
 $legacy=Join-Path $env:WINDIR 'System32/WindowsPowerShell/v1.0/powershell.exe'
 $legacyParse=Invoke-QProcess $legacy @('-NoProfile','-NonInteractive','-Command',('$t=$null;$e=$null;[void][Management.Automation.Language.Parser]::ParseFile('''+(Join-Path $root 'lib/QualityUiWorker.ps1')+''',[ref]$t,[ref]$e);if($e.Count){$e;exit 2}')) $work 10 65536
 Check 'PS5.1 worker parse' ($legacyParse.ExitCode -eq 0)
 Check 'numeric canonical comparison' ((ConvertTo-QCanonical 1L) -ceq (ConvertTo-QCanonical 1))
 Check 'string numeric distinction' ((ConvertTo-QCanonical '1') -cne (ConvertTo-QCanonical 1))
 Check 'large integer comparison' ((ConvertTo-QCanonical ([Numerics.BigInteger]::Parse('9223372036854775808'))) -cne (ConvertTo-QCanonical '9223372036854775808'))
 $escaped=$false;try{$null=Resolve-QChild $work '../escape'}catch{$escaped=$true};Check 'traversal refused' $escaped
 $inputs=Join-Path $work 'fixture inputs'
 $null=New-Item -ItemType Directory -Path (Join-Path $inputs 'valid'),(Join-Path $inputs 'corrupt'),(Join-Path $inputs 'wrong')
 '{"schemaVersion":1,"keep":{"unicode":"café","number":9223372036854775808,"false":false,"nil":null},"old":"value"}'|Set-Content (Join-Path $inputs 'valid/settings.json') -Encoding utf8
 '{bad'|Set-Content (Join-Path $inputs 'corrupt/settings.json')
 '{"schemaVersion":99}'|Set-Content (Join-Path $inputs 'wrong/settings.json')
 $original=Get-QTreeHash $inputs
 $pwsh=(Get-Command pwsh.exe).Source
 $migrator=Join-Path $fixture 'migrator.ps1'
 function Phase([string]$Mode){@{executable=$pwsh;arguments=@('-NoProfile','-File',$migrator,'-InputRoot','{InputRoot}','-OutputRoot','{OutputRoot}','-Mode',$Mode,'-Quoted','space and "quote"');expectedExitCodes=@(0)}}
 $outAssertions=@{jsonFiles=@(@{path='settings.json';preservePointers=@('/keep');equals=@{'/transformed'='done'}})}
 foreach($mode in @('Migrate','Corrupt','Crash','Timeout','Wrong')){
  $phase=Phase $(if($mode -eq 'Wrong'){'Migrate'}else{$mode})
  $case=@{id=$mode;source=if($mode -eq 'Corrupt'){'corrupt'}elseif($mode -eq 'Wrong'){'wrong'}else{'valid'};fromVersion=1;toVersion=2;executable=$phase.executable;arguments=$phase.arguments;expectedExitCodes=@(0);assertions=$outAssertions}
  $expected=0
  if($mode -eq 'Corrupt'){$case.expectedInputInvalid=$true;$case.expectedExitCodes=@(7);$case.assertions=@{jsonFiles=@(@{path='settings.json';equals=@{'/rejected'=$true}});files=@(@{path='rejected.txt'})}}
  if($mode -in @('Crash','Timeout')){$back=Phase 'Rollback';$back.assertions=@{jsonFiles=@(@{path='settings.json';expectedVersion=1;preservePointers=@('/keep')})};$case.rollback=$back;if($mode -eq 'Crash'){$expected=2}else{$case.timeoutSeconds=2;$expected=3}}
  if($mode -eq 'Wrong'){$expected=2}
  $plan=SaveJson @{schemaVersion=1;cases=@($case)} ('migration-'+$mode+'.plan.json')
  $result=Run ('migration-'+$mode) 'Test-DataMigration.ps1' @{FixtureRoot=$inputs;PlanPath=$plan;Destination=(Join-Path $work ('migration-'+$mode));ExecuteTrusted=$true} $expected
  if($mode -in @('Crash','Timeout')){Check ($mode+' actual rollback') ($result.cases[0].rollback.status -eq 'Pass')}
  if($mode -eq 'Wrong'){Check 'wrong version never executed' ($result.executionEvidence.Count -eq 0 -and $result.cases[0].migrationExecution -eq 'NotPerformed')}
 }
 foreach($regression in @('contradictory','rollback-contradictory','missing-json','bad-pointer','mutate-both')){
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
 Check 'original fixtures unchanged' ((Get-QTreeHash $inputs) -ceq $original)
 $null=Run 'migration-overlap-refused' 'Test-DataMigration.ps1' @{FixtureRoot=$inputs;PlanPath=$plan;Destination=(Join-Path $inputs 'overlap');ExecuteTrusted=$true} 125
 $malformed=SaveJson @{schemaVersion='1';cases=@()} 'malformed.json'
 $null=Run 'migration-malformed-refused' 'Test-DataMigration.ps1' @{FixtureRoot=$inputs;PlanPath=$malformed;Destination=(Join-Path $work 'malformed');ExecuteTrusted=$true} 125
 $link=Join-Path $work 'junction';$null=New-Item -ItemType Junction -Path $link -Target $inputs
 $reparse=$false;try{$null=Assert-QPath (Join-Path $link 'valid/settings.json')}catch{$reparse=$true};Check 'reparse refused' $reparse
 $bounded=Invoke-QProcess $pwsh @('-NoProfile','-Command','[Console]::Write("x" * 8192)') $work 10 1024
 Check 'actual process output cap' ($bounded.Truncated -and $bounded.Output.Length -eq 1024)
 $timed=Invoke-QProcess $pwsh @('-NoProfile','-Command','Start-Sleep -Seconds 15') $work 1 1024
 Check 'actual child timeout' ($timed.TimedOut -and $timed.ExitCode -eq 124)
 $clPath=(Get-Command cl.exe -CommandType Application -ErrorAction Stop).Source
 $vc=$env:VCToolsInstallDir
 if([string]::IsNullOrWhiteSpace($vc)){$vcArch=[IO.Path]::GetDirectoryName($clPath);$vcHost=[IO.Path]::GetDirectoryName($vcArch);$vcBinRoot=[IO.Path]::GetDirectoryName($vcHost);$vc=[IO.Path]::GetDirectoryName($vcBinRoot)}
 $sdk=$env:WindowsSdkDir
 if([string]::IsNullOrWhiteSpace($sdk)){$sdk=Join-Path ([Environment]::GetFolderPath('ProgramFilesX86')) 'Windows Kits\10'}
 $sdkVersion=$env:WindowsSDKVersion
 if([string]::IsNullOrWhiteSpace($sdkVersion)){$sdkVersion=(Get-ChildItem -LiteralPath (Join-Path $sdk 'Include') -Directory -ErrorAction Stop|Where-Object{$_.Name -match '^\d+\.\d+\.\d+\.\d+$'}|Sort-Object {[version]$_.Name} -Descending|Select-Object -First 1).Name}
 $sdkVersion=$sdkVersion.TrimEnd([char]92)
 $sdkInclude=Join-Path (Join-Path $sdk 'Include') $sdkVersion;$sdkLib=Join-Path (Join-Path $sdk 'Lib') $sdkVersion;$vcInclude=Join-Path $vc 'include';$vcLib=Join-Path (Join-Path $vc 'lib') 'x64';$compilerBin=[IO.Path]::GetDirectoryName($clPath)
 if(-not (Test-Path -LiteralPath $vcInclude -PathType Container) -or -not (Test-Path -LiteralPath $sdkInclude -PathType Container) -or -not (Test-Path -LiteralPath $sdkLib -PathType Container)) { throw 'Configured MSVC and Windows SDK paths are unavailable.' }
 foreach($mode in @('safe','overflow')){
  $compile=@('/nologo','/fsanitize=address','/Zi','/Od','/MD',('/I'+$vcInclude))
  foreach($inc in @('ucrt','shared','um')){$compile+=('/I'+(Join-Path $sdkInclude $inc))}
  if($mode -eq 'overflow'){$compile+='/DOVERFLOW'}
  $compile+=@('{ProjectRoot}/memory.c','/Fe{WorkRoot}/fixture.exe','/Fo{WorkRoot}/fixture.obj','/Fd{WorkRoot}/fixture.pdb','/link','/INCREMENTAL:NO',('/LIBPATH:'+$vcLib),('/LIBPATH:'+(Join-Path (Join-Path $sdkLib 'ucrt') 'x64')),('/LIBPATH:'+(Join-Path (Join-Path $sdkLib 'um') 'x64')))
  $runtimePath=Join-Path $compilerBin 'clang_rt.asan_dynamic-x86_64.dll'
  $manifest=SaveJson @{schemaVersion=1;compilerPath=$clPath;compileArguments=$compile;executablePath='fixture.exe';runArguments=@();instrumentation='AddressSanitizer';timeoutSeconds=30;maxOutputBytes=1048576;runtimeFiles=@($runtimePath)} ('asan-'+$mode+'.plan.json')
  $result=Run ('asan-'+$mode) 'Invoke-NativeMemoryTest.ps1' @{ProjectPath=$fixture;BuildManifestPath=$manifest;Destination=(Join-Path $work ('asan-'+$mode));ExecuteTrusted=$true} $(if($mode -eq 'safe'){0}else{2})
  Check ($mode+' actual ASan runtime') ($result.executionEvidence.Count -eq 2 -and $result.findings[0].status -eq 'Pass')
  if($mode -eq 'overflow'){Check 'actual heap overflow diagnostic' ($result.executionEvidence.Count -eq 2 -and $result.executionEvidence[1].sanitizerDiagnostic)}
 }
 $safeExe=Join-Path $work 'asan-safe/fixture.exe'
 if(Test-Path -LiteralPath $safeExe -PathType Leaf){
  foreach($kind in @('fake-runtime','missing-symbols','missing-flag')){
   $bytes=[IO.File]::ReadAllBytes($safeExe)
   $binary=[Text.Encoding]::Latin1.GetString($bytes)
   if($kind -ceq 'fake-runtime'){$binary=$binary.Replace('clang_rt.asan_dynamic-x86_64.dll',('fake_asan.dll'+([string][char]0)*19))}
   if($kind -ceq 'missing-symbols'){$binary=$binary.Replace('__asan_','__fake_')}
   $artifact=Join-Path $work ($kind+'.exe');[IO.File]::WriteAllBytes($artifact,[Text.Encoding]::Latin1.GetBytes($binary))
   $copyArgs=@('-NoProfile','-File',(Join-Path $fixture 'copy-artifact.ps1'),'-Source',$artifact,'-Destination','{WorkRoot}/fixture.exe')
   if($kind -cne 'missing-flag'){$copyArgs+=@('/fsanitize=address')}
   $regPlan=SaveJson @{schemaVersion=1;compilerPath=$pwsh;compileArguments=$copyArgs;executablePath='fixture.exe';runArguments=@();instrumentation='AddressSanitizer'} ($kind+'.plan.json')
   $reg=Run ('asan-'+$kind) 'Invoke-NativeMemoryTest.ps1' @{ProjectPath=$fixture;BuildManifestPath=$regPlan;Destination=(Join-Path $work ('asan-'+$kind));ExecuteTrusted=$true} 3
   Check ($kind+' never executed') ($reg.executionEvidence.Count -eq 1 -and $reg.status -ceq 'Unknown')
  }
 }else{
  $blockedGates.Add(@{gate='ASan mutation fixtures';status='Unknown';reason='Safe ASan fixture was not built; mutation checks were not run.'})
  Write-Host 'ASan mutation checks: Unknown (safe fixture unavailable)'
 }
 $noInstrument=SaveJson @{schemaVersion=1;instrumentation='None'} 'asan-no-instrument.plan.json'
 $null=Run 'asan-no-instrument-refused' 'Invoke-NativeMemoryTest.ps1' @{ProjectPath=$fixture;BuildManifestPath=$noInstrument;Destination=(Join-Path $work 'no-instrument');ExecuteTrusted=$true} 125
 $compilerError=Read-QJson $manifest;$compilerError.compileArguments=@('/nologo','{ProjectRoot}/does-not-exist.c')
 $errorPlan=SaveJson $compilerError 'asan-compiler-error.plan.json'
 $null=Run 'asan-actual-compiler-error' 'Invoke-NativeMemoryTest.ps1' @{ProjectPath=$fixture;BuildManifestPath=$errorPlan;Destination=(Join-Path $work 'compiler-error');ExecuteTrusted=$true} 2
 $null=Run 'asan-overlap-refused' 'Invoke-NativeMemoryTest.ps1' @{ProjectPath=$fixture;BuildManifestPath=$manifest;Destination=(Join-Path $fixture 'overlap');ExecuteTrusted=$true} 125
 $assertions=@{schemaVersion=1;context=@{dpi=96;theme='fixture';locale='en-US'};checks=@(@{id='apply';selector=@{automationId='FixtureApply'};name='Apply';enabled=$true;keyboardFocusable=$true;patterns=@('Invoke')});workflow=@()}
 $assertionPath=SaveJson $assertions 'ui.plan.json'
 $uiExe=Join-Path $work 'QualityFixture.exe'
 $uiBuild=Invoke-QProcess $legacy @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $fixture 'build-ui.ps1'),'-Source',(Join-Path $fixture 'ui.cs'),'-Destination',$uiExe) $work 20 65536
 [IO.File]::WriteAllText((Join-Path $work 'ui-build.stderr.log'),$uiBuild.Error)
 Check 'actual Framework UI fixture compile' ($uiBuild.ExitCode -eq 0 -and (Test-Path $uiExe))
 '<configuration><startup><supportedRuntime version="v4.0" sku=".NETFramework,Version=v4.8"/></startup></configuration>'|Set-Content ($uiExe+'.config')
 $ui=[Diagnostics.Process]::new();$ui.StartInfo=[Diagnostics.ProcessStartInfo]::new($legacy);$ui.StartInfo.UseShellExecute=$false;$ui.StartInfo.CreateNoWindow=$true
 foreach($argument in @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-STA','-File',(Join-Path $fixture 'ui-wpf.ps1'))){$ui.StartInfo.ArgumentList.Add($argument)}
 $null=$ui.Start()
 try{
  $deadline=[DateTime]::UtcNow.AddSeconds(15);do{Start-Sleep -Milliseconds 200;$ui.Refresh()}while(-not $ui.HasExited -and $ui.MainWindowHandle -eq 0 -and [DateTime]::UtcNow -lt $deadline)
  $rootAssertions=@{schemaVersion=1;checks=@(@{id='root';selector=@{name='Quality fixture';controlType='Window'};enabled=$true;patterns=@('Window')})}
  $rootPath=SaveJson $rootAssertions 'ui.root.plan.json'
  $result=Run 'ui-live-read-root' 'Test-WindowsUi.ps1' @{ProcessId=$ui.Id;AssertionsPath=$rootPath;Destination=(Join-Path $work 'ui-live')} 0
  $providerAvailable=@($result.snapshot.nodes|Where-Object {$_.automationId -ceq 'FixtureApply' -and 'Invoke' -cin $_.patterns}).Count -eq 1
  if($providerAvailable){
  $null=Run 'ui-live-control-patterns' 'Test-WindowsUi.ps1' @{ProcessId=$ui.Id;AssertionsPath=$assertionPath} 0
  $assertions.checks[0].name='wrong';$bad=SaveJson $assertions 'ui.bad.plan.json'
  $null=Run 'ui-live-bad' 'Test-WindowsUi.ps1' @{ProcessId=$ui.Id;AssertionsPath=$bad} 2
  $assertions.checks=@(@{id='ambiguous';selector=@{name='Apply'}});$ambiguous=SaveJson $assertions 'ui.ambiguous.plan.json'
  $null=Run 'ui-live-ambiguous' 'Test-WindowsUi.ps1' @{ProcessId=$ui.Id;AssertionsPath=$ambiguous} 2
  }else{
   $blockedGates.Add(@{gate='LiveOwnedControlPatternsAndActions';status='Unknown';exitCode=3;reason='Owned WPF fixture did not expose stable AutomationId and Invoke patterns in this desktop context.';unperformed=@('control pattern positive/negative assertions','SetFocus/SetValue/Invoke and fresh post-action tree assertions','per-step stale-name regression')})
   Write-Host 'Live owned control/action gate: Unknown (3), provider patterns unavailable'
  }
  $null=Run 'ui-tree-cap' 'Test-WindowsUi.ps1' @{ProcessId=$ui.Id;AssertionsPath=$assertionPath;MaxNodes=1} 3
  $assertions.checks=@(@{id='changed';selector=@{automationId='FixtureApply'};name='Applied'},@{id='added';selector=@{automationId='FixtureAdded'};name='Added'})
  $assertions.workflow=@(@{action='SetFocus';selector=@{automationId='FixtureInput'}},@{action='SetValue';selector=@{automationId='FixtureInput'};value='café'},@{action='Invoke';selector=@{automationId='FixtureApply'}})
  $actionPath=SaveJson $assertions 'ui.actions.plan.json'
  $null=Run 'ui-actions-denied' 'Test-WindowsUi.ps1' @{ProcessId=$ui.Id;AssertionsPath=$actionPath} 3
  if($providerAvailable){$null=Run 'ui-actions-refreshed' 'Test-WindowsUi.ps1' @{ProcessId=$ui.Id;AssertionsPath=$actionPath;AllowActions=$true} 0}
  if($providerAvailable){
   $stalePath=SaveJson @{schemaVersion=1;checks=$rootAssertions.checks;workflow=@(@{action='Invoke';selector=@{automationId='FixtureRename'}},@{action='Invoke';selector=@{name='RenameTarget';controlType='Button'}})} 'ui.stale.plan.json'
   $staleRun=Invoke-QProcess $legacy @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',(Join-Path $root 'lib/QualityUiWorker.ps1'),'-ProcessId',[string]$ui.Id,'-ExpectedStartUtc',$ui.StartTime.ToUniversalTime().ToString('o'),'-AssertionsPath',$stalePath,'-AllowActions') $work 20 2097152
   $staleText=[Text.Encoding]::UTF8.GetString($staleRun.Output);$staleResultPath=Join-Path $work 'ui-stale-name-refused.json';$staleText|Set-Content $staleResultPath
   $commands.Add(@{name='ui-stale-name-refused';command='lib/QualityUiWorker.ps1';exitCode=$staleRun.ExitCode;resultPath=$staleResultPath})
   $stale=$staleText|ConvertFrom-Json -AsHashtable
   Check 'ui-stale-name-refused' ($staleRun.ExitCode -eq 3)
   Check 'stale selector stops after first action' ($stale.workflow.Count -eq 1 -and $stale.error -like '*Selector is missing or ambiguous*')
   $clickPath=SaveJson @{schemaVersion=1;checks=@(@{id='once';selector=@{automationId='FixtureClicks'};name='Clicks: 1'},@{id='renamed';selector=@{automationId='FixtureRename'};name='RenamedTarget'})} 'ui.clicks.plan.json'
   $null=Run 'ui-renamed-invoked-once' 'Test-WindowsUi.ps1' @{ProcessId=$ui.Id;AssertionsPath=$clickPath} 0
  }
  $tabPlan=SaveJson @{schemaVersion=1;checks=$rootAssertions.checks;workflow=@(@{action='Invoke';selector=@{name='Quality fixture';controlType='Window'}},@{action='Tab'})} 'ui.tab.plan.json'
  $tab=Run 'ui-tab-unsupported' 'Test-WindowsUi.ps1' @{ProcessId=$ui.Id;AssertionsPath=$tabPlan;AllowActions=$true} 3
  Check 'Tab rejected before preceding workflow input' ($tab.status -ceq 'Unknown' -and $tab.error -like 'Unsupported: Tab*')
  Check 'no global keyboard injection' ((Get-Content (Join-Path $root 'lib/QualityUiWorker.ps1') -Raw) -notmatch 'keybd_event|SendInput|SendKeys')
  $budget=Run 'ui-worker-budget' 'Test-WindowsUi.ps1' @{ProcessId=$ui.Id;AssertionsPath=$rootPath;TimeoutSeconds=1} @(0,3)
  Check 'UI worker returns bounded result' ($budget.status -in @('Pass','Unknown'))
  $exitedId=$ui.Id;$ui.Kill();$ui.WaitForExit()
  $null=Run 'ui-target-exited' 'Test-WindowsUi.ps1' @{ProcessId=$exitedId;AssertionsPath=$rootPath} 125
 }finally{if(-not $ui.HasExited){$ui.Kill();$ui.WaitForExit()};$ui.Dispose()}
}catch{Check ('unexpected line '+$_.InvocationInfo.ScriptLineNumber+': '+$_.Exception.Message) $false;$_|Out-String|Set-Content (Join-Path $work 'failure.log')}
$failed=@($checks|Where-Object {-not $_.passed}).Count
$code=if($failed){2}elseif($blockedGates.Count){3}else{0}
@{schemaVersion=1;command='pwsh -NoProfile -File tests/Test-QualityFoundations.ps1';exitCode=$code;observedUtc=[DateTime]::UtcNow.ToString('o');fixturePath=$fixture;artifactRoot=$work;blockedGates=$blockedGates.ToArray();checks=$checks.ToArray();commands=$commands.ToArray();passed=$checks.Count-$failed;failed=$failed;limits=@{childOutputBytes=2097152;fixtureEntries=10000;fixtureBytes=134217728};limitations=@('Positive UIA coverage uses the owned WPF fixture. WinForms bridge qualification remains Unknown: observed Pane children without stable IDs or Value/Invoke patterns.','No foreign applications, device, installer, release or external-service actions performed.')}|ConvertTo-Json -Depth 40|Set-Content -LiteralPath $evidencePath -Encoding utf8
Write-Host "Evidence: $work; checks=$($checks.Count); failures=$failed"
exit $code


