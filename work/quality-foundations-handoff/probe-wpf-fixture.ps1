$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$window=New-Object Windows.Window;$window.Title='Quality WPF fixture';$window.Width=360;$window.Height=210
$panel=New-Object Windows.Controls.StackPanel;$panel.Margin=New-Object Windows.Thickness(20)
$input=New-Object Windows.Controls.TextBox;[Windows.Automation.AutomationProperties]::SetAutomationId($input,'FixtureInput');[Windows.Automation.AutomationProperties]::SetName($input,'Input')
$button=New-Object Windows.Controls.Button;$button.Content='Apply';[Windows.Automation.AutomationProperties]::SetAutomationId($button,'FixtureApply');$button.Margin=New-Object Windows.Thickness(0,20,0,0)
$button.Add_Click({$button.Content='Applied';[Windows.Automation.AutomationProperties]::SetName($button,'Applied');$label=New-Object Windows.Controls.TextBlock;$label.Text='Added';[Windows.Automation.AutomationProperties]::SetAutomationId($label,'FixtureAdded');$panel.Children.Add($label)|Out-Null})
$panel.Children.Add($input)|Out-Null;$panel.Children.Add($button)|Out-Null;$window.Content=$panel
$timer=New-Object Windows.Threading.DispatcherTimer;$timer.Interval=[TimeSpan]::FromSeconds(30);$timer.Add_Tick({$window.Close()});$timer.Start();$null=$window.ShowDialog()
