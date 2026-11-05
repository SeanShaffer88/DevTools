param([Parameter(Mandatory)][string]$FixturePath,[switch]$Register,[string]$WpfScript)
$ErrorActionPreference='Stop';$env:PSModulePath=[IO.Path]::Combine($PSHOME,'Modules')
Add-Type -AssemblyName UIAutomationClient,UIAutomationTypes
$registration='NotRequested'
if($Register){$assembly=[Reflection.Assembly]::LoadFrom([IO.Path]::Combine([Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory(),'WPF\UIAutomationClientsideProviders.dll'));[Windows.Automation.ClientSettings]::RegisterClientSideProviderAssembly($assembly.GetName());$registration='RegisteredInstalledFrameworkProvider'}
$fixture=$null
try{
 $fixture=New-Object Diagnostics.Process;$fixture.StartInfo=New-Object Diagnostics.ProcessStartInfo($FixturePath);$fixture.StartInfo.UseShellExecute=$false;$fixture.StartInfo.CreateNoWindow=$true;if($WpfScript){if($WpfScript.Contains('"')){throw 'Invalid fixed probe script path.'};$fixture.StartInfo.Arguments='-NoProfile -NonInteractive -ExecutionPolicy Bypass -STA -File "'+$WpfScript+'"'};$null=$fixture.Start()
 for($i=0;$i -lt 50;$i++){$fixture.Refresh();if($fixture.HasExited){throw 'Own fixture exited.'};if($fixture.MainWindowHandle -ne [IntPtr]::Zero){break};Start-Sleep -Milliseconds 100}
 if($fixture.MainWindowHandle -eq [IntPtr]::Zero){throw 'Own fixture did not create window.'}
 $root=[Windows.Automation.AutomationElement]::FromHandle($fixture.MainWindowHandle);$q=New-Object 'Collections.Generic.Queue[object]';$q.Enqueue($root);$nodes=@();$walker=[Windows.Automation.TreeWalker]::ControlViewWalker
 while($q.Count -and $nodes.Count -lt 40){$e=$q.Dequeue();$c=$e.Current;if($c.ProcessId -ne $fixture.Id){continue};$nodes+=@{automationId=$c.AutomationId;name=$c.Name;controlType=$c.ControlType.ProgrammaticName;patterns=@($e.GetSupportedPatterns()|ForEach-Object {$_.ProgrammaticName})};$child=$walker.GetFirstChild($e);while($child){$q.Enqueue($child);if($q.Count -ge 40){break};$child=$walker.GetNextSibling($child)}}
 @{schemaVersion=1;registration=$registration;scope='DedicatedOwnedFixtureLocalProviderProbe';processId=$fixture.Id;nodes=$nodes}|ConvertTo-Json -Depth 12 -Compress
}finally{if($fixture){$fixture.Refresh();if(-not $fixture.HasExited){$fixture.Kill();$fixture.WaitForExit()}}}
