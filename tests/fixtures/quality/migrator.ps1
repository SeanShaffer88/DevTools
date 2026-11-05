param([string]$InputRoot,[string]$OutputRoot,[string]$Mode='Migrate',[string]$Quoted)
$ErrorActionPreference='Stop'
if($Quoted -cne 'space and "quote"'){throw 'Argument boundary damaged'}
if($Mode -eq 'Corrupt'){Set-Content -LiteralPath (Join-Path $OutputRoot 'rejected.txt') -Value 'rejected';Set-Content -LiteralPath (Join-Path $OutputRoot 'settings.json') -Value '{"schemaVersion":2,"rejected":true}';exit 7}
if($Mode -eq 'Timeout'){Start-Sleep -Seconds 15;exit 0}
if($Mode -eq 'Crash'){exit 9}
if($Mode -eq 'Rollback'){Copy-Item -LiteralPath (Join-Path $InputRoot 'settings.json') -Destination (Join-Path $OutputRoot 'settings.json');exit 0}
$d=Get-Content -LiteralPath (Join-Path $InputRoot 'settings.json') -Raw | ConvertFrom-Json -AsHashtable
if($Mode -eq 'MutateBoth'){$d.keep.unicode='changed';$d|ConvertTo-Json -Depth 10|Set-Content -LiteralPath (Join-Path $InputRoot 'settings.json')}
$d.schemaVersion=2
$d['transformed']='done'
$d|ConvertTo-Json -Depth 10|Set-Content -LiteralPath (Join-Path $OutputRoot 'settings.json')
