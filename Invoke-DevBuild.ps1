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
.NOTES
Exit codes: child exit code when nonzero; 0 verified success; 2 missing/unreadable artifacts; 125 setup/start/evidence failure.
Captured child output can contain secrets. Logs stay local; review before sharing.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ProjectPath,[Parameter(Mandatory)][string]$Executable,[string[]]$ArgumentList=@(),[string[]]$ArtifactPath=@())
$ErrorActionPreference = 'Stop'
$runDirectory = Join-Path $PSScriptRoot ('runs\' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ') + '-' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $runDirectory
$result = [ordered]@{schemaVersion=1;startedUtc=[DateTime]::UtcNow.ToString('o');finishedUtc=$null;projectPath=$null;executable=$null;argumentCount=$ArgumentList.Count;processExitCode=$null;runnerExitCode=125;status='SetupFailed';error=$null;artifacts=@();runDirectory=$runDirectory}
$process = $null
$stdoutFile=$null
$stderrFile=$null
$processStarted=$false
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
    $null=$process.Start()
    $processStarted=$true
    $result.status='EvidenceFailed'
    $stdout=$process.StandardOutput.BaseStream.CopyToAsync($stdoutFile)
    $stderr=$process.StandardError.BaseStream.CopyToAsync($stderrFile)
    while (-not $process.WaitForExit(100)) {
        if ($stdout.IsFaulted -or $stderr.IsFaulted -or $stdout.IsCanceled -or $stderr.IsCanceled) {
            $process.Kill($true)
            $process.WaitForExit()
            throw 'Output capture failed.'
        }
    }
    $result.processExitCode=$process.ExitCode
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
    if ($processStarted -and -not $process.HasExited) {
        $process.Kill($true)
        $process.WaitForExit()
    }
    # Exception text may contain command arguments or other sensitive values; store a bounded classification.
    $result.error=$_.Exception.GetType().FullName
    $result.runnerExitCode=125
} finally {
    if ($stdoutFile) { $stdoutFile.Dispose() }
    if ($stderrFile) { $stderrFile.Dispose() }
    if ($process) { $process.Dispose() }
    $result.finishedUtc=[DateTime]::UtcNow.ToString('o')
    foreach ($name in @('stdout.log','stderr.log')) { $path=Join-Path $runDirectory $name; if (-not (Test-Path -LiteralPath $path)) { [IO.File]::WriteAllText($path,'') } }
    $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $runDirectory 'result.json') -Encoding utf8
}
[pscustomobject]$result
exit $result.runnerExitCode
