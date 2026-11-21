function Wait-SmokeObservation([scriptblock]$Observe,[string]$Failure,[int]$Milliseconds=4000){
 $waitClock=[Diagnostics.Stopwatch]::StartNew()
 do{
  $observed=& $Observe
  if($observed){return $observed}
  Start-Sleep -Milliseconds 80
 }while($waitClock.ElapsedMilliseconds -lt $Milliseconds)
 throw $Failure
}

function Get-SmokeElement($Scope,[string]$AutomationId){
 $condition=[Windows.Automation.PropertyCondition]::new(
  [Windows.Automation.AutomationElement]::AutomationIdProperty,$AutomationId)
 $matches=$Scope.FindAll([Windows.Automation.TreeScope]::Descendants,$condition)
 if($matches.Count -eq 1){return $matches[0]}
 if($matches.Count -gt 1){throw "Automation ID $AutomationId is ambiguous in its owned scope."}
}

function Get-SmokeValue($Element){
 if($null -eq $Element){return}
 $pattern=$null
 if($Element.TryGetCurrentPattern([Windows.Automation.ValuePattern]::Pattern,[ref]$pattern)){
  return $pattern.Current.Value
 }
}

function Assert-SmokeForeground([IntPtr]$Expected){
 Assert-OwnedIdentity
 if([PilotKeyboard]::GetForegroundWindow() -ne $Expected){throw 'The expected owned window is not in the foreground.'}
}

function Invoke-SmokeButton([string]$Id){
 Assert-SmokeForeground $window
 $button=Get-SmokeElement $root $Id
 if($null -eq $button -or $button.Current.ControlType -ne [Windows.Automation.ControlType]::Button -or
    -not $button.Current.IsEnabled -or -not $button.Current.IsKeyboardFocusable){
  throw "Owned button $Id is unavailable."
 }
 $button.SetFocus()
 $null=Wait-SmokeObservation {
  Assert-SmokeForeground $window
  $focus=Read-TargetFocus
  $focus -and $focus.hasFocus -and $focus.automationId -ceq $Id
 } "Owned button $Id did not get focus." 1200
 if($Id -in @('inspect','cancel')){
  Assert-SmokeForeground $window
  $action=$null
  if(-not $button.TryGetCurrentPattern([Windows.Automation.InvokePattern]::Pattern,[ref]$action)){
   throw "Owned button $Id has no InvokePattern."
  }
  $action.Invoke()
 }elseif(-not [PilotKeyboard]::SendWorkflowKey($window,$ProcessId,0x0d)){
  throw "Could not send Enter to owned button $Id."
 }
}

function Invoke-SmokePicker([string]$Path,[switch]$Dismiss){
 Assert-SmokeForeground $window
 if([PilotKeyboard]::FindVisibleOwnedFolderDialog($window,$ProcessId) -ne [IntPtr]::Zero){
  throw 'An owned folder dialog was already open.'
 }
 Invoke-SmokeButton 'select'
 $handle=Wait-SmokeObservation {
  Assert-OwnedIdentity
  $visible=[PilotKeyboard]::FindVisibleOwnedFolderDialog($window,$ProcessId)
  if($visible -ne [IntPtr]::Zero){return $visible}
 } 'The owned Select project folder dialog did not appear.' 5500
 $result.workflow.observedDialogHandle=$handle.ToInt64()
 if([PilotKeyboard]::GetForegroundWindow() -ne $handle){
  $null=[PilotKeyboard]::RequestForeground($handle,$ProcessId)
  $null=[PilotKeyboard]::WaitForActivationMessage($handle,$ProcessId,100)
 }
 $null=Wait-SmokeObservation {
  Assert-OwnedIdentity
  [PilotKeyboard]::FindVisibleOwnedFolderDialog($window,$ProcessId) -eq $handle -and
  [PilotKeyboard]::GetForegroundWindow() -eq $handle
 } 'The authenticated folder dialog was visible but not foreground.' 1200
 $dialog=[pscustomobject]@{handle=$handle;element=[Windows.Automation.AutomationElement]::FromHandle($handle)}
 if($Dismiss){
  Assert-SmokeForeground $dialog.handle
  if(-not [PilotKeyboard]::IsOwnedFolderDialog($dialog.handle,$window,$ProcessId) -or
     -not [PilotKeyboard]::SendWorkflowKey($dialog.handle,$ProcessId,0x1b)){
   throw 'Could not send Escape to the owned folder dialog.'
  }
 }else{
  Assert-SmokeForeground $dialog.handle
  $confirm=[PilotKeyboard]::ConfirmOwnedFolder($dialog.handle,$window,$ProcessId,$Path)
  $result.workflow.nativeConfirmation=$confirm
  if($confirm -ne 'ConfirmationSent'){throw "Native folder confirmation failed: $confirm."}
 }
 $returned=Wait-SmokeObservation {
  Assert-OwnedIdentity
  if([PilotKeyboard]::GetForegroundWindow() -ne $window -or
     [PilotKeyboard]::FindVisibleOwnedFolderDialog($window,$ProcessId) -ne [IntPtr]::Zero){return}
  $focus=Read-TargetFocus
  if($focus -and $focus.hasFocus -and $focus.automationId -ceq 'select'){return $focus}
 } 'Focus did not return to Select folder after the owned dialog closed.'
 if((Get-SmokeValue (Get-SmokeElement $root 'path')) -ine $Path){throw 'The project path did not match the fixture after the picker returned.'}
 return [ordered]@{dialogHandle=$dialog.handle.ToInt64();path=$Path;focusedId=$returned.automationId;gesture=if($Dismiss){'Escape'}else{'NativeButton'}}
}

function Get-SmokeTextNames($Scope){
 if($null -eq $Scope){return}
 $condition=[Windows.Automation.PropertyCondition]::new(
  [Windows.Automation.AutomationElement]::ControlTypeProperty,[Windows.Automation.ControlType]::Text)
 $text=$Scope.FindAll([Windows.Automation.TreeScope]::Descendants,$condition)
 if($text.Count -gt 512){throw 'Rendered evidence exceeded its 512-text-node budget.'}
 foreach($node in $text){
  $name=$node.Current.Name
  if($name){$name}
 }
}

function Find-SmokeMeta([string]$Prefix){
 $raw=Get-SmokeElement $root 'raw'
 $scope=if($raw){$raw}else{$root}
 $names=@(Get-SmokeTextNames $scope)
 $meta=@($names | Where-Object {$_ -cmatch $Prefix})
 if($meta.Count -eq 1){return $meta[0]}
 $result.workflow.observedMeta=@($names | Where-Object {
  $_ -match '^(completed|cancelled|timed_out|output_limit|error|Host error|Running|Inspection)'
 } | Select-Object -First 12)
}

function Assert-SmokeGitEvidence{
 $display=Get-SmokeElement $root 'results'
 if($null -eq $display){
  $region=[Windows.Automation.PropertyCondition]::new(
   [Windows.Automation.AutomationElement]::NameProperty,'Project Evidence')
  $display=$root.FindFirst([Windows.Automation.TreeScope]::Descendants,$region)
 }
 if($null -eq $display){$display=$root}
 $seen=@(Get-SmokeTextNames $display)
 $names=@('Git branch','smoke','Git work tree available' | Where-Object {$seen -ccontains $_})
 $result.workflow.observedGit=$names
 $meta=Find-SmokeMeta '^completed\s*\u00B7\s*Exit 0(?:\s*\u00B7|$)'
 if($names.Count -eq 3 -and $meta){
  return [ordered]@{branch='smoke';gitProbe='Available';renderedNames=$names;meta=$meta}
 }
}

function Invoke-NativeSmokeWorkflow{
 $result.workflow=[ordered]@{scenario=$Scenario;confirmation=$null;inspection=$null;dismissal=$null;cancellation=$null}
 $result.workflow.confirmation=Invoke-SmokePicker -Path $FixtureProject
 Invoke-SmokeButton 'inspect'
 if($Scenario -eq 'Inspection'){
  $result.workflow.inspection=Wait-SmokeObservation {Assert-SmokeGitEvidence} 'The exact Git branch and available probe were not rendered.' 6000
  $result.workflow.dismissal=Invoke-SmokePicker -Path $FixtureProject -Dismiss
  $preserved=Wait-SmokeObservation {Assert-SmokeGitEvidence} 'Escape dismissed the picker but Git evidence changed.'
  if($preserved.meta -cne $result.workflow.inspection.meta){
   throw 'Escape dismissal replaced the existing inspection evidence.'
  }
  $result.workflow.dismissal.evidencePreserved=$true
  return
 }

 . (Join-Path $PSScriptRoot 'native-cancel-fixture.ps1')
 $config=Get-Content -LiteralPath (Join-Path $PSScriptRoot '../host-config.json') -Raw | ConvertFrom-Json
 try{
  $result.workflow.inspectionStarted=Wait-SmokeObservation {
   Assert-OwnedIdentity
   $inspect=Get-SmokeElement $root 'inspect'
   $cancel=Get-SmokeElement $root 'cancel'
   $inspect -and $cancel -and -not $inspect.Current.IsEnabled -and $cancel.Current.IsEnabled
  } 'The app did not enter its running inspection state.' 1200
  $tree=Open-NativeCancelTree -LogPath $FixtureLog -PilotProcess $process -PinnedPowerShell $config.pwsh -TimeoutSeconds 6
 }catch{
  $startError=$_.Exception.Message
  try{
   $result.workflow.handshakeFailure=@(Get-SmokeTextNames $root | Where-Object {
    $_ -match '^(completed|cancelled|timed_out|output_limit|Inspection complete|Git probe failed)'
   } | Select-Object -First 8)
  }catch{}
  throw $startError
 }
 try{
  Assert-OwnedIdentity
  Invoke-SmokeButton 'cancel'
 }finally{
  $result.workflow.cancellation=Wait-NativeCancelTreeExit -Tree $tree
 }
 Assert-OwnedIdentity
 if(-not $result.workflow.cancellation.AllExited){throw 'A process in the owned cancellation tree did not exit.'}
 $backend=Wait-SmokeObservation {
  $status=@(Get-SmokeTextNames $root | Where-Object {$_ -clike 'Cancelled. Result discarded*'})
  $meta=Find-SmokeMeta '^cancelled\s*\u00B7\s*Exit\s'
  $inspect=Get-SmokeElement $root 'inspect'
  $cancel=Get-SmokeElement $root 'cancel'
  if($status.Count -eq 1 -and $meta -and
     $inspect.Current.IsEnabled -and -not $cancel.Current.IsEnabled){
   return [ordered]@{status=$status[0];meta=$meta;inspectEnabled=$true;cancelEnabled=$false}
  }
 } 'The app did not report backend cancellation and restore idle controls.' 3000
 $result.workflow.cancellationStatus=$backend
}
