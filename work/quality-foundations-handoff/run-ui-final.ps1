#requires -Version 7.0
[CmdletBinding()]param()
$ErrorActionPreference='Stop'
$root='C:\Users\Sean Shaffer\Documents\DevTools'
. (Join-Path $root 'lib/QualityCommon.ps1')
$fixture=Join-Path $root 'tests/fixtures/quality'
$work=Join-Path $root ('scratchwork/quality-foundations-handoff/run-'+[guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $work
$checks=[Collections.Generic.List[object]]::new()
$commands=[Collections.Generic.List[object]]::new()
$blockedGates=[Collections.Generic.List[object]]::new()
function Check([string]$Name,[bool]$Passed){$checks.Add(@{name=$Name;passed=$Passed});Write-Host "$Name : $Passed"}
function SaveJson($Value,[string]$Name){$path=Join-Path $work $Name;$Value|ConvertTo-Json -Depth 40|Set-Content -LiteralPath $path -Encoding utf8;return $path}
function Run([string]$Name,[string]$Tool,[hashtable]$Parameters,[int]$Expected){
 $text=& (Join-Path $root $Tool) @Parameters -Json
 $exitCode=$LASTEXITCODE
 $path=Join-Path $work ($Name+'.json');$text|Set-Content -LiteralPath $path -Encoding utf8
 $commands.Add(@{name=$Name;command=$Tool;exitCode=$exitCode;resultPath=$path})
 Check $Name ($exitCode -eq $Expected)
 $text|ConvertFrom-Json -AsHashtable
}
try{
 $legacy=Join-Path $env:WINDIR 'System32/WindowsPowerShell/v1.0/powershell.exe'
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
   $staleRun=Invoke-QProcess $legacy @('-NoProfile','-NonInteractive','-File',(Join-Path $root 'lib/QualityUiWorker.ps1'),'-ProcessId',[string]$ui.Id,'-ExpectedStartUtc',$ui.StartTime.ToUniversalTime().ToString('o'),'-AssertionsPath',$stalePath,'-AllowActions') $work 20 2097152
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
  $budget=Run 'ui-worker-budget' 'Test-WindowsUi.ps1' @{ProcessId=$ui.Id;AssertionsPath=$rootPath;TimeoutSeconds=1} 3
  Check 'actual UI worker timeout' ($budget.executionEvidence[0].timedOut)
  $exitedId=$ui.Id;$ui.Kill();$ui.WaitForExit()
  $null=Run 'ui-target-exited' 'Test-WindowsUi.ps1' @{ProcessId=$exitedId;AssertionsPath=$rootPath} 125
 }finally{if(-not $ui.HasExited){$ui.Kill();$ui.WaitForExit()};$ui.Dispose()}
}catch{Check ('unexpected: '+$_.Exception.Message) $false;$_|Out-String|Set-Content (Join-Path $work 'failure.log')}
$failed=@($checks|Where-Object {-not $_.passed}).Count
$code=if($failed){2}elseif($blockedGates.Count){3}else{0}
@{schemaVersion=1;command='pwsh -NoProfile -File work/quality-foundations-handoff/run-ui-final.ps1';exitCode=$code;observedUtc=[DateTime]::UtcNow.ToString('o');fixturePath=$fixture;artifactRoot=$work;blockedGates=$blockedGates.ToArray();checks=$checks.ToArray();commands=$commands.ToArray();passed=$checks.Count-$failed;failed=$failed;limits=@{childOutputBytes=2097152;fixtureEntries=10000;fixtureBytes=134217728};limitations=@('Positive UIA coverage uses the owned WPF fixture. WinForms bridge qualification remains Unknown: observed Pane children without stable IDs or Value/Invoke patterns.','No foreign applications, device, installer, release or external-service actions performed.')}|ConvertTo-Json -Depth 40|Set-Content -LiteralPath (Join-Path $root 'work/quality-foundations-handoff/validation-ui-final.json') -Encoding utf8
Write-Host "Evidence: $work; checks=$($checks.Count); failures=$failed"
exit $code



