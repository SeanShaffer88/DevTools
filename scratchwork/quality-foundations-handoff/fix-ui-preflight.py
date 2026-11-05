from pathlib import Path
p=Path('lib/QualityUiWorker.ps1');s=p.read_text();needle="if(@($assertions.workflow).Count -gt 100){throw 'Workflow action limit exceeded.'}"
s=s.replace(needle,needle+";if($result.truncated){throw 'Workflow refused: initial UI tree is truncated.'};if(@($assertions.workflow|Where-Object {$_.action -ceq 'Tab'}).Count){throw 'Unsupported: Tab requires an app-owned navigation adapter; global keyboard injection is disabled.'}")
a=s.index(";$action=[string]$step.action;if($action -ceq 'Tab'){");b=s.index('$target=Resolve-Element',a)
s=s[:a]+";$action=[string]$step.action;"+s[b:]
s=s.replace("default{throw 'Unsupported workflow action.'}}};Start-Sleep", "default{throw 'Unsupported workflow action.'}};Start-Sleep")
p.write_text(s)
