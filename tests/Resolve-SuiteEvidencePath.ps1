#requires -Version 7.0
param([string]$FileName,[AllowEmptyString()][string]$EvidenceDirectory,[bool]$Explicit)

$ErrorActionPreference='Stop'
$toolRoot=Split-Path $PSScriptRoot -Parent
if (-not $Explicit) { return (Join-Path $toolRoot $FileName) }

if ([string]::IsNullOrWhiteSpace($EvidenceDirectory)) { throw 'EvidenceDirectory must be an existing local filesystem directory.' }
$directory=Get-Item -LiteralPath $EvidenceDirectory -Force
if ($directory -isnot [IO.DirectoryInfo]) { throw 'EvidenceDirectory must be an existing local filesystem directory.' }
. (Join-Path $toolRoot 'lib/PlatformResources.ps1')
$evidencePath=Assert-PlatformPath (Join-Path $directory.FullName $FileName)
if ([IO.Directory]::Exists($evidencePath)) { throw 'The evidence file path is a directory.' }
Write-Verbose "Evidence path: $evidencePath"
$evidencePath
