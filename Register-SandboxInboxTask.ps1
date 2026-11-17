#requires -Version 7.4
<#
.SYNOPSIS
Registers (or removes) a current-user Windows scheduled task that sweeps the build-sandbox inbox
every few minutes, so jobs dropped by ChatGPT run without anyone starting them.

.DESCRIPTION
The task runs: pwsh -NoProfile -NonInteractive -File New-BuildSandbox.ps1 -InboxRoot ... -OutboxRoot ... -ImagePath ...
  - Current user, only while logged on (WSL needs the user's session); no elevation, no stored password.
  - Overlapping sweeps are prevented (MultipleInstances = IgnoreNew); each sweep is capped at 6 hours.
  - Each sweep appends its JSON result to <OutboxRoot>\.sweep-log\<yyyy-MM-dd>.jsonl.
This is a persistent change to the user's scheduled tasks; nothing is registered by -WhatIf.
Use -Unregister to remove it again. Use -Status to show the task and its last run.

.EXAMPLE
./Register-SandboxInboxTask.ps1 -InboxRoot D:\sandbox\inbox -OutboxRoot D:\sandbox\outbox -ImagePath $env:LOCALAPPDATA\BuildSandbox\images\build-sandbox.tar -WhatIf
.EXAMPLE
./Register-SandboxInboxTask.ps1 -Unregister
#>
[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Register')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Register')][string]$InboxRoot,
    [Parameter(Mandatory, ParameterSetName = 'Register')][string]$OutboxRoot,
    [Parameter(Mandatory, ParameterSetName = 'Register')][string]$ImagePath,
    [Parameter(ParameterSetName = 'Register')][ValidateRange(1, 1440)][int]$IntervalMinutes = 5,
    [Parameter(ParameterSetName = 'Register')][switch]$NoDevTools,
    [Parameter(Mandatory, ParameterSetName = 'Unregister')][switch]$Unregister,
    [Parameter(Mandatory, ParameterSetName = 'Status')][switch]$Status,
    [ValidatePattern('^[A-Za-z0-9 _.-]{1,64}$')][string]$TaskName = 'DevTools Build Sandbox Inbox'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$TaskPath = '\DevTools\'

function Resolve-SafePath([string]$Path, [string]$Label, [switch]$File) {
    $item = Get-Item -LiteralPath $Path
    if ($File -and $item.PSIsContainer) { throw "$Label must be a file: $Path" }
    if (-not $File -and -not $item.PSIsContainer) { throw "$Label must be a directory: $Path" }
    # The path is embedded in a command line; quotes would break out of the argument.
    if ($item.FullName -match '["%]') { throw "$Label must not contain quotes or percent signs: $($item.FullName)" }
    $item.FullName.TrimEnd('\')
}

switch ($PSCmdlet.ParameterSetName) {
    'Status' {
        $task = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue
        if (-not $task) { "Task '$TaskPath$TaskName' is not registered."; return }
        $info = $task | Get-ScheduledTaskInfo
        [pscustomobject]@{ Task = "$TaskPath$TaskName"; State = $task.State; LastRunTime = $info.LastRunTime
                           LastTaskResult = $info.LastTaskResult; NextRunTime = $info.NextRunTime
                           Command = ($task.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)" }) -join '; ' }
    }
    'Unregister' {
        $task = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue
        if (-not $task) { "Task '$TaskPath$TaskName' is not registered; nothing to remove."; return }
        if ($PSCmdlet.ShouldProcess("$TaskPath$TaskName", 'Unregister scheduled task')) {
            Unregister-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -Confirm:$false
            "Removed scheduled task '$TaskPath$TaskName'."
        }
    }
    'Register' {
        $inbox = Resolve-SafePath $InboxRoot 'InboxRoot'
        $outbox = Resolve-SafePath $OutboxRoot 'OutboxRoot'
        $image = Resolve-SafePath $ImagePath 'ImagePath' -File
        $script = Resolve-SafePath (Join-Path $PSScriptRoot 'New-BuildSandbox.ps1') 'New-BuildSandbox.ps1' -File
        $pwsh = (Get-Command pwsh -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
        if ($outbox.StartsWith($inbox + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'OutboxRoot must not be inside InboxRoot.' }

        # Wrapper command: run one sweep and append its JSON result to a dated log in the outbox.
        $logDir = Join-Path $outbox '.sweep-log'
        $sweep = "& '$($script.Replace("'", "''"))' -InboxRoot '$($inbox.Replace("'", "''"))' -OutboxRoot '$($outbox.Replace("'", "''"))' -ImagePath '$($image.Replace("'", "''"))' -Json$(if ($NoDevTools) { ' -NoDevTools' })"
        $command = "`$null = New-Item -ItemType Directory -Force -Path '$($logDir.Replace("'", "''"))'; " +
                   "`$r = $sweep; " +
                   "(`$r -join ' ') | Add-Content -LiteralPath (Join-Path '$($logDir.Replace("'", "''"))' ((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd') + '.jsonl'))"
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
        $action = New-ScheduledTaskAction -Execute $pwsh -Argument "-NoProfile -NonInteractive -WindowStyle Hidden -EncodedCommand $encoded"
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes)
        $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 6) `
            -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
        $principal = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited

        $description = "Runs New-BuildSandbox.ps1 inbox sweeps every $IntervalMinutes min. Inbox: $inbox. Outbox: $outbox. Remove with Register-SandboxInboxTask.ps1 -Unregister."
        if ($PSCmdlet.ShouldProcess("$TaskPath$TaskName", "Register scheduled task (every $IntervalMinutes min, current user, not elevated)")) {
            $null = Register-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings `
                -Principal $principal -Description $description -Force
            "Registered '$TaskPath$TaskName': sweeps $inbox every $IntervalMinutes min; results in $outbox, sweep log in $logDir."
        } else {
            [pscustomobject]@{ Task = "$TaskPath$TaskName"; Execute = $pwsh; Command = $command; IntervalMinutes = $IntervalMinutes; SweepLog = $logDir }
        }
    }
}
