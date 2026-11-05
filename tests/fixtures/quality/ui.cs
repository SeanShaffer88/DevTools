using System;
using System.Windows.Forms;
public class Fixture {
 [STAThread] public static void Main() {
 AppContext.SetSwitch("Switch.System.Windows.Forms.UseLegacyAccessibilityFeatures", false);
 AppContext.SetSwitch("Switch.System.Windows.Forms.UseLegacyAccessibilityFeatures.2", false);
 AppContext.SetSwitch("Switch.System.Windows.Forms.UseLegacyAccessibilityFeatures.3", false);
 Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);
 using(var f=new Form {Text="Quality fixture",Name="QualityFixture",Width=360,Height=210})
 using(var timer=new Timer {Interval=90000}) {
 var t=new TextBox {Name="FixtureInput",AccessibleName="Input",Top=20,Left=20,TabIndex=0};
 var b=new Button {Name="FixtureApply",Text="Apply",AccessibleName="Apply",Top=60,Left=20,TabIndex=1};
 b.Click+=(s,e)=>{b.AccessibleName="Applied";b.Text="Applied";if(!f.Controls.ContainsKey("FixtureAdded")){f.Controls.Add(new Label {Name="FixtureAdded",Text="Added",AccessibleName="Added",Top=140,Left=20});}};
 var d=new Button {Name="FixtureDuplicate",Text="Apply",AccessibleName="Apply",Top=100,Left=20,TabIndex=2};
 f.Controls.AddRange(new Control[]{t,b,d});timer.Tick+=(s,e)=>f.Close();timer.Start();Application.Run(f);
 }
 }
}
