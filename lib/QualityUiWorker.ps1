#requires -Version 5.1
param([Parameter(Mandatory)][int]$ProcessId,[Parameter(Mandatory)][string]$ExpectedStartUtc,[Parameter(Mandatory)][string]$AssertionsPath,[switch]$AllowActions,[int]$MaxNodes=2000,[int]$MaxDepth=20)
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=New-Object Text.UTF8Encoding($false)
# Avoid inherited PowerShell 7 module paths in a Windows PowerShell worker.
$env:PSModulePath=[IO.Path]::Combine($PSHOME,'Modules')
Add-Type -AssemblyName UIAutomationClient,UIAutomationTypes
Add-Type -Path ([IO.Path]::Combine($PSScriptRoot,'WindowsDiagnosticsNative.cs'))
Add-Type -TypeDefinition @'
using System;using System.Runtime.InteropServices;
public static class QualityUiNative {
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h,out uint pid);
}
'@
$owned=$null;$result=[ordered]@{schemaVersion=1;scope='LiveOwnedUiAutomation';valid=$false;status='Unknown';nodes=@();workflow=@();truncated=$false;error=$null;processId=$ProcessId;startUtc=$ExpectedStartUtc}
function Get-Field($Object,[string]$Name) {$Object.PSObject.Properties[$Name]}
function Check-Identity {
 $owned.EnsureRunning();$p=Get-Process -Id $ProcessId -ErrorAction Stop;if($p.StartTime.ToUniversalTime() -ne [DateTime]::Parse($ExpectedStartUtc).ToUniversalTime()){throw 'Target process identity changed.'}
 [uint32]$windowProcess=0;$null=[QualityUiNative]::GetWindowThreadProcessId($script:window,[ref]$windowProcess);if($windowProcess -ne $ProcessId){throw 'Target window identity changed.'}
}
function Resolve-Element($Selector) {
 Check-Identity;Capture-Tree;if($result.truncated){throw 'Workflow refused: current UI tree is truncated.'};Check-Identity
 if($null -eq $Selector){throw 'Selector required.'};$criteria=@('automationId','name','controlType')|Where-Object {$null -ne (Get-Field $Selector $_)};if($criteria.Count -eq 0){throw 'Selector must constrain at least one identity field.'}
 $matches=@($script:items|Where-Object{$ok=$true;foreach($key in $criteria){$expected=$Selector.$key;if($expected -isnot [string]){throw 'Selector values must be strings.'};if(-not [string]::Equals([string]$_.snapshot[$key],$expected,[StringComparison]::Ordinal)){$ok=$false}};$ok});if($matches.Count -ne 1){throw 'Selector is missing or ambiguous.'};$matches[0]
}
function Check-Element($Element) {
 $cursor=$Element;for($i=0;$i -le 40 -and $null -ne $cursor;$i++){
  if($cursor.Current.ProcessId -ne $ProcessId){throw 'Element ancestry left selected process.'}
  if([Windows.Automation.Automation]::Compare($cursor,$root)){return}
  $cursor=$walker.GetParent($cursor)
 };throw 'Element no longer belongs to selected window.'
}
function Capture-Tree {
 $result.truncated=$false
 $script:root=[Windows.Automation.AutomationElement]::FromHandle($script:window);$script:walker=[Windows.Automation.TreeWalker]::ControlViewWalker;$queue=New-Object 'Collections.Generic.Queue[object]';$queue.Enqueue(@{element=$root;depth=0});$script:items=New-Object 'Collections.Generic.List[object]'
 while($queue.Count){Check-Identity;$entry=$queue.Dequeue();$element=$entry.element;$current=$element.Current;if($current.ProcessId -ne $ProcessId){continue};$patterns=@($element.GetSupportedPatterns()|ForEach-Object {$_.ProgrammaticName.Replace('PatternIdentifiers.Pattern','').Replace('PatternIdentifiers','').Replace('.Pattern','')})
  $snapshot=[ordered]@{automationId=$current.AutomationId;name=$current.Name;controlType=$current.ControlType.ProgrammaticName.Replace('ControlType.','');enabled=$current.IsEnabled;keyboardFocusable=$current.IsKeyboardFocusable;password=$current.IsPassword;offscreen=$current.IsOffscreen;patterns=$patterns;hasKeyboardFocus=$current.HasKeyboardFocus}
  $script:items.Add(@{element=$element;snapshot=$snapshot});if($script:items.Count -ge $MaxNodes){if($queue.Count -or $null -ne $walker.GetFirstChild($element)){$result.truncated=$true};break}
  if($entry.depth -ge $MaxDepth){if($null -ne $walker.GetFirstChild($element)){$result.truncated=$true};continue};$child=$walker.GetFirstChild($element);while($null -ne $child){$queue.Enqueue(@{element=$child;depth=$entry.depth+1});if($queue.Count -gt $MaxNodes){$result.truncated=$true;break};$child=$walker.GetNextSibling($child)}
 }
}
try {
 if($MaxNodes -lt 1 -or $MaxNodes -gt 10000 -or $MaxDepth -lt 1 -or $MaxDepth -gt 40){throw 'Invalid UI traversal bounds.'}
 $owned=[LocalDevTools.OwnedProcess]::Open($ProcessId);if($owned.StartUtc -ne [DateTime]::Parse($ExpectedStartUtc).ToUniversalTime()){throw 'Selected process creation time changed.'}
 $process=Get-Process -Id $ProcessId;$script:window=$process.MainWindowHandle;if($script:window -eq [IntPtr]::Zero){throw 'Selected process has no main window.'};Check-Identity
 Capture-Tree
 $file=Get-Item -LiteralPath $AssertionsPath;if($file.Length -gt 4194304){throw 'Assertions exceed size limit.'};$assertions=[IO.File]::ReadAllText($file.FullName,[Text.Encoding]::UTF8)|ConvertFrom-Json
 if((Get-Field $assertions 'workflow') -and @($assertions.workflow).Count){if(-not $AllowActions){throw 'AllowActions required for workflow.'};if(@($assertions.workflow).Count -gt 100){throw 'Workflow action limit exceeded.'};if($result.truncated){throw 'Workflow refused: initial UI tree is truncated.'};if(@($assertions.workflow|Where-Object {$_.action -ceq 'Tab'}).Count){throw 'Unsupported: Tab requires an app-owned navigation adapter; global keyboard injection is disabled.'}
  foreach($step in $assertions.workflow){Check-Identity;$action=[string]$step.action;$target=Resolve-Element $step.selector;$element=$target.element;Check-Element $element;if($element.Current.ProcessId -ne $ProcessId){throw 'Selected element changed process.'};switch -CaseSensitive ($action){'SetFocus'{$element.SetFocus()}'Invoke'{$pattern=$element.GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern);$pattern.Invoke()}'SetValue'{if(-not $element.Current.HasKeyboardFocus){throw 'SetValue refused: selected element does not have focus.'};if($element.Current.IsPassword){throw 'Password-field modification is not supported.'};if($step.value -isnot [string]){throw 'SetValue requires a string.'};$pattern=$element.GetCurrentPattern([Windows.Automation.ValuePattern]::Pattern);$pattern.SetValue($step.value)}default{throw 'Unsupported workflow action.'}};Start-Sleep -Milliseconds 40;Check-Identity
   $focus=[Windows.Automation.AutomationElement]::FocusedElement;$result.workflow+=@{action=$action;focusAutomationId=if($focus -and $focus.Current.ProcessId -eq $ProcessId){$focus.Current.AutomationId}else{$null}}
  }
 }
 Check-Identity;Capture-Tree;$result.nodes=@($script:items|ForEach-Object {$_.snapshot});$result.status=if($result.truncated){'Unknown'}else{'Pass'};$result.valid=-not $result.truncated
} catch {$result.status='Unknown';$result.error=$_.Exception.Message} finally {if($null -ne $owned){$owned.Dispose()}}
$result|ConvertTo-Json -Depth 30 -Compress
if($result.valid){exit 0}else{exit 3}

