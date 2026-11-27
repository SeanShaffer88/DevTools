[CmdletBinding()]
param([Parameter(Mandatory)][string]$Path)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath($Path)
if (![IO.Path]::IsPathFullyQualified($Path) -or $root.StartsWith('\\') -or $root.Substring(2).Contains(':')) { throw 'Only absolute local paths without alternate streams are accepted.' }
if (Test-Path -LiteralPath $root) { throw 'Offline root must be a new directory.' }
$parent = Split-Path -Parent $root
if (!(Test-Path -LiteralPath $parent -PathType Container)) { throw 'Offline root parent must exist.' }
$current = Get-Item -LiteralPath $parent -Force
while ($null -ne $current) {
    if ($current.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Linked ancestor refused.' }
    $current = $current.Parent
}
[IO.Directory]::CreateDirectory($root) | Out-Null
@{ schemaVersion = 1; purpose = 'DevTools disposable offline build root'; id = [guid]::NewGuid().ToString(); root = $root } |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $root '.devtools-offline-owned.json') -Encoding utf8
$root
