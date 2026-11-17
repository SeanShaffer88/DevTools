#requires -Version 7.4
<#
.SYNOPSIS
Creates a build-sandbox job folder from a source tree (auto-detecting CMake, Python and .NET
projects) and optionally submits it to an inbox, runs it and waits for the result.

.DESCRIPTION
Generates job.json for New-BuildSandbox.ps1 from presets:
  cmake   CMakeLists.txt at the root: configure (Ninja), build, ctest.
  python  pyproject.toml / setup.py / setup.cfg / pytest.ini / tox.ini / test_*.py: pytest.
  dotnet  *.sln at the root (build + test), else every *.csproj (build; test projects also tested).
  auto    (default) every preset whose markers are present.

The source is copied into <job>\src without bin, obj, build, out, .git, .vs, node_modules,
__pycache__, .venv and similar folders. Symlinks/junctions are refused (the sandbox rejects them).

Destinations:
  -OutputPath  write the job folder there (must not exist).
  -InboxRoot   stage in <inbox>\.staging, then move to <inbox>\<Name> and write READY last,
               so a concurrent inbox sweep never sees a half-written job.
  -RunNow      after submitting, run one inbox sweep (needs -OutboxRoot and -ImagePath).
  -Wait        wait for <outbox>\<Name>-*\DONE (needs -OutboxRoot) and return the result.
  -WhatIfSteps only print the generated job; write nothing.

.EXAMPLE
./New-SandboxJob.ps1 -SourcePath C:\src\mylib -WhatIfSteps -OutputPath unused
.EXAMPLE
./New-SandboxJob.ps1 -SourcePath C:\src\mylib -InboxRoot D:\sandbox\inbox -OutboxRoot D:\sandbox\outbox -ImagePath $img -RunNow
#>
[CmdletBinding(DefaultParameterSetName = 'Output')]
param(
    [Parameter(Mandatory)][string]$SourcePath,
    [ValidateSet('auto', 'cmake', 'python', 'dotnet')][string[]]$Preset = @('auto'),
    [ValidatePattern('^[A-Za-z0-9_.-]{1,40}$')][string]$Name,
    [ValidateRange(30, 14400)][int]$TimeoutSeconds = 1800,
    [ValidateSet('Debug', 'Release')][string]$Configuration = 'Debug',
    [switch]$ContinueOnFailure,

    [Parameter(Mandatory, ParameterSetName = 'Output')][string]$OutputPath,
    [Parameter(Mandatory, ParameterSetName = 'Inbox')][string]$InboxRoot,
    [Parameter(ParameterSetName = 'Inbox')][string]$OutboxRoot,
    [Parameter(ParameterSetName = 'Inbox')][string]$ImagePath,
    [Parameter(ParameterSetName = 'Inbox')][switch]$RunNow,
    [Parameter(ParameterSetName = 'Inbox')][switch]$Wait,
    [Parameter(ParameterSetName = 'Inbox')][ValidateRange(1, 1440)][int]$WaitTimeoutMinutes = 60,

    [switch]$WhatIfSteps,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

$ExcludedDirs = @('bin', 'obj', 'build', 'out', '.git', '.vs', '.vscode', '.idea', 'node_modules', '__pycache__',
                  '.venv', 'venv', '.pytest_cache', '.mypy_cache', 'cmake-build-debug', 'cmake-build-release', 'TestResults')
$MaxFiles = 100000
$MaxBytes = 2GB

function New-Step([string]$StepName, [string]$Executable, [string[]]$Arguments, [int]$Timeout) {
    [ordered]@{ name = $StepName; executable = $Executable; arguments = @($Arguments); timeoutSeconds = [Math]::Min($Timeout, $TimeoutSeconds) }
}

function ConvertTo-SandboxPath([string]$Root, [string]$FullPath) {
    [IO.Path]::GetRelativePath($Root, $FullPath).Replace('\', '/')
}

function Get-SourceFiles([string]$Root) {
    # Bounded walk that skips excluded folders and refuses reparse points.
    $files = [Collections.Generic.List[IO.FileInfo]]::new()
    $bytes = 0L
    $stack = [Collections.Generic.Stack[IO.DirectoryInfo]]::new()
    $stack.Push([IO.DirectoryInfo]::new($Root))
    while ($stack.Count) {
        foreach ($item in $stack.Pop().EnumerateFileSystemInfos()) {
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Source contains a symlink/junction (not allowed in sandbox jobs): $($item.FullName)" }
            if ($item -is [IO.DirectoryInfo]) {
                if ($item.Name -notin $ExcludedDirs) { $stack.Push($item) }
            } else {
                $files.Add($item); $bytes += $item.Length
                if ($files.Count -gt $MaxFiles -or $bytes -gt $MaxBytes) { throw 'Source exceeds the sandbox limit of 100000 files / 2 GB (after exclusions).' }
            }
        }
    }
    , $files
}

function Get-DetectedPresets([string]$Root, [Collections.Generic.List[IO.FileInfo]]$Files) {
    $found = [Collections.Generic.List[string]]::new()
    if (Test-Path -LiteralPath (Join-Path $Root 'CMakeLists.txt')) { $found.Add('cmake') }
    $pyMarkers = 'pyproject.toml', 'setup.py', 'setup.cfg', 'pytest.ini', 'tox.ini'
    if (@($pyMarkers | Where-Object { Test-Path -LiteralPath (Join-Path $Root $_) }).Count -or
        @($Files | Where-Object { $_.Name -like 'test_*.py' -or $_.Name -like '*_test.py' }).Count) { $found.Add('python') }
    if (@($Files | Where-Object { $_.Extension -in '.sln', '.csproj' }).Count) { $found.Add('dotnet') }
    $found.ToArray()
}

function Get-PresetSteps([string]$PresetName, [string]$Root, [Collections.Generic.List[IO.FileInfo]]$Files) {
    switch ($PresetName) {
        'cmake' {
            New-Step 'cmake-configure' 'cmake' @('-S', '.', '-B', '%WORKSPACE%/build', '-G', 'Ninja', "-DCMAKE_BUILD_TYPE=$Configuration", '-DCMAKE_EXPORT_COMPILE_COMMANDS=ON') 300
            New-Step 'cmake-build' 'cmake' @('--build', '%WORKSPACE%/build', '--parallel') 1800
            New-Step 'ctest' 'ctest' @('--test-dir', '%WORKSPACE%/build', '--output-on-failure', '--no-tests=ignore') 1800
        }
        'python' {
            New-Step 'pytest' 'python3' @('-m', 'pytest', '-q', '-p', 'no:cacheprovider', '--junitxml=%ARTIFACTS%/pytest-junit.xml') 1800
        }
        'dotnet' {
            $rootSln = @(Get-ChildItem -LiteralPath $Root -Filter *.sln -File)
            if ($rootSln.Count -eq 1) {
                $sln = $rootSln[0].Name
                New-Step 'dotnet-build' 'dotnet' @('build', $sln, '-c', $Configuration, '-nologo') 1800
                New-Step 'dotnet-test' 'dotnet' @('test', $sln, '-c', $Configuration, '--no-build', '-nologo', '--logger', 'trx', '--results-directory', '%ARTIFACTS%/dotnet-test') 1800
            } else {
                foreach ($project in @($Files | Where-Object Extension -eq '.csproj' | Sort-Object FullName | Select-Object -First 16)) {
                    $rel = ConvertTo-SandboxPath $Root $project.FullName
                    $stem = $project.BaseName -replace '[^A-Za-z0-9_.-]', '_'
                    if ($stem.Length -gt 40) { $stem = $stem.Substring(0, 40) }
                    New-Step "build-$stem" 'dotnet' @('build', $rel, '-c', $Configuration, '-nologo') 1800
                    if ((Get-Content -LiteralPath $project.FullName -Raw) -match 'Microsoft\.NET\.Test\.Sdk|xunit|NUnit|MSTest') {
                        New-Step "test-$stem" 'dotnet' @('test', $rel, '-c', $Configuration, '--no-build', '-nologo', '--logger', 'trx', '--results-directory', '%ARTIFACTS%/dotnet-test') 1800
                    }
                }
            }
        }
    }
}

function Write-JobFolder([string]$Folder, [string]$Root, [Collections.Generic.List[IO.FileInfo]]$Files, $Job) {
    $src = Join-Path $Folder 'src'
    $null = New-Item -ItemType Directory -Path $src -Force
    foreach ($file in $Files) {
        $target = Join-Path $src ([IO.Path]::GetRelativePath($Root, $file.FullName))
        $null = [IO.Directory]::CreateDirectory((Split-Path $target -Parent))
        [IO.File]::Copy($file.FullName, $target, $false)
    }
    $Job | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $Folder 'job.json') -Encoding utf8NoBOM
}

$result = [ordered]@{ schemaVersion = 1; tool = 'New-SandboxJob'; valid = $false; name = $null; presets = @(); steps = 0
                      files = 0; jobFolder = $null; submitted = $false; outcome = $null; resultFolder = $null; job = $null; error = $null }
$exitCode = 125
try {
    $sourceItem = Get-Item -LiteralPath $SourcePath -Force
    if (-not $sourceItem.PSIsContainer) { throw "SourcePath must be a directory: $SourcePath" }
    $root = $sourceItem.FullName.TrimEnd('\')
    if (-not $Name) {
        $Name = ($sourceItem.Name -replace '[^A-Za-z0-9_.-]', '-').Trim('-', '.')
        if ($Name.Length -gt 40) { $Name = $Name.Substring(0, 40) }
        if (-not $Name) { $Name = 'job' }
    }
    $result.name = $Name

    $files = Get-SourceFiles $root
    $result.files = $files.Count
    $presets = @(if ($Preset -contains 'auto') { Get-DetectedPresets $root $files } else { $Preset | Select-Object -Unique })
    if (-not $presets.Count) { throw 'No CMake, Python or .NET project markers found; pass -Preset explicitly or write job.json by hand (templates/build-sandbox-job/JOB-FORMAT.md).' }
    $result.presets = $presets

    $steps = @(foreach ($p in $presets) { Get-PresetSteps $p $root $files })
    if (-not $steps.Count) { throw 'Presets produced no steps.' }
    if ($steps.Count -gt 64) { throw "Too many steps ($($steps.Count)); the sandbox allows 64." }
    $job = [ordered]@{ schemaVersion = 1; description = "Generated by New-SandboxJob from '$($sourceItem.Name)' ($($presets -join ', '))."
                       timeoutSeconds = $TimeoutSeconds; continueOnFailure = [bool]$ContinueOnFailure; steps = $steps }
    $result.steps = $steps.Count

    if ($WhatIfSteps) {
        $result.job = $job; $result.valid = $true; $exitCode = 0
    } elseif ($PSCmdlet.ParameterSetName -eq 'Output') {
        $folder = [IO.Path]::GetFullPath($OutputPath)
        if (Test-Path -LiteralPath $folder) { throw "OutputPath must not exist: $folder" }
        Write-JobFolder $folder $root $files $job
        $result.jobFolder = $folder; $result.valid = $true; $exitCode = 0
    } else {
        if (($RunNow -or $Wait) -and -not $OutboxRoot) { throw '-RunNow and -Wait need -OutboxRoot.' }
        if ($RunNow -and -not $ImagePath) { throw '-RunNow needs -ImagePath.' }
        $inbox = (Get-Item -LiteralPath $InboxRoot).FullName.TrimEnd('\')
        $final = Join-Path $inbox $Name
        if (Test-Path -LiteralPath $final) { throw "A job named '$Name' is already waiting in the inbox." }
        $staging = Join-Path $inbox ".staging\$Name-$([Guid]::NewGuid().ToString('N').Substring(0, 8))"
        Write-JobFolder $staging $root $files $job
        Move-Item -LiteralPath $staging -Destination $final
        [IO.File]::WriteAllText((Join-Path $final 'READY'), [datetime]::UtcNow.ToString('o'))
        $result.jobFolder = $final; $result.submitted = $true
        $submittedUtc = [datetime]::UtcNow.AddSeconds(-5)

        if ($RunNow) {
            $sweep = & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'New-BuildSandbox.ps1') -InboxRoot $inbox -OutboxRoot $OutboxRoot -ImagePath $ImagePath -Json | ConvertFrom-Json
            if (-not $sweep.valid) { throw "Inbox sweep failed: $($sweep.error)" }
        }
        if ($RunNow -or $Wait) {
            $done = $null
            $deadline = [datetime]::UtcNow.AddMinutes($WaitTimeoutMinutes)
            while (-not $done -and [datetime]::UtcNow -lt $deadline) {
                $done = Get-ChildItem -LiteralPath $OutboxRoot -Directory -Filter "$Name-*" -ErrorAction SilentlyContinue |
                    Where-Object { $_.CreationTimeUtc -ge $submittedUtc -and (Test-Path -LiteralPath (Join-Path $_.FullName 'DONE')) } |
                    Sort-Object CreationTimeUtc -Descending | Select-Object -First 1
                if (-not $done) { Start-Sleep -Seconds 5 }
            }
            if (-not $done) { throw "No result within $WaitTimeoutMinutes minutes. Is the inbox sweep scheduled (Register-SandboxInboxTask.ps1)?" }
            $result.resultFolder = $done.FullName
            $result.outcome = Get-Content -LiteralPath (Join-Path $done.FullName 'DONE') -Raw | ConvertFrom-Json
        }
        $result.valid = $true
        $exitCode = if ($result.outcome -and -not $result.outcome.passed) { 2 } else { 0 }
    }
} catch {
    $result.error = $_.Exception.Message
}

if ($Json) { $result | ConvertTo-Json -Depth 12 } else { [pscustomobject]$result }
exit $exitCode
