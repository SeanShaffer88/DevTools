#requires -Version 7.0
[CmdletBinding()]param()
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. "$root/lib/ReliabilityScenarios.ps1"
$p=Join-Path $root 'work/devtools-reliability-wave/scenarios/duplicate.json'
[IO.File]::WriteAllText($p,'{"schemaVersion":1,"schemaVersion":1}')
$rejected=$false;try{Read-SJson $p | Out-Null}catch{$rejected=$true}
if(-not $rejected){throw 'Duplicate JSON fields must be rejected before any action.'}
Write-Output 'Strict JSON rejection passed.'
