function New-NativeCancelFixture {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$EvidencePath,
        [Parameter(Mandatory)][string]$PilotPath
    )
    $root = Join-Path (Get-Item -LiteralPath $EvidencePath -ErrorAction Stop).FullName 'cancel-fixture'
    $source = Join-Path $PilotPath 'tests/NativeCancelGit.cs'
    $compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Fixture source unavailable: $source" }
    if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) { throw "Framework C# compiler unavailable: $compiler" }
    $null = New-Item -ItemType Directory -Path $root -ErrorAction Stop
    $bin = Join-Path $root 'bin'
    $project = Join-Path $root 'project'
    $null = New-Item -ItemType Directory -Path $bin, $project -ErrorAction Stop
    Set-Content -LiteralPath (Join-Path $project 'README.md') -Value 'Owned cancellation fixture.' -Encoding ascii
    $shim = Join-Path $bin 'git.exe'
    $compileLog = Join-Path $root 'compile.log'
    & $compiler '/nologo' '/target:exe' '/platform:x64' "/out:$shim" $source *> $compileLog
    $compilerExit = $LASTEXITCODE
    if ($compilerExit -ne 0 -or -not (Test-Path -LiteralPath $shim -PathType Leaf)) {
        throw "Cancellation fixture compiler exit $compilerExit. See $compileLog"
    }
    [pscustomobject]@{
        BinPath = $bin
        ProjectPath = $project
        LogPath = Join-Path $root 'run-cancel.log'
        CompilerExit = $compilerExit
        CompileLog = $compileLog
    }
}

function Open-NativeCancelTree {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$LogPath,
        [Parameter(Mandatory)][Diagnostics.Process]$PilotProcess,
        [Parameter(Mandatory)][string]$PinnedPowerShell,
        [ValidateRange(1,15)][int]$TimeoutSeconds = 10
    )
    if (-not ('InspectorFixtureProcessTree' -as [type])) {
        Add-Type -Path (Join-Path $PSScriptRoot 'NativeCancelGit.cs') -ErrorAction Stop
    }
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $childMarker = "$LogPath.child"
    while (-not (Test-Path -LiteralPath $LogPath) -or -not (Test-Path -LiteralPath $childMarker)) {
        foreach ($failure in "$LogPath.git.error", "$LogPath.child.error") {
            if (Test-Path -LiteralPath $failure -PathType Leaf) {
                $detail = Get-Content -LiteralPath $failure -TotalCount 1 -ErrorAction Stop
                throw "Cancellation fixture failed at $detail. See $failure"
            }
        }
        if ($PilotProcess.HasExited) { throw 'Owned pilot exited before the cancellation handshake.' }
        if ($clock.Elapsed.TotalSeconds -ge $TimeoutSeconds) { throw 'Cancellation fixture handshake timed out.' }
        Start-Sleep -Milliseconds 25
    }

    $log = Get-Item -LiteralPath $LogPath -ErrorAction Stop
    $shim = Join-Path $log.DirectoryName 'bin/git.exe'
    $reported = @(Get-Content -LiteralPath $LogPath -ErrorAction Stop)
    if ($reported.Count -ne 2 -or (Get-Content -LiteralPath $childMarker -Raw -ErrorAction Stop) -cne $reported[1]) {
        throw 'Cancellation fixture handshake mismatch.'
    }

    $processes = [Collections.Generic.List[Diagnostics.Process]]::new()
    try {
        foreach ($row in $reported) {
            $parts = $row.Split('|')
            if ($parts.Count -ne 3 -or $parts[2] -ine $shim) { throw 'Unexpected process in cancellation handshake.' }
            $process = [Diagnostics.Process]::GetProcessById([int]$parts[0])
            $processes.Add($process)
            $null = $process.Handle
            if ($process.HasExited -or $process.Path -ine $shim -or
                $process.StartTime.ToUniversalTime().Ticks -ne [long]$parts[1]) {
                throw 'Cancellation fixture process identity changed.'
            }
        }
        $git = $processes[0]
        $child = $processes[1]
        $parents = [InspectorFixtureProcessTree]::Snapshot()
        if (-not $parents.ContainsKey($git.Id) -or -not $parents.ContainsKey($child.Id) -or
            $parents[$child.Id] -ne $git.Id) {
            throw 'Cancellation child did not belong to the exact Git fixture process.'
        }
        $helperId = $parents[$git.Id]
        if (-not $parents.ContainsKey($helperId) -or $parents[$helperId] -ne $PilotProcess.Id) {
            throw 'Cancellation helper did not belong to the exact pilot process.'
        }
        $helper = [Diagnostics.Process]::GetProcessById($helperId)
        $processes.Add($helper)
        $null = $helper.Handle

        $pilotStart = $PilotProcess.StartTime.ToUniversalTime()
        $helperStart = $helper.StartTime.ToUniversalTime()
        $gitStart = $git.StartTime.ToUniversalTime()
        $childStart = $child.StartTime.ToUniversalTime()
        if ($PilotProcess.HasExited -or $helper.HasExited -or $git.HasExited -or $child.HasExited -or
            $helper.Path -ine $PinnedPowerShell -or $helperStart -lt $pilotStart -or
            $helperStart -gt $gitStart -or $gitStart -gt $childStart) {
            throw 'Cancellation process chain did not match the pinned helper and launch window.'
        }
        [pscustomobject]@{
            PilotPid = $PilotProcess.Id
            HelperPid = $helper.Id
            Handles = @($git, $child, $helper)
            Identities = @(
                [pscustomobject]@{ Role = 'git'; Pid = $git.Id; StartUtcTicks = $gitStart.Ticks; Image = $git.Path; ParentPid = $helper.Id }
                [pscustomobject]@{ Role = 'git-child'; Pid = $child.Id; StartUtcTicks = $childStart.Ticks; Image = $child.Path; ParentPid = $git.Id }
                [pscustomobject]@{ Role = 'helper'; Pid = $helper.Id; StartUtcTicks = $helperStart.Ticks; Image = $helper.Path; ParentPid = $PilotProcess.Id }
            )
            # The inert child sleeps 35 seconds, so reject exits near natural completion.
            LatestSignalUtc = $childStart.AddSeconds(33)
        }
    } catch {
        foreach ($process in $processes) { $process.Dispose() }
        throw
    }
}

function Wait-NativeCancelTreeExit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Tree,
        [ValidateRange(1,15)][int]$TimeoutSeconds = 8
    )
    $clock = [Diagnostics.Stopwatch]::StartNew()
    try {
        do {
            $signals = @($Tree.Handles | ForEach-Object { $_.WaitForExit(0) })
            $allSignaled = @($signals | Where-Object { -not $_ }).Count -eq 0
            $earlyEnough = [DateTime]::UtcNow -lt $Tree.LatestSignalUtc
            if (-not $allSignaled -and $earlyEnough) { Start-Sleep -Milliseconds 25 }
        } until ($allSignaled -or -not $earlyEnough -or $clock.Elapsed.TotalSeconds -ge $TimeoutSeconds)
        [pscustomobject]@{
            AllExited = $allSignaled -and $earlyEnough
            ElapsedMs = $clock.ElapsedMilliseconds
            PilotPid = $Tree.PilotPid
            Processes = @(for ($index = 0; $index -lt $Tree.Handles.Count; $index++) {
                $observed = $Tree.Identities[$index]
                [pscustomobject]@{
                    Role = $observed.Role
                    Pid = $observed.Pid
                    ParentPid = $observed.ParentPid
                    Image = $observed.Image
                    StartUtcTicks = $observed.StartUtcTicks
                    Exited = $signals[$index]
                    ExitCode = if ($signals[$index]) { $Tree.Handles[$index].ExitCode } else { $null }
                }
            })
        }
    } finally {
        foreach ($process in $Tree.Handles) { $process.Dispose() }
    }
}
