$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$window=New-Object Windows.Window;$window.Title='Quality fixture';$window.Width=360;$window.Height=290
$panel=New-Object Windows.Controls.StackPanel;$panel.Margin=New-Object Windows.Thickness(20)
$input=New-Object Windows.Controls.TextBox;[Windows.Automation.AutomationProperties]::SetAutomationId($input,'FixtureInput');[Windows.Automation.AutomationProperties]::SetName($input,'Input')
$button=New-Object Windows.Controls.Button;$button.Content='Apply';[Windows.Automation.AutomationProperties]::SetAutomationId($button,'FixtureApply');$button.Margin=New-Object Windows.Thickness(0,20,0,0)
$button.Add_Click({$button.Content='Applied';[Windows.Automation.AutomationProperties]::SetName($button,'Applied');$label=New-Object Windows.Controls.TextBlock;$label.Text='Added';[Windows.Automation.AutomationProperties]::SetAutomationId($label,'FixtureAdded');$panel.Children.Add($label)|Out-Null})
$duplicate=New-Object Windows.Controls.Button;$duplicate.Content='Apply';[Windows.Automation.AutomationProperties]::SetAutomationId($duplicate,'FixtureDuplicate')
$rename=New-Object Windows.Controls.Button;$rename.Content='RenameTarget';[Windows.Automation.AutomationProperties]::SetAutomationId($rename,'FixtureRename')
$count=New-Object Windows.Controls.TextBlock;$count.Text='Clicks: 0';[Windows.Automation.AutomationProperties]::SetAutomationId($count,'FixtureClicks');$script:clicks=0
$rename.Add_Click({$script:clicks++;$rename.Content='RenamedTarget';[Windows.Automation.AutomationProperties]::SetName($rename,'RenamedTarget');$count.Text='Clicks: '+$script:clicks})
$panel.Children.Add($input)|Out-Null;$panel.Children.Add($button)|Out-Null;$panel.Children.Add($duplicate)|Out-Null;$panel.Children.Add($rename)|Out-Null;$panel.Children.Add($count)|Out-Null;$window.Content=$panel
$timer=New-Object Windows.Threading.DispatcherTimer;$timer.Interval=[TimeSpan]::FromSeconds(90);$timer.Add_Tick({$window.Close()});$timer.Start();$null=$window.ShowDialog()
