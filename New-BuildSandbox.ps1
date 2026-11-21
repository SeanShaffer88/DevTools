#requires -Version 7.4
<#
.SYNOPSIS
Provisions and runs an ephemeral, isolated WSL2 build/test sandbox for untrusted (AI-generated) jobs.

.DESCRIPTION
Windows 11 Home has neither Windows Sandbox nor Hyper-V, so this uses WSL2 with a Linux guest.

  -BuildImage  Bake a golden image once. Imports a base Ubuntu rootfs into a temporary distro,
               installs GCC/Clang/mingw-w64 (C++), Python 3 + pytest and the .NET SDK (C#),
               hardens wsl.conf (no C:\ automount, no Windows interop), smoke-tests the
               toolchains and exports a tarball plus .sha256. Only this mode uses the network.
  -JobFolder   Run one job folder (job.json + src\). Imports a brand-new distro from the golden
               image, runs every step as an unprivileged user in fresh PID/mount/IPC/UTS/network
               namespaces with a read-only root, size-capped tmpfs workspace and no network,
               mounts DevToolsRoot READ-ONLY at /workspace/devtools, copies logs and results to
               Destination, then terminates and unregisters the distro (revert to clean image).
  -InboxRoot   Job-folder drop. Runs every <InboxRoot>\<job> folder containing a READY marker,
               writing results to <OutboxRoot>\<job>-<runId> followed by a DONE marker.

Nothing from a job executes on the host. Job definitions are validated before use.

.NOTES
WSL2 distros share one lightweight utility VM and kernel. This is strong process/filesystem
isolation, not the per-run hypervisor boundary of Hyper-V or Windows Sandbox.
Everything under DevToolsRoot is readable by job code and can reach ChatGPT through logs.
Exit codes: 0 pass, 2 job failure, 3 WSL/image unavailable, 125 setup error.

.EXAMPLE
./New-BuildSandbox.ps1 -BuildImage -BaseRootfs D:\images\ubuntu-24.04-base.tar -ImagePath D:\images\build-sandbox.tar
.EXAMPLE
./New-BuildSandbox.ps1 -JobFolder .\templates\build-sandbox-job -ImagePath D:\images\build-sandbox.tar -Destination D:\runs\sample-1
.EXAMPLE
./New-BuildSandbox.ps1 -InboxRoot D:\sandbox\inbox -OutboxRoot D:\sandbox\outbox -ImagePath D:\images\build-sandbox.tar
#>
[CmdletBinding(DefaultParameterSetName = 'Run')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Image')][switch]$BuildImage,
    [Parameter(Mandatory, ParameterSetName = 'Image')][string]$BaseRootfs,
    [Parameter(ParameterSetName = 'Image')][ValidatePattern('^dotnet-sdk-[0-9]+\.[0-9]+$')][string]$DotnetPackage = 'dotnet-sdk-8.0',

    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$JobFolder,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$Destination,

    [Parameter(Mandatory, ParameterSetName = 'Inbox')][string]$InboxRoot,
    [Parameter(Mandatory, ParameterSetName = 'Inbox')][string]$OutboxRoot,

    [Parameter(Mandatory)][string]$ImagePath,

    [Parameter(ParameterSetName = 'Run')][Parameter(ParameterSetName = 'Inbox')][string]$DevToolsRoot = $PSScriptRoot,
    [Parameter(ParameterSetName = 'Run')][Parameter(ParameterSetName = 'Inbox')][switch]$NoDevTools,
    [Parameter(ParameterSetName = 'Run')][Parameter(ParameterSetName = 'Inbox')][ValidateRange(256, 65536)][int]$WorkspaceSizeMB = 4096,
    [Parameter(ParameterSetName = 'Run')][Parameter(ParameterSetName = 'Inbox')][ValidateRange(16, 16384)][int]$ResultsSizeMB = 1024,
    [Parameter(ParameterSetName = 'Run')][Parameter(ParameterSetName = 'Inbox')][switch]$AllowStepNetwork,
    [Parameter(ParameterSetName = 'Run')][switch]$ValidateOnly,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

$SandboxLib = Join-Path $PSScriptRoot 'lib/build-sandbox'
$InstanceRoot = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'BuildSandbox\instances'
$DistroPrefix = 'BuildSandbox-'
$Limits = @{ MaxSteps = 64; MaxArgs = 256; MaxArgLength = 8192; MinJobSeconds = 30; MaxJobSeconds = 14400
             MaxSrcFiles = 100000; MaxSrcBytes = 2GB; MaxJobJsonBytes = 1MB }
$script:ExitCode = 125

class SandboxUnavailableException : Exception { SandboxUnavailableException([string]$m) : base($m) {} }

#region helpers
function New-RunId { '{0:yyyyMMdd-HHmmss}-{1}' -f [datetime]::UtcNow, [Guid]::NewGuid().ToString('N').Substring(0, 6) }

function Write-RunLog([string]$Path, [string]$Message) {
    if ($Path) { Add-Content -LiteralPath $Path -Value ("[{0:o}] {1}" -f [datetime]::UtcNow, $Message) -Encoding utf8 }
    Write-Verbose $Message
}

function Assert-NewPath([string]$Path, [string]$Label) {
    $full = [IO.Path]::GetFullPath($Path)
    if (Test-Path -LiteralPath $full) { throw "$Label must not already exist: $full" }
    $parent = Split-Path $full -Parent
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { throw "$Label parent directory does not exist: $parent" }
    $full
}

function Get-ExistingDirectory([string]$Path, [string]$Label) {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if (-not $item -or -not $item.PSIsContainer) { throw "$Label is not an existing directory: $Path" }
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "$Label must not be a symlink or junction: $Path" }
    $item.FullName.TrimEnd('\')
}

function Invoke-Wsl {
    param([string[]]$Arguments, [int]$TimeoutSeconds = 600, [string]$StdoutPath, [string]$StderrPath)
    $psi = [Diagnostics.ProcessStartInfo]::new('wsl.exe')
    foreach ($a in $Arguments) { $psi.ArgumentList.Add($a) }
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [Text.Encoding]::UTF8
    $psi.Environment['WSL_UTF8'] = '1'
    $process = [Diagnostics.Process]::Start($psi)
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    $exited = $process.WaitForExit($TimeoutSeconds * 1000)
    if (-not $exited) { try { $process.Kill($true) } catch { }; $process.WaitForExit() }
    $out = $stdout.GetAwaiter().GetResult(); $err = $stderr.GetAwaiter().GetResult()
    if ($StdoutPath) { [IO.File]::AppendAllText($StdoutPath, $out) }
    if ($StderrPath) { [IO.File]::AppendAllText($StderrPath, $err) }
    [pscustomobject]@{ ExitCode = $process.ExitCode; TimedOut = -not $exited; Stdout = $out; Stderr = $err }
}

function Assert-WslOk($Result, [string]$What) {
    if ($Result.TimedOut) { throw "$What timed out." }
    if ($Result.ExitCode -ne 0) {
        $detail = (($Result.Stderr + "`n" + $Result.Stdout) -replace "`0", '').Trim()
        if ($detail.Length -gt 2000) { $detail = $detail.Substring(0, 2000) + '...' }
        throw "$What failed (exit $($Result.ExitCode)): $detail"
    }
}

function Assert-WslReady {
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { throw [SandboxUnavailableException]::new('wsl.exe not found; install WSL2 first.') }
    $status = Invoke-Wsl @('--status') 60
    if ($status.ExitCode -ne 0) { throw [SandboxUnavailableException]::new("WSL is not ready: $(($status.Stderr + $status.Stdout).Trim())") }
}

function Get-VerifiedImage([string]$Path) {
    $item = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $item -or $item.PSIsContainer) { throw [SandboxUnavailableException]::new("Golden image not found: $Path (build it with -BuildImage).") }
    $sidecar = "$($item.FullName).sha256"
    $check = 'NoSidecar'
    if (Test-Path -LiteralPath $sidecar) {
        $expected = (Get-Content -LiteralPath $sidecar -Raw).Trim()
        $actual = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
        if ($expected -ne $actual) { throw "Golden image hash mismatch; refusing to use a modified image ($($item.FullName))." }
        $check = 'Sha256Verified'
    }
    [pscustomobject]@{ Path = $item.FullName; Integrity = $check }
}

# Files cross the host/guest boundary only as tar streams over wsl.exe stdin/stdout. The hardened
# image disables interop, which also removes the \\wsl.localhost share, and that is intended.
function Invoke-WslStream {
    param([string[]]$Arguments, [int]$TimeoutSeconds = 600, [string]$InputPath, [string]$OutputPath)
    $psi = [Diagnostics.ProcessStartInfo]::new('wsl.exe')
    foreach ($a in $Arguments) { $psi.ArgumentList.Add($a) }
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardError = $true
    $psi.StandardErrorEncoding = [Text.Encoding]::UTF8
    $psi.RedirectStandardInput = [bool]$InputPath
    $psi.RedirectStandardOutput = [bool]$OutputPath
    $psi.Environment['WSL_UTF8'] = '1'
    $process = [Diagnostics.Process]::Start($psi)
    $stderr = $process.StandardError.ReadToEndAsync()
    $outFile = $null; $copyOut = $null
    if ($OutputPath) { $outFile = [IO.File]::Create($OutputPath); $copyOut = $process.StandardOutput.BaseStream.CopyToAsync($outFile) }
    if ($InputPath) {
        $inFile = [IO.File]::OpenRead($InputPath)
        try { $inFile.CopyTo($process.StandardInput.BaseStream) } catch [IO.IOException] { } finally { $inFile.Dispose(); $process.StandardInput.Close() }
    }
    $exited = $process.WaitForExit($TimeoutSeconds * 1000)
    if (-not $exited) { try { $process.Kill($true) } catch { }; $process.WaitForExit() }
    if ($copyOut) { try { $copyOut.Wait() } catch { }; $outFile.Dispose() }
    [pscustomobject]@{ ExitCode = $process.ExitCode; TimedOut = -not $exited; Stdout = ''; Stderr = $stderr.GetAwaiter().GetResult() }
}

function New-InputTar([string]$TarPath, [Collections.IDictionary]$TextFiles, [string]$SourceDir) {
    $stream = [IO.File]::Create($TarPath)
    try {
        $writer = [Formats.Tar.TarWriter]::new($stream, [Formats.Tar.TarEntryFormat]::Pax, $false)
        try {
            foreach ($name in $TextFiles.Keys) {
                # Guest scripts must have LF line endings regardless of how the host checkout stores them.
                $bytes = [Text.UTF8Encoding]::new($false).GetBytes(($TextFiles[$name] -replace "`r`n", "`n"))
                $entry = [Formats.Tar.PaxTarEntry]::new([Formats.Tar.TarEntryType]::RegularFile, $name)
                $entry.DataStream = [IO.MemoryStream]::new($bytes)
                $writer.WriteEntry($entry)
            }
            if ($SourceDir) {
                $writer.WriteEntry($SourceDir, 'src')
                foreach ($item in Get-ChildItem -LiteralPath $SourceDir -Recurse -Force) {
                    $relative = [IO.Path]::GetRelativePath($SourceDir, $item.FullName).Replace('\', '/')
                    $writer.WriteEntry($item.FullName, "src/$relative")
                }
            }
        } finally { $writer.Dispose() }
    } finally { $stream.Dispose() }
}

function Expand-ResultsTar([string]$TarPath, [string]$DestinationPath, [long]$MaxBytes) {
    # Untrusted archive: only regular files and directories, only inside DestinationPath.
    $root = [IO.Path]::GetFullPath($DestinationPath).TrimEnd('\') + '\'
    $skipped = [Collections.Generic.List[string]]::new()
    $total = 0L
    $stream = [IO.File]::OpenRead($TarPath)
    $reader = [Formats.Tar.TarReader]::new($stream)
    try {
        while ($null -ne ($entry = $reader.GetNextEntry())) {
            $name = $entry.Name.Replace('\', '/')
            while ($name.StartsWith('./')) { $name = $name.Substring(2) }
            $name = $name.TrimEnd('/')
            if (-not $name -or $name -eq '.') { continue }
            if ($name.StartsWith('/') -or $name -match '(^|/)\.\.(/|$)' -or $name -match '[:\x00-\x1f]') { $skipped.Add("$name (unsafe path)"); continue }
            $target = [IO.Path]::GetFullPath((Join-Path $DestinationPath $name))
            if (-not $target.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) { $skipped.Add("$name (outside destination)"); continue }
            try {
                if ($entry.EntryType -eq [Formats.Tar.TarEntryType]::Directory) {
                    $null = [IO.Directory]::CreateDirectory($target)
                } elseif ($entry.EntryType -in [Formats.Tar.TarEntryType]::RegularFile, [Formats.Tar.TarEntryType]::V7RegularFile) {
                    $total += $entry.Length
                    if ($total -gt $MaxBytes) { throw "Guest results exceed $MaxBytes bytes; extraction stopped." }
                    $null = [IO.Directory]::CreateDirectory((Split-Path $target -Parent))
                    $entry.ExtractToFile($target, $true)
                } else {
                    $skipped.Add("$name ($($entry.EntryType))")
                }
            } catch [IO.IOException], [ArgumentException], [NotSupportedException] {
                $skipped.Add("$name ($($_.Exception.Message))")
            }
        }
    } finally { $reader.Dispose(); $stream.Dispose() }
    $skipped.ToArray()
}

function Remove-SandboxDistro([string]$Distro, [string]$InstanceDir) {
    if (-not $Distro.StartsWith($DistroPrefix, [StringComparison]::Ordinal)) { throw "Refusing to unregister non-sandbox distro '$Distro'." }
    $null = Invoke-Wsl @('--terminate', $Distro) 120
    $listed = (Invoke-Wsl @('--list', '--quiet') 60).Stdout -split "`r?`n" | ForEach-Object { ($_ -replace "`0", '').Trim() }
    $state = 'NotRegistered'
    if ($listed -contains $Distro) {
        $r = Invoke-Wsl @('--unregister', $Distro) 300
        $state = if ($r.ExitCode -eq 0) { 'Unregistered' } else { "UnregisterFailed: $(($r.Stderr + $r.Stdout).Trim())" }
    }
    $root = [IO.Path]::GetFullPath($InstanceRoot) + '\'
    if ($InstanceDir -and [IO.Path]::GetFullPath($InstanceDir).StartsWith($root, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $InstanceDir)) {
        Remove-Item -LiteralPath $InstanceDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    $state
}
#endregion

#region job validation
function Test-IntegerValue($Value, [long]$Min, [long]$Max) {
    ($Value -is [int] -or $Value -is [long]) -and $Value -ge $Min -and $Value -le $Max
}

function Read-JobDefinition([string]$Path) {
    $file = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $file -or $file.PSIsContainer) { throw "job.json not found: $Path" }
    if ($file.Length -gt $Limits.MaxJobJsonBytes) { throw 'job.json exceeds 1 MB.' }
    $job = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json -AsHashtable -Depth 16
    if ($job -isnot [Collections.IDictionary]) { throw 'job.json must contain a JSON object.' }
    foreach ($key in $job.Keys) {
        if ($key -notin 'schemaVersion', 'description', 'timeoutSeconds', 'continueOnFailure', 'steps') { throw "Unknown job field '$key'." }
    }
    if ($job['schemaVersion'] -ne 1) { throw 'schemaVersion must be 1.' }
    if (-not (Test-IntegerValue $job['timeoutSeconds'] $Limits.MinJobSeconds $Limits.MaxJobSeconds)) { throw "timeoutSeconds must be $($Limits.MinJobSeconds)..$($Limits.MaxJobSeconds)." }
    if ($job.Contains('continueOnFailure') -and $job['continueOnFailure'] -isnot [bool]) { throw 'continueOnFailure must be true or false.' }
    if ($job.Contains('description') -and ($job['description'] -isnot [string] -or $job['description'].Length -gt 2000)) { throw 'description must be a string of at most 2000 characters.' }
    $steps = $job['steps']
    if ($steps -isnot [Collections.IList] -or $steps.Count -lt 1 -or $steps.Count -gt $Limits.MaxSteps) { throw "steps must be an array of 1..$($Limits.MaxSteps) steps." }
    $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($step in $steps) {
        if ($step -isnot [Collections.IDictionary]) { throw 'Each step must be an object.' }
        foreach ($key in $step.Keys) {
            if ($key -notin 'name', 'description', 'executable', 'arguments', 'workingDirectory', 'timeoutSeconds', 'expectedExitCodes') { throw "Unknown step field '$key'." }
        }
        $name = $step['name']
        if ($name -isnot [string] -or $name -notmatch '^[A-Za-z0-9_.-]{1,64}$' -or -not $names.Add($name)) { throw "Step names must be unique and match [A-Za-z0-9_.-]{1,64} ('$name')." }
        $exe = $step['executable']
        if ($exe -isnot [string] -or $exe.Length -lt 1 -or $exe.Length -gt 4096 -or $exe -match '[\x00-\x1f]') { throw "Step '$name': executable must be a non-empty single-line string." }
        if ($step.Contains('arguments')) {
            $arguments = $step['arguments']
            if ($arguments -isnot [Collections.IList] -or $arguments.Count -gt $Limits.MaxArgs) { throw "Step '$name': arguments must be an array of at most $($Limits.MaxArgs) strings." }
            foreach ($a in $arguments) { if ($a -isnot [string] -or $a.Length -gt $Limits.MaxArgLength -or $a.Contains([char]0)) { throw "Step '$name': every argument must be a string without NUL, at most $($Limits.MaxArgLength) characters." } }
        }
        if ($step.Contains('workingDirectory')) {
            $wd = $step['workingDirectory']
            if ($wd -isnot [string] -or $wd.Length -gt 1024 -or $wd -match '[\x00-\x1f]' -or $wd.StartsWith('/') -or $wd -match '(^|[\\/])\.\.([\\/]|$)') { throw "Step '$name': workingDirectory must be a relative path inside src without '..'." }
        }
        if (-not (Test-IntegerValue $step['timeoutSeconds'] 1 $job['timeoutSeconds'])) { throw "Step '$name': timeoutSeconds must be 1..job timeoutSeconds." }
        if ($step.Contains('expectedExitCodes')) {
            $codes = $step['expectedExitCodes']
            if ($codes -isnot [Collections.IList] -or $codes.Count -lt 1 -or $codes.Count -gt 16) { throw "Step '$name': expectedExitCodes must be an array of 1..16 integers." }
            foreach ($c in $codes) { if (-not (Test-IntegerValue $c 0 255)) { throw "Step '$name': exit codes must be 0..255." } }
        }
    }
    $job
}

function Test-SourceTree([string]$SourceRoot) {
    $files = 0; $bytes = 0L
    foreach ($item in Get-ChildItem -LiteralPath $SourceRoot -Recurse -Force) {
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "src must not contain symlinks or junctions: $($item.FullName)" }
        if (-not $item.PSIsContainer) {
            $files++; $bytes += $item.Length
            if ($files -gt $Limits.MaxSrcFiles -or $bytes -gt $Limits.MaxSrcBytes) { throw 'src exceeds the 100000-file / 2 GB limit.' }
        }
    }
    [pscustomobject]@{ Files = $files; Bytes = $bytes }
}
#endregion

#region modes
function Invoke-ImageBuild {
    Assert-WslReady
    $base = Get-Item -LiteralPath $BaseRootfs -ErrorAction SilentlyContinue
    if (-not $base -or $base.PSIsContainer) { throw "BaseRootfs not found: $BaseRootfs" }
    $imageFull = Assert-NewPath $ImagePath 'ImagePath'
    $distro = $DistroPrefix + 'image-' + (New-RunId)
    $instanceDir = Join-Path $InstanceRoot $distro
    $log = "$imageFull.provision.log"
    $build = [ordered]@{ image = $imageFull; sha256 = $null; distro = $distro; log = $log; cleanup = $null }
    try {
        $null = New-Item -ItemType Directory -Path $instanceDir -Force
        Write-RunLog $log "Importing base rootfs $($base.FullName) as $distro"
        Assert-WslOk (Invoke-Wsl @('--import', $distro, $instanceDir, $base.FullName, '--version', '2') 1800 $log $log) 'wsl --import (base)'
        $inputTar = Join-Path $instanceDir 'provision-input.tar'
        New-InputTar $inputTar @{ 'provision-image.sh' = [IO.File]::ReadAllText((Join-Path $SandboxLib 'provision-image.sh')) } $null
        Assert-WslOk (Invoke-WslStream @('-d', $distro, '-u', 'root', '--exec', '/bin/sh', '-c',
                'mkdir -p /tmp/build-sandbox && tar -x --no-same-owner -C /tmp/build-sandbox -f -') 300 -InputPath $inputTar) 'copy provisioning script'
        Write-RunLog $log 'Provisioning toolchains (network: apt)'
        Assert-WslOk (Invoke-Wsl @('-d', $distro, '-u', 'root', '--cd', '/', '--exec', '/bin/bash', '/tmp/build-sandbox/provision-image.sh',
                '--image-build-acknowledged', '--dotnet-package', $DotnetPackage) 5400 $log $log) 'image provisioning'
        $null = Invoke-Wsl @('--terminate', $distro) 120
        Write-RunLog $log "Exporting golden image to $imageFull"
        Assert-WslOk (Invoke-Wsl @('--export', $distro, $imageFull) 3600 $log $log) 'wsl --export'
        $build.sha256 = (Get-FileHash -LiteralPath $imageFull -Algorithm SHA256).Hash
        Set-Content -LiteralPath "$imageFull.sha256" -Value $build.sha256 -Encoding ascii
    } finally {
        $build.cleanup = Remove-SandboxDistro $distro $instanceDir
        Write-RunLog $log "Temporary distro cleanup: $($build.cleanup)"
    }
    $build
}

function Invoke-SandboxRun([string]$JobDir, [string]$DestinationPath, $Image) {
    $run = [ordered]@{ runId = New-RunId; jobFolder = $JobDir; destination = $DestinationPath; distro = $null; image = $Image.Path
                       imageIntegrity = $Image.Integrity; passed = $false; runnerExitCode = $null; timedOut = $false
                       source = $null; summary = $null; skippedResultEntries = @(); cleanup = 'NotImported'; error = $null }
    $distro = $DistroPrefix + $run.runId
    $run.distro = $distro
    $instanceDir = Join-Path $InstanceRoot $distro
    $hostLogs = Join-Path $DestinationPath 'host'
    $null = New-Item -ItemType Directory -Path $hostLogs -Force
    $log = Join-Path $hostLogs 'orchestrator.log'
    $imported = $false
    try {
        $job = Read-JobDefinition (Join-Path $JobDir 'job.json')
        $src = Get-ExistingDirectory (Join-Path $JobDir 'src') 'Job src folder'
        $run.source = Test-SourceTree $src
        if ($ValidateOnly) { $run.passed = $true; Write-RunLog $log 'Validation only; no distro created.'; return $run }

        Write-RunLog $log "Importing $distro from golden image ($($Image.Integrity))"
        $null = New-Item -ItemType Directory -Path $instanceDir -Force
        Assert-WslOk (Invoke-Wsl @('--import', $distro, $instanceDir, $Image.Path, '--version', '2') 1800) 'wsl --import'
        $imported = $true
        Write-RunLog $log "Copying job ($($run.source.Files) files) into the distro"
        $inputTar = Join-Path $instanceDir 'job-input.tar'
        New-InputTar $inputTar ([ordered]@{ 'runner.py' = [IO.File]::ReadAllText((Join-Path $SandboxLib 'runner.py'))
                                            'job.json' = ($job | ConvertTo-Json -Depth 16) }) $src
        Assert-WslOk (Invoke-WslStream @('-d', $distro, '-u', 'root', '--exec', '/bin/sh', '-c',
                'test -f /etc/build-sandbox-image.json && mkdir -p /sandbox/inbox && tar -x --no-same-owner --no-same-permissions -C /sandbox/inbox -f - && chmod -R u=rwX,go=rX /sandbox/inbox') 900 -InputPath $inputTar) 'copy job into distro'
        Remove-Item -LiteralPath $inputTar -Force

        $runnerArgs = @('-d', $distro, '-u', 'root', '--cd', '/', '--exec', '/usr/bin/python3', '-I', '/sandbox/inbox/runner.py',
                        '--inbox', '/sandbox/inbox', '--out', '/sandbox/out', '--workspace-mb', "$WorkspaceSizeMB",
                        '--results-mb', "$ResultsSizeMB", '--sandbox-acknowledged')
        if (-not $NoDevTools) { $runnerArgs += @('--devtools', $DevToolsRoot) }
        if ($AllowStepNetwork) { $runnerArgs += '--allow-network' }
        Write-RunLog $log "Running job (timeout $($job['timeoutSeconds']) s + 300 s grace)"
        $r = Invoke-Wsl $runnerArgs ($job['timeoutSeconds'] + 300) (Join-Path $hostLogs 'runner.stdout.log') (Join-Path $hostLogs 'runner.stderr.log')
        $run.runnerExitCode = $r.ExitCode
        $run.timedOut = $r.TimedOut
        if ($r.TimedOut) { Write-RunLog $log 'Runner exceeded its timeout; terminating distro.'; $null = Invoke-Wsl @('--terminate', $distro) 120 }

        $outputTar = Join-Path $instanceDir 'results.tar'
        $pull = Invoke-WslStream @('-d', $distro, '-u', 'root', '--exec', '/bin/sh', '-c',
                'test -d /sandbox/out && tar -c -C /sandbox/out -f - .') 900 -OutputPath $outputTar
        if ($pull.ExitCode -eq 0 -and -not $pull.TimedOut) {
            $run.skippedResultEntries = @(Expand-ResultsTar $outputTar $DestinationPath (($ResultsSizeMB + 64) * 1MB))
        } else {
            Write-RunLog $log "No results retrieved (exit $($pull.ExitCode)): $($pull.Stderr.Trim())"
        }
        $summaryPath = Join-Path $DestinationPath 'summary.json'
        if (Test-Path -LiteralPath $summaryPath) {
            $run.summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json -AsHashtable -Depth 16
            $run.passed = $r.ExitCode -eq 0 -and -not $r.TimedOut -and $run.summary['passed'] -eq $true
            if ($run.summary['error']) { $run.error = "Guest: $($run.summary['error'])" }
        } else {
            $run.error = 'Guest produced no summary.json; see host\runner.*.log.'
        }
    } catch {
        $run.error = $_.Exception.Message
        Write-RunLog $log "ERROR: $($run.error)"
    } finally {
        if ($imported -or (Test-Path -LiteralPath $instanceDir)) {
            $run.cleanup = Remove-SandboxDistro $distro $instanceDir
            Write-RunLog $log "Distro cleanup: $($run.cleanup)"
        }
        $run | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath (Join-Path $hostLogs 'run.json') -Encoding utf8NoBOM
    }
    $run
}

function Invoke-InboxSweep($Image) {
    $inbox = Get-ExistingDirectory $InboxRoot 'InboxRoot'
    $outbox = Get-ExistingDirectory $OutboxRoot 'OutboxRoot'
    if ($outbox.StartsWith($inbox + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'OutboxRoot must not be inside InboxRoot.' }
    $claimed = Join-Path $inbox '.claimed'
    $processed = Join-Path $inbox '.processed'
    $null = New-Item -ItemType Directory -Path $claimed, $processed -Force
    $runs = [Collections.Generic.List[object]]::new()
    $skipped = [Collections.Generic.List[string]]::new()
    foreach ($dir in Get-ChildItem -LiteralPath $inbox -Directory -Force | Where-Object Name -NotLike '.*' | Sort-Object Name) {
        if ($dir.Attributes -band [IO.FileAttributes]::ReparsePoint) { $skipped.Add("$($dir.Name): symlink/junction"); continue }
        if (-not (Test-Path -LiteralPath (Join-Path $dir.FullName 'READY') -PathType Leaf)) { continue }
        if ($dir.Name -notmatch '^[A-Za-z0-9_.-]{1,64}$') { $skipped.Add("$($dir.Name): invalid folder name"); continue }
        $stamp = New-RunId
        $claim = Join-Path $claimed "$($dir.Name)-$stamp"
        try { Move-Item -LiteralPath $dir.FullName -Destination $claim } catch { $skipped.Add("$($dir.Name): could not claim ($($_.Exception.Message))"); continue }
        $dest = Join-Path $outbox "$($dir.Name)-$stamp"
        $null = New-Item -ItemType Directory -Path $dest
        $run = Invoke-SandboxRun $claim $dest $Image
        Move-Item -LiteralPath $claim -Destination (Join-Path $processed (Split-Path $claim -Leaf))
        [ordered]@{ passed = $run.passed; error = $run.error; finishedUtc = [datetime]::UtcNow.ToString('o') } |
            ConvertTo-Json | Set-Content -LiteralPath (Join-Path $dest 'DONE') -Encoding utf8NoBOM
        $runs.Add($run)
    }
    [pscustomobject]@{ Runs = $runs.ToArray(); Skipped = $skipped.ToArray() }
}
#endregion

$result = [ordered]@{
    schemaVersion = 1; tool = 'New-BuildSandbox'; mode = $PSCmdlet.ParameterSetName; observedUtc = [datetime]::UtcNow.ToString('o')
    valid = $false; image = $null; runs = @(); skipped = @(); warnings = @(); error = $null
    limitations = @(
        'Guest is Linux (WSL2), not Windows; Windows-only APIs, MSVC, WPF/WinForms cannot be tested. mingw-w64 cross-builds .exe files but cannot run them.',
        'WSL2 distros share one utility VM and kernel: strong namespace isolation, not a per-run hypervisor boundary.',
        'Logs and artifacts are produced by untrusted code; review before trusting or executing anything returned.')
}
try {
    if ($PSCmdlet.ParameterSetName -ne 'Image') {
        if (-not $NoDevTools) {
            $DevToolsRoot = Get-ExistingDirectory $DevToolsRoot 'DevToolsRoot'
            $result.warnings += "DevTools ($DevToolsRoot) is mounted read-only; all of it is readable by job code and can reach ChatGPT through logs."
        }
        if ($AllowStepNetwork) { $result.warnings += 'Step network is ENABLED; job code can reach the internet and services on the host network.' }
    }
    switch ($PSCmdlet.ParameterSetName) {
        'Image' {
            $result.image = Invoke-ImageBuild
            $script:ExitCode = 0
        }
        'Run' {
            $jobDir = Get-ExistingDirectory $JobFolder 'JobFolder'
            $dest = Assert-NewPath $Destination 'Destination'
            $image = if ($ValidateOnly) { [pscustomobject]@{ Path = $ImagePath; Integrity = 'NotChecked' } } else { Assert-WslReady; Get-VerifiedImage $ImagePath }
            $null = New-Item -ItemType Directory -Path $dest
            $run = Invoke-SandboxRun $jobDir $dest $image
            $result.image = $image.Path
            $result.runs = @($run)
            $script:ExitCode = if ($run.passed) { 0 } elseif ($run.summary) { 2 } else { 125 }
        }
        'Inbox' {
            Assert-WslReady
            $image = Get-VerifiedImage $ImagePath
            $sweep = Invoke-InboxSweep $image
            $result.image = $image.Path
            $result.runs = $sweep.Runs
            $result.skipped = $sweep.Skipped
            $script:ExitCode = if (@($sweep.Runs | Where-Object { -not $_.passed }).Count) { 2 } else { 0 }
        }
    }
    $result.valid = $true
} catch [SandboxUnavailableException] {
    $result.error = $_.Exception.Message
    $script:ExitCode = 3
} catch {
    $result.error = $_.Exception.Message
    $script:ExitCode = 125
}

if ($Json) { $result | ConvertTo-Json -Depth 16 } else { [pscustomobject]$result }
exit $script:ExitCode
