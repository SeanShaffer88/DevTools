#requires -Version 7.0
<#
.SYNOPSIS
Inspect bounded project metadata without running project commands or reading source contents.
.PARAMETER ProjectPath
Literal directory to inspect.
.PARAMETER MaxDepth
Directory depth to inspect, from 0 to 4; default 2.
.PARAMETER Json
Emit JSON instead of an object.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ProjectPath,[ValidateRange(0,4)][int]$MaxDepth=2,[switch]$Json)
$ErrorActionPreference = 'Stop'
$root = Get-Item -LiteralPath $ProjectPath
if (-not $root.PSIsContainer) { throw 'ProjectPath must be a directory.' }
if ($root.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'ProjectPath must not be a reparse point.' }
for ($parent=$root.Parent; $null -ne $parent; $parent=$parent.Parent) {
    if ($parent.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'ProjectPath must not have a reparse point ancestor.' }
}
$excluded = @('.git','.svn','node_modules','vendor','target','build','dist','bin','obj','.gradle','.idea','.vs','.venv','venv','__pycache__','runs')
$queue = [Collections.Generic.Queue[object]]::new()
$queue.Enqueue(@($root.FullName,0))
$markers = [Collections.Generic.List[object]]::new()
$instructions = [Collections.Generic.List[string]]::new()
$wrappers = [Collections.Generic.List[string]]::new()
$visited = 0
$limitReached = $false
while ($queue.Count -gt 0) {
    $current = $queue.Dequeue()
    foreach ($item in Get-ChildItem -LiteralPath $current[0] -Force) {
        $visited++
        if ($visited -gt 10000) { $limitReached=$true; break }
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
        if ($item.PSIsContainer) {
            if ($current[1] -lt $MaxDepth -and $item.Name -notin $excluded) { $queue.Enqueue(@($item.FullName,($current[1]+1))) }
            continue
        }
        $relative = [IO.Path]::GetRelativePath($root.FullName,$item.FullName)
        if ($item.Name -in @('AGENTS.md','CLAUDE.md','README.md','CONTRIBUTING.md')) { $instructions.Add($relative) }
        if ($item.Name -in @('gradlew','gradlew.bat','mvnw','mvnw.cmd')) { $wrappers.Add($relative) }
        $kind = switch -Wildcard ($item.Name) {
            'CMakeLists.txt' {'CMake'} 'CMakePresets.json' {'CMake'}
            '*.sln' {'.NET / Visual Studio'} '*.slnx' {'.NET / Visual Studio'} '*.csproj' {'.NET'} '*.vcxproj' {'Windows C++'}
            'Cargo.toml' {'Rust'} 'package.json' {'Node'}
            'build.gradle*' {'Gradle'} 'settings.gradle*' {'Gradle'} 'AndroidManifest.xml' {'Android'}
            '*.toc' {'WoW Addon'}
            default {$null}
        }
        if ($kind) { $markers.Add([pscustomobject]@{path=$relative;kind=$kind}) }
    }
    if ($limitReached) { break }
}
$gitInfo = $null
$gitProbe = [pscustomobject]@{status='NotAvailable';exitCode=$null}
$git = Get-Command git.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($git) {
    # A nonzero native exit is probe data, even when the caller enables native error handling.
    $PSNativeCommandUseErrorActionPreference = $false
    $probeOutput = @(& $git.Source --no-optional-locks -C $root.FullName rev-parse --is-inside-work-tree 2>&1)
    $gitProbe.exitCode = $LASTEXITCODE
    $gitProbe.status = 'ProbeFailed'
    if ($gitProbe.exitCode -eq 0) {
        $probeValue = @($probeOutput | Where-Object { $_ -is [string] })
        if ($probeValue.Count -eq 1 -and $probeValue[0] -ceq 'true') { $gitProbe.status = 'Available' }
        elseif ($probeValue.Count -eq 1 -and $probeValue[0] -ceq 'false') { $gitProbe.status = 'NotWorkTree' }
    } else {
        # Classify only Git's known English diagnostics. Leave other failures opaque.
        $probeErrors = @($probeOutput | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | ForEach-Object { [string]$_ })
        if ($probeErrors.Count -eq 1 -and $probeErrors[0] -ceq 'fatal: not a git repository (or any of the parent directories): .git') {
            $gitProbe.status = 'NotRepository'
        } elseif ($probeErrors.Count -eq 2 -and
            $probeErrors[0] -cmatch '\Afatal: not a git repository \(or any parent up to mount point [^\r\n]+\)\z' -and
            $probeErrors[1] -ceq 'Stopping at filesystem boundary (GIT_DISCOVERY_ACROSS_FILESYSTEM not set).') {
            $gitProbe.status = 'NotRepository'
        }
    }
    if ($gitProbe.status -eq 'Available') {
        $branch = & $git.Source --no-optional-locks -C $root.FullName symbolic-ref --quiet --short HEAD 2>$null
        if ($LASTEXITCODE -ne 0) { $branch='(detached)' }
        # Git status may execute configured clean filters; metadata inspection must not do that.
        $gitInfo = [pscustomobject]@{ branch=($branch -join ''); status='NotQueried'; statusReason='Git status can execute repository-configured filters.' }
    }
}
$result = [pscustomobject]@{schemaVersion=1;observedUtc=[DateTime]::UtcNow.ToString('o');projectPath=$root.FullName;maxDepth=$MaxDepth;entryLimit=10000;limitReached=$limitReached;markers=@($markers.ToArray());instructionFiles=@($instructions.ToArray());wrappers=@($wrappers.ToArray());git=$gitInfo;gitProbe=$gitProbe;buildPolicy='Provide an explicit executable and argument array to Invoke-DevBuild.ps1; no build command was executed.'}
if ($Json) { $result | ConvertTo-Json -Depth 8 } else { $result }
