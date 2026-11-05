$ErrorActionPreference='Stop'
$toolRoot='C:\Users\Sean Shaffer\Documents\DevTools'
$request=Join-Path $PSScriptRoot 'ui-final-request.json'
$helper='C:\Users\Sean Shaffer\.codex\skills\ruflo-agency\scripts\run.py'
$stamp=[Guid]::NewGuid().ToString('N');$stdout=Join-Path $PSScriptRoot ('ui-launcher-'+$stamp+'.stdout.json');$stderr=Join-Path $PSScriptRoot ('ui-launcher-'+$stamp+'.stderr.txt')
$child=Start-Process -FilePath 'C:\Python315\python.exe' -ArgumentList @(('"'+$helper+'"'),'--request',('"'+$request+'"')) -WorkingDirectory $toolRoot -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
@{processId=$child.Id;stdout=$stdout;stderr=$stderr;request=$request}|ConvertTo-Json -Compress
