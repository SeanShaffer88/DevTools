$ErrorActionPreference='Stop'
$out=Join-Path $PSScriptRoot 'probe.stdout.txt'
$err=Join-Path $PSScriptRoot 'probe.stderr.txt'
$script=Join-Path $PSScriptRoot 'probe-child.py'
$p=Start-Process -FilePath 'C:\Python315\python.exe' -ArgumentList ('"'+$script+'"') -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -RedirectStandardOutput $out -RedirectStandardError $err -PassThru -Wait
if($null -eq $p.ExitCode -or $p.ExitCode -ne 0 -or [IO.File]::ReadAllText($out).Trim() -cne 'QUALITY_BACKGROUND_OK'){throw 'Probe output or exit failure.'}
@{success=$true;childExitCode=$p.ExitCode;stdout=$out;stderr=$err}|ConvertTo-Json -Compress
