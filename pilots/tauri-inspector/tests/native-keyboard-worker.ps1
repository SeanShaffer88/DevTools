#requires -Version 5.1
param(
 [Parameter(Mandatory)][int]$ProcessId,
 [Parameter(Mandatory)][long]$WindowHandle,
 [Parameter(Mandatory)][string]$StartUtc,
 [Parameter(Mandatory)][string]$ImagePath,
 [ValidateSet("Startup","Inspection","Cancellation")][string]$Scenario="Startup",
 [string]$FixtureProject,
 [string]$FixtureLog
)
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
$OutputEncoding=[Console]::OutputEncoding
$result=[ordered]@{status='Unknown';error=$null;processId=$ProcessId;windowHandle=$WindowHandle;checks=@();tabSteps=@();focus=$null;foreground=$null}
$exitCode=3
$process=$null
try {
 Add-Type -AssemblyName UIAutomationClient,UIAutomationTypes
 Add-Type -Path (Join-Path $PSScriptRoot 'PilotKeyboard.cs')
 $expectedImage=(Get-Item -LiteralPath (Join-Path $PSScriptRoot '../target/debug/devtools-inspector.exe')).FullName
 if($ImagePath -ine $expectedImage){throw 'The requested executable is not this pilot build.'}
 $process=Get-Process -Id $ProcessId
 $window=[IntPtr]$WindowHandle
 $sessionId=[Diagnostics.Process]::GetCurrentProcess().SessionId
 $expectedStart=[DateTime]::Parse($StartUtc,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::RoundtripKind)
 function Assert-OwnedIdentity {
  $process.Refresh()
  if($process.HasExited -or $process.SessionId -ne $sessionId -or $process.StartTime.ToUniversalTime() -ne $expectedStart -or
     $process.Path -ine $ImagePath -or
     $window -eq [IntPtr]::Zero -or [PilotKeyboard]::WindowProcess($window) -ne $ProcessId){
   throw 'The owned window identity changed.'
  }
 }
 function Assert-OwnedWindow {
  Assert-OwnedIdentity
  if($process.MainWindowHandle -ne $window){throw 'The main window identity changed.'}
 }
 Assert-OwnedWindow

 $root=[Windows.Automation.AutomationElement]::FromHandle($window)
 $walker=[Windows.Automation.TreeWalker]::RawViewWalker
 $assertions=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'native-assertions.json') -Raw | ConvertFrom-Json
 function Find-Buttons {
  $matches=@{}
  foreach($check in $assertions.checks){$matches[$check.selector.automationId]=[Collections.Generic.List[object]]::new()}
  $pending=[Collections.Generic.Queue[object]]::new()
  $pending.Enqueue($root)
  $visited=0
  while($pending.Count -gt 0){
   $visited++
   $node=$pending.Dequeue()
   $current=$node.Current
   if($current.AutomationId -and $matches.ContainsKey($current.AutomationId)){
    $matches[$current.AutomationId].Add($current)
   }
   $child=$walker.GetFirstChild($node)
   while($null -ne $child){
    if($visited+$pending.Count -ge 512){throw 'Owned RawView exceeds the 512-element budget.'}
    $pending.Enqueue($child)
    $child=$walker.GetNextSibling($child)
   }
  }
  return $matches
 }
 function Read-TargetFocus {
  $element=[Windows.Automation.AutomationElement]::FocusedElement
  $ancestor=$element
  for($depth=0;$null -ne $ancestor -and $depth -lt 40;$depth++){
   if([Windows.Automation.Automation]::Compare($ancestor,$root)){
    $state=$element.Current
    return [ordered]@{automationId=$state.AutomationId;name=$state.Name;type=$state.ControlType.ProgrammaticName;enabled=$state.IsEnabled;focusable=$state.IsKeyboardFocusable;hasFocus=$state.HasKeyboardFocus}
   }
   $ancestor=$walker.GetParent($ancestor)
  }
  return $null
 }
 $clock=[Diagnostics.Stopwatch]::StartNew()
 do {
  Assert-OwnedWindow
  $matches=Find-Buttons
  $missing=@($assertions.checks | Where-Object {$matches[$_.selector.automationId].Count -eq 0})
  if($missing.Count -eq 0){break}
  Start-Sleep -Milliseconds 200
 }while($clock.Elapsed.TotalSeconds -lt 6)
 foreach($check in $assertions.checks){
  $items=$matches[$check.selector.automationId]
  $observation=[ordered]@{id=$check.id;matches=$items.Count;match=$false}
  if($items.Count -eq 1){
   $item=$items[0]
   $observation.name=$item.Name
   $observation.type=$item.ControlType.ProgrammaticName
   $observation.enabled=$item.IsEnabled
   $observation.focusable=$item.IsKeyboardFocusable
   $observation.providerPid=$item.ProcessId
   $observation.match=$item.AutomationId -ceq $check.selector.automationId -and $item.Name -ceq $check.selector.name -and
    $item.ControlType -eq [Windows.Automation.ControlType]::Button -and $item.IsEnabled -eq $check.enabled -and
    ($null -eq $check.keyboardFocusable -or $item.IsKeyboardFocusable -eq $check.keyboardFocusable)
  }
  $result.checks+=,$observation
 }
 if($missing.Count -gt 0){throw 'The owned RawView did not expose every expected control.'}
 if(@($result.checks | Where-Object {-not $_.match}).Count -gt 0){
  $exitCode=2
  $result.status='Fail'
  throw 'An expected control is ambiguous or has the wrong name, type, or state.'
 }
 Assert-OwnedWindow
 $initialWindow=[PilotKeyboard]::GetForegroundWindow().ToInt64()
 $result.foreground=[ordered]@{
  sessionId=$sessionId;initialHandle=$initialWindow;finalHandle=$initialWindow;attempts=0;acceptedRequests=0;completedBarriers=0;captionFallback='NotNeeded';status='AlreadyOwned'
 }
 if($initialWindow -ne $WindowHandle){
  $result.foreground.status='Acquiring'
  $activationClock=[Diagnostics.Stopwatch]::StartNew()
  $activated=$false
  while($activationClock.ElapsedMilliseconds -lt 2000){
   Assert-OwnedWindow
   $result.foreground.attempts++
   if([PilotKeyboard]::RequestForeground($window,$ProcessId)){$result.foreground.acceptedRequests++}
   $remaining=2000-$activationClock.ElapsedMilliseconds
   if($remaining -le 0){break}
   # A bounded WM_NULL round trip lets the owned GUI thread process activation.
   $synchronized=[PilotKeyboard]::WaitForActivationMessage($window,$ProcessId,[Math]::Min(100,$remaining))
   if($synchronized){$result.foreground.completedBarriers++}
   $result.foreground.finalHandle=[PilotKeyboard]::GetForegroundWindow().ToInt64()
   if($synchronized -and $result.foreground.finalHandle -eq $WindowHandle){$activated=$true;break}
   $remaining=2000-$activationClock.ElapsedMilliseconds
   if($remaining -gt 0){Start-Sleep -Milliseconds ([Math]::Min(100,$remaining))}
  }
  Assert-OwnedWindow
  $result.foreground.finalHandle=[PilotKeyboard]::GetForegroundWindow().ToInt64()
  if(-not $activated -or $result.foreground.finalHandle -ne $WindowHandle){
   $result.foreground.captionFallback=[PilotKeyboard]::ClickOwnedCaption($window,$ProcessId)
   $result.foreground.captionDiagnostics=[PilotKeyboard]::CaptionDiagnostics
   if($result.foreground.captionFallback -in @('Sent','AlreadyForeground')){
    $clickClock=[Diagnostics.Stopwatch]::StartNew()
    do{
     Assert-OwnedWindow
     $result.foreground.finalHandle=[PilotKeyboard]::GetForegroundWindow().ToInt64()
     if($result.foreground.finalHandle -eq $WindowHandle){break}
     Start-Sleep -Milliseconds 50
    }while($clickClock.ElapsedMilliseconds -lt 1000)
   }
   if($result.foreground.captionFallback -notin @('Sent','AlreadyForeground') -or $result.foreground.finalHandle -ne $WindowHandle){
    $result.foreground.status='Denied'
    throw 'Windows did not foreground the owned window after the guarded caption fallback. No Tab was sent.'
   }
   $result.foreground.status=if($result.foreground.captionFallback -eq 'Sent'){'AcquiredByCaption'}else{'Acquired'}
  }else{
   $result.foreground.status='Acquired'
  }
 }
 $previous=Read-TargetFocus
 $result.initialFocus=$previous
 if($null -eq $previous){throw 'Initial keyboard focus could not be located under the owned window.'}
 for($step=1;$step -le 8;$step++){
  Assert-OwnedWindow
  $result.foreground.finalHandle=[PilotKeyboard]::GetForegroundWindow().ToInt64()
  if($result.foreground.finalHandle -ne $WindowHandle){
   $result.foreground.status='Lost'
   throw 'The owned window lost the foreground before Tab.'
  }
  if(-not [PilotKeyboard]::SendTab($window,$ProcessId)){throw 'Could not safely send Tab to the owned window.'}
  Start-Sleep -Milliseconds 200
  Assert-OwnedWindow
  $result.foreground.finalHandle=[PilotKeyboard]::GetForegroundWindow().ToInt64()
  if($result.foreground.finalHandle -ne $WindowHandle){
   $result.foreground.status='Lost'
   throw 'The foreground changed after Tab.'
  }
  $focus=Read-TargetFocus
  if($null -eq $focus){throw 'Keyboard focus left the owned window or could not be observed.'}
  $result.tabSteps+=,$focus
  if($focus.automationId -ceq 'select' -and $focus.name -ceq 'Select folder' -and $focus.type -ceq 'ControlType.Button' -and
     $focus.enabled -and $focus.focusable -and $focus.hasFocus -and $previous.automationId -cne 'select'){
   $result.focus=$focus
   $result.status='Pass'
   $exitCode=0
   break
  }
  $previous=$focus
 }
 if($exitCode -ne 0){
  $exitCode=2
  $result.status='Fail'
  throw 'Tab did not move keyboard focus to Select folder within eight attempts.'
 }
 if($Scenario -ne 'Startup'){
  $exitCode=3
  $result.status='Unknown'
  . (Join-Path $PSScriptRoot 'native-picker-workflow.ps1')
  Invoke-NativeSmokeWorkflow
  $result.status='Pass'
  $exitCode=0
 }
}catch{
 $result.error=$_.Exception.Message
}finally{
 if($process){$process.Dispose()}
}
$result | ConvertTo-Json -Depth 8
exit $exitCode
