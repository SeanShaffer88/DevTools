param([string]$InputPath)
$b=[IO.File]::ReadAllBytes($InputPath);$s=[Text.Encoding]::UTF8.GetString($b)
if($s.Contains('TIME')){Start-Sleep -Seconds 15;exit 0}
if($s.Contains('OUTPUT')){[Console]::Write(('X'*100000));exit 0}
if($s.Contains('BUG')){exit 42}
if($s -ceq 'valid'){exit 0}
exit 1
