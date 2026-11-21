#requires -Version 7.4
<#
.SYNOPSIS
Summarises a build-sandbox run folder as compact Markdown, ready to paste back to ChatGPT
(or any reviewer): overall result, per-step table, log tails of failed steps, artifacts.

.DESCRIPTION
Reads <RunPath>\summary.json, <RunPath>\host\run.json and the step logs written by
New-BuildSandbox.ps1. Log content is produced by untrusted job code: it is fenced and
truncated, never interpreted. ANSI escape sequences and control characters are stripped.

.PARAMETER RunPath
An outbox run folder (<outbox>\<job>-<runId>) or a -Destination folder of a single run.
.PARAMETER TailLines
Lines of stdout/stderr shown per failed step (default 40). -AllSteps includes passing steps.
.PARAMETER OutFile
Also write the Markdown to this new file.
.EXAMPLE
./Get-SandboxReport.ps1 -RunPath D:\sandbox\outbox\mylib-20261117-093240-ad59c3 | Set-Clipboard
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RunPath,
    [ValidateRange(0, 2000)][int]$TailLines = 40,
    [switch]$AllSteps,
    [switch]$IncludeToolchains,
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

function Get-CleanTail([string]$Path, [int]$Count) {
    if ($Count -eq 0 -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @() }
    # Bounded read: only the last 256 KB of a (possibly huge) log.
    $stream = [IO.File]::OpenRead($Path)
    try {
        $take = [Math]::Min($stream.Length, 256KB)
        $null = $stream.Seek(-$take, [IO.SeekOrigin]::End)
        $buffer = [byte[]]::new($take)
        $read = 0; while ($read -lt $take) { $n = $stream.Read($buffer, $read, $take - $read); if ($n -le 0) { break }; $read += $n }
    } finally { $stream.Dispose() }
    $text = [Text.Encoding]::UTF8.GetString($buffer, 0, $read)
    $text = $text -replace "`e\[[0-9;?]*[ -/]*[@-~]", '' -replace "[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]", '' -replace '```', "'''"
    @($text -split "`r?`n" | Where-Object { $_ -ne '' } | Select-Object -Last $Count)
}

function Format-Cell([object]$Value) { "$Value" -replace '\|', '\|' -replace "`r?`n", ' ' }

function Format-Utc([object]$Value) {
    if ($Value -is [datetime]) { $Value.ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss 'UTC'") } else { "$Value" }
}

$ErrorPattern = '(?i)(\berror\b|\bfailed\b|\bfailure\b|exception|traceback|assert|undefined reference|segmentation fault|AddressSanitizer)'

$run = (Get-Item -LiteralPath $RunPath).FullName
$summaryPath = Join-Path $run 'summary.json'
$hostRun = Join-Path $run 'host\run.json'
$summary = if (Test-Path -LiteralPath $summaryPath) { Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json -AsHashtable } else { $null }
$hostInfo = if (Test-Path -LiteralPath $hostRun) { Get-Content -LiteralPath $hostRun -Raw | ConvertFrom-Json -AsHashtable } else { $null }
if (-not $summary -and -not $hostInfo) { throw "Not a build-sandbox run folder (no summary.json or host\run.json): $run" }

$md = [Text.StringBuilder]::new()
$passed = $hostInfo -and $hostInfo['passed'] -eq $true
$status = if ($passed) { 'PASSED' } elseif ($summary) { 'FAILED' } else { 'ERROR (no guest summary)' }
$null = $md.AppendLine("## Sandbox run: $status").AppendLine()
$null = $md.AppendLine("- Folder: ``$(Split-Path $run -Leaf)``")
if ($summary) {
    $null = $md.AppendLine("- Guest: $($summary['image']['os']); network $($summary['network']); DevTools mounted read-only: $($summary['devtoolsMounted'])")
    $null = $md.AppendLine("- Started $(Format-Utc $summary['startedUtc']), finished $(Format-Utc $summary['finishedUtc'])")
}
if ($hostInfo -and $hostInfo['error']) { $null = $md.AppendLine("- **Host error:** $(Format-Cell $hostInfo['error'])") }
if ($summary -and $summary['error']) { $null = $md.AppendLine("- **Guest error:** $(Format-Cell $summary['error'])") }
if ($hostInfo -and $hostInfo['timedOut']) { $null = $md.AppendLine('- **The job hit its overall timeout and was terminated.**') }

if ($summary -and $summary['steps']) {
    $null = $md.AppendLine().AppendLine('| # | Step | Result | Exit | Seconds |').AppendLine('|---|---|---|---|---|')
    $index = 0
    foreach ($step in $summary['steps']) {
        $index++
        $result = if ($step['passed']) { 'pass' } elseif ($step['timedOut']) { 'TIMEOUT' } elseif ($step['error']) { 'ERROR' } else { 'FAIL' }
        $null = $md.AppendLine("| $index | $(Format-Cell $step['name']) | $result | $($step['exitCode']) | $($step['durationSeconds']) |")
    }
    $index = 0
    foreach ($step in $summary['steps']) {
        $index++
        if ($step['passed'] -and -not $AllSteps) { continue }
        $null = $md.AppendLine().AppendLine("### $index. $($step['name'])$(if (-not $step['passed']) { ' (failed)' })")
        if ($step['error']) { $null = $md.AppendLine("Runner error: $(Format-Cell $step['error'])") }
        if (-not $step['passed']) {
            $errorLines = @(foreach ($stream in 'stdout', 'stderr') { Get-CleanTail (Join-Path $run $step[$stream]) 2000 }) |
                Where-Object { $_ -match $ErrorPattern } | Select-Object -Unique -First 12
            if (@($errorLines).Count) { $null = $md.AppendLine('Error lines:').AppendLine('```').AppendLine((@($errorLines) -join "`n")).AppendLine('```') }
        }
        foreach ($stream in 'stdout', 'stderr') {
            $lines = @(Get-CleanTail (Join-Path $run $step[$stream]) $TailLines)
            if ($lines.Count) { $null = $md.AppendLine("$stream (last $($lines.Count) lines):").AppendLine('```').AppendLine(($lines -join "`n")).AppendLine('```') }
        }
    }
    $total = @($summary['steps']).Count
    $ok = @($summary['steps'] | Where-Object { $_['passed'] }).Count
    $null = $md.AppendLine().AppendLine("**$ok/$total steps passed.**")
}

if ($IncludeToolchains -and $summary -and $summary['toolchains']) {
    $null = $md.AppendLine().AppendLine('### Toolchains')
    foreach ($key in $summary['toolchains'].Keys | Sort-Object) { $null = $md.AppendLine("- $key`: $($summary['toolchains'][$key]['detail'])") }
}

$artifactsDir = Join-Path $run 'artifacts'
if (Test-Path -LiteralPath $artifactsDir) {
    $artifacts = @(Get-ChildItem -LiteralPath $artifactsDir -Recurse -File | Sort-Object FullName)
    if ($artifacts.Count) {
        $null = $md.AppendLine().AppendLine("### Artifacts ($($artifacts.Count))")
        foreach ($a in $artifacts | Select-Object -First 25) { $null = $md.AppendLine("- ``$([IO.Path]::GetRelativePath($artifactsDir, $a.FullName).Replace('\', '/'))`` ($([Math]::Ceiling($a.Length / 1KB)) KB)") }
        if ($artifacts.Count -gt 25) { $null = $md.AppendLine("- ... and $($artifacts.Count - 25) more") }
    }
}
if ($hostInfo -and $hostInfo['skippedResultEntries'] -and @($hostInfo['skippedResultEntries']).Count) {
    $null = $md.AppendLine().AppendLine("Result entries refused by the host: $(@($hostInfo['skippedResultEntries']).Count)")
}

$report = $md.ToString()
if ($OutFile) {
    $target = [IO.Path]::GetFullPath($OutFile)
    if (Test-Path -LiteralPath $target) { throw "OutFile must not exist: $target" }
    [IO.File]::WriteAllText($target, $report, [Text.UTF8Encoding]::new($false))
}
$report
