#requires -Version 7.0
<#
.SYNOPSIS
Run one explicitly supplied executable and record local build evidence.
.PARAMETER ProjectPath
Literal working directory.
.PARAMETER Executable
Executable path or application name. For scripts or batch files, explicitly invoke their interpreter.
.PARAMETER ArgumentList
Exact process arguments. Values are not saved to result.json.
.PARAMETER ArtifactPath
Explicit output files to hash, relative to ProjectPath or absolute.
.PARAMETER TimeoutSeconds
Optional 1 to 86400 seconds for process exit and output capture, measured from successful start.
.NOTES
Exit codes: child exit code when nonzero; 0 verified success; 2 missing/unreadable artifacts; 124 timeout; 125 setup/start/evidence failure.
Captured child output can contain secrets. Logs stay local; review before sharing.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ProjectPath,[Parameter(Mandatory)][string]$Executable,[string[]]$ArgumentList=@(),[string[]]$ArtifactPath=@(),[ValidateRange(1,86400)][int]$TimeoutSeconds)
$ErrorActionPreference = 'Stop'
$runDirectory = Join-Path $PSScriptRoot ('runs\' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ') + '-' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $runDirectory
$result = [ordered]@{schemaVersion=1;startedUtc=[DateTime]::UtcNow.ToString('o');finishedUtc=$null;projectPath=$null;executable=$null;argumentCount=$ArgumentList.Count;processExitCode=$null;runnerExitCode=125;status='SetupFailed';error=$null;artifacts=@();runDirectory=$runDirectory}
$process = $null
$stdoutFile=$null
$stderrFile=$null
$processStarted=$false
$timedOut=$false
$bounded=$PSBoundParameters.ContainsKey('TimeoutSeconds')
$captureCancellation=$null
$stdoutPipe=$null
$stderrPipe=$null
$stdout=$null
$stderr=$null
if ($bounded) { $result.timeoutSeconds=$TimeoutSeconds }
try {
    $root = Get-Item -LiteralPath $ProjectPath
    if (-not $root.PSIsContainer) { throw 'ProjectPath must be a directory.' }
    $result.projectPath=$root.FullName
    if ([IO.Path]::IsPathRooted($Executable) -or $Executable.Contains('\') -or $Executable.Contains('/')) {
        $exePath = if ([IO.Path]::IsPathRooted($Executable)) { $Executable } else { Join-Path $root.FullName $Executable }
        $exe = Get-Item -LiteralPath $exePath
        if ($exe.PSIsContainer) { throw 'Executable must be a file.' }
        $resolvedExe=$exe.FullName
    } else {
        $exe=Get-Command $Executable -CommandType Application -ErrorAction Stop | Select-Object -First 1
        $resolvedExe=$exe.Source
    }
    if ([IO.Path]::GetExtension($resolvedExe) -in @('.bat','.cmd','.ps1')) { throw 'Invoke the script interpreter explicitly; scripts and batch files are not direct executables.' }
    $result.executable=$resolvedExe
    $process=[Diagnostics.Process]::new()
    $process.StartInfo=[Diagnostics.ProcessStartInfo]::new($resolvedExe)
    $process.StartInfo.WorkingDirectory=$root.FullName
    $process.StartInfo.UseShellExecute=$false
    $process.StartInfo.CreateNoWindow=$true
    $process.StartInfo.RedirectStandardOutput=$true
    $process.StartInfo.RedirectStandardError=$true
    foreach ($argument in $ArgumentList) { $process.StartInfo.ArgumentList.Add($argument) }
    $stdoutFile=[IO.File]::Create((Join-Path $runDirectory 'stdout.log'))
    $stderrFile=[IO.File]::Create((Join-Path $runDirectory 'stderr.log'))
    $result.status='StartFailed'
    $processStarted=$process.Start()
    if (-not $processStarted) { throw 'Child process did not start.' }
    if ($bounded) {
        $clock=[Diagnostics.Stopwatch]::StartNew()
        $deadlineMilliseconds=$TimeoutSeconds * 1000
        $captureCancellation=[Threading.CancellationTokenSource]::new()
    }
    $result.status='EvidenceFailed'
    $stdoutPipe=$process.StandardOutput.BaseStream
    $stderrPipe=$process.StandardError.BaseStream
    $captureToken=if ($bounded) { $captureCancellation.Token } else { [Threading.CancellationToken]::None }
    $stdout=$stdoutPipe.CopyToAsync($stdoutFile,81920,$captureToken)
    $stderr=$stderrPipe.CopyToAsync($stderrFile,81920,$captureToken)
    $captureFailed = $false
    while ($true) {
        $waitMilliseconds=100
        if ($bounded) { $waitMilliseconds=[Math]::Min(100,[Math]::Max(0,$deadlineMilliseconds-[int]$clock.ElapsedMilliseconds)) }
        if ($process.WaitForExit($waitMilliseconds)) { break }
        if ($bounded -and $clock.ElapsedMilliseconds -ge $deadlineMilliseconds) { $timedOut=$true; break }
        if ($stdout.IsFaulted -or $stderr.IsFaulted -or $stdout.IsCanceled -or $stderr.IsCanceled) {
            $captureFailed = $true
            break
        }
    }
    if ($captureFailed) { throw 'Output capture failed.' }
    if (-not $timedOut) {
        $result.processExitCode=$process.ExitCode
        if ($bounded) {
            $remaining=[Math]::Max(0,$deadlineMilliseconds-[int]$clock.ElapsedMilliseconds)
            $timedOut=-not [Threading.Tasks.Task]::WhenAll($stdout,$stderr).Wait($remaining)
        }
    }
    if ($timedOut) { throw [TimeoutException]::new('Process or output capture exceeded its deadline.') }
    $stdout.GetAwaiter().GetResult()
    $stderr.GetAwaiter().GetResult()
    $result.artifacts=@(foreach ($path in $ArtifactPath) {
        $fullPath=if ([IO.Path]::IsPathRooted($path)) {$path} else {Join-Path $root.FullName $path}
        try {
            $file=Get-Item -LiteralPath $fullPath
            if ($file.PSIsContainer) { throw 'Artifact must be a file.' }
            [pscustomobject]@{path=$file.FullName;status='Hashed';sizeBytes=$file.Length;sha256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash}
        } catch { [pscustomobject]@{path=[IO.Path]::GetFullPath($fullPath);status='MissingOrUnreadable';sizeBytes=$null;sha256=$null} }
    })
    $result.runnerExitCode=$process.ExitCode
    $result.status=if ($process.ExitCode -eq 0) {'Succeeded'} else {'CommandFailed'}
    if ($process.ExitCode -eq 0 -and @($result.artifacts | Where-Object status -ne 'Hashed').Count -gt 0) { $result.runnerExitCode=2; $result.status='ArtifactVerificationFailed' }
} catch {
    # Exception text may contain command arguments or other sensitive values; store a bounded classification.
    $result.error=$_.Exception.GetType().FullName
    if ($timedOut) {
        $result.status='TimedOut'
        $result.runnerExitCode=124
    } else { $result.runnerExitCode=125 }
    # Cancel future copy writes before closing owned pipes. A descendant can hold a pipe after its root exits.
    if ($captureCancellation) { try { $captureCancellation.Cancel() } catch {} }
    if ($processStarted) {
        try {
            if (-not $process.HasExited) {
                $process.Kill($true)
                $null=$process.WaitForExit(1000)
            }
            if ($timedOut -and $process.HasExited) { $result.processExitCode=$process.ExitCode }
        } catch { $result.cleanupError=$_.Exception.GetType().FullName }
    }
    if ($stdoutPipe) { try { $stdoutPipe.Dispose() } catch {} }
    if ($stderrPipe) { try { $stderrPipe.Dispose() } catch {} }
    $captures=@($stdout,$stderr | Where-Object { $null -ne $_ })
    if ($captures.Count -gt 0) { try { $null=[Threading.Tasks.Task]::WaitAll($captures,500) } catch {} }
} finally {
    if ($stdoutFile) { $stdoutFile.Dispose() }
    if ($stderrFile) { $stderrFile.Dispose() }
    if ($process) { $process.Dispose() }
    if ($captureCancellation) { $captureCancellation.Dispose() }
    $result.finishedUtc=[DateTime]::UtcNow.ToString('o')
    foreach ($name in @('stdout.log','stderr.log')) { $path=Join-Path $runDirectory $name; if (-not (Test-Path -LiteralPath $path)) { [IO.File]::WriteAllText($path,'') } }
    $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $runDirectory 'result.json') -Encoding utf8
}
[pscustomobject]$result
exit $result.runnerExitCode
