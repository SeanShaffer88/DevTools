param([int]$LifetimeSeconds=90)
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$f=New-Object Windows.Forms.Form
$f.Text='Quality fixture';$f.Name='QualityFixture';$f.Width=360;$f.Height=210
$t=New-Object Windows.Forms.TextBox
$t.Name='FixtureInput';$t.AccessibleName='Input';$t.Top=20;$t.Left=20;$t.TabIndex=0
$b=New-Object Windows.Forms.Button
$b.Name='FixtureApply';$b.Text='Apply';$b.AccessibleName='Apply';$b.Top=60;$b.Left=20;$b.TabIndex=1
$b.Add_Click({$b.AccessibleName='Applied';$b.Text='Applied'})
$d=New-Object Windows.Forms.Button
$d.Name='FixtureDuplicate';$d.Text='Apply';$d.AccessibleName='Apply';$d.Top=100;$d.Left=20;$d.TabIndex=2
$f.Controls.AddRange(@($t,$b,$d))
$timer=New-Object Windows.Forms.Timer
$timer.Interval=$LifetimeSeconds*1000
$timer.Add_Tick({$f.Close()});$timer.Start()
[Windows.Forms.Application]::Run($f)
$timer.Dispose();$f.Dispose()
