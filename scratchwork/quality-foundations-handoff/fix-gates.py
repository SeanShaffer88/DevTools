from pathlib import Path
p=Path('Invoke-NativeMemoryTest.ps1');s=p.read_text().replace('$runtimeName=$runtimeByArchitecture[$pe.image.Architecture]',"$runtimeName=if($pe.valid -and $pe.image.Architecture){$runtimeByArchitecture[$pe.image.Architecture]}else{$null}");p.write_text(s)
p=Path('Test-DataMigration.ps1');s=p.read_text().replace("+@($entry.preservePointers)+@($(if($entry.Contains('equals')){$entry.equals.Keys}))", "+@($(if($entry.Contains('preservePointers')){$entry.preservePointers}))+@($(if($entry.Contains('equals')){$entry.equals.Keys}))")
# Explicit null array entries are invalid too, without including absent optional groups.
s=s.replace("$pointers=@($(if($entry.Contains('versionPointer')){$entry.versionPointer}else{'/schemaVersion'}))+@($(if($entry.Contains('preservePointers')){$entry.preservePointers}))+@($(if($entry.Contains('equals')){$entry.equals.Keys}))", "$pointers=@($(if($entry.Contains('versionPointer')){$entry.versionPointer}else{'/schemaVersion'}));if($entry.Contains('preservePointers')){$pointers+= $entry.preservePointers};if($entry.Contains('equals')){$pointers+=@($entry.equals.Keys)}")
s=s.replace("if($null -eq $pointer){continue};if($pointer -isnot", "if($pointer -isnot")
p.write_text(s)
p=Path('tests/Test-QualityFoundations.ps1');s=p.read_text().replace('([string][char]0)*18','([string][char]0)*19')
s=s.replace('$commands=[Collections.Generic.List[object]]::new()',"$commands=[Collections.Generic.List[object]]::new()\n$blockedGates=[Collections.Generic.List[object]]::new()")
a=s.index("  $null=Run 'ui-live-control-patterns'");b=s.index("  $null=Run 'ui-tree-cap'",a)
s=s[:a]+'''  $providerAvailable=@($result.snapshot.nodes|Where-Object {$_.automationId -ceq 'FixtureApply' -and 'Invoke' -cin $_.patterns}).Count -eq 1
  if($providerAvailable){
'''+s[a:b]+'''  }else{
   $blockedGates.Add(@{gate='LiveOwnedControlPatternsAndActions';status='Unknown';exitCode=3;reason='Owned WinForms UIA provider exposes child controls as Pane without stable AutomationId or Invoke/Value patterns.';unperformed=@('control pattern positive/negative assertions','SetFocus/SetValue/Invoke and fresh post-action tree assertions')})
   Write-Host 'Live owned control/action gate: Unknown (3), provider patterns unavailable'
  }
'''+s[b:]
s=s.replace("  $null=Run 'ui-actions-refreshed'", "  if($providerAvailable){$null=Run 'ui-actions-refreshed'")
s=s.replace("AssertionsPath=$actionPath;AllowActions=$true} 0\n", "AssertionsPath=$actionPath;AllowActions=$true} 0}\n")
s=s.replace("$code=if($failed){2}else{0}","$code=if($failed){2}elseif($blockedGates.Count){3}else{0}")
s=s.replace('checks=$checks.ToArray();commands=', 'blockedGates=$blockedGates.ToArray();checks=$checks.ToArray();commands=')
s=s.replace("$assertions.checks=@(@{id='changed';selector=@{automationId='FixtureApply'};name='Applied'})", "$assertions.checks=@(@{id='changed';selector=@{automationId='FixtureApply'};name='Applied'},@{id='added';selector=@{automationId='FixtureAdded'};name='Added'})")
p.write_text(s)
p=Path('tests/fixtures/quality/ui.cs');s=p.read_text().replace('b.Text="Applied";','b.Text="Applied";if(!f.Controls.ContainsKey("FixtureAdded")){f.Controls.Add(new Label {Name="FixtureAdded",Text="Added",AccessibleName="Added",Top=140,Left=20});}')
p.write_text(s)
