from pathlib import Path
p=Path('tests/Test-QualityFoundations.ps1');s=p.read_text().replace("workflow=@(@{action='Tab'})", "workflow=@(@{action='Invoke';selector=@{name='Quality fixture';controlType='Window'}},@{action='Tab'})")
s=s.replace("Check 'Tab explicitly unsupported'", "Check 'Tab rejected before preceding workflow input'")
p.write_text(s)
