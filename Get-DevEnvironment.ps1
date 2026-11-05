#requires -Version 7.0
<#
.SYNOPSIS
Read-only inventory of local development tools; does not install or configure tools.
.PARAMETER Json
Emit a single JSON document instead of an object.
#>
[CmdletBinding()]
param([switch]$Json)
$ErrorActionPreference = 'Stop'
$specs = @(
    @('git.exe','--version'), @('cmake.exe','--version'), @('ninja.exe','--version'),
    @('dotnet.exe','--version'), @('java.exe','-version'), @('python.exe','--version'),
    @('node.exe','--version'), @('rustc.exe','--version'), @('cargo.exe','--version'),
    @('adb.exe',$null), @('gradle.bat',$null), @('lua.exe','-v'), @('luajit.exe','-v'),
    @('cl.exe',$null), @('clang.exe','--version'), @('msbuild.exe','-version'), @('pwsh.exe','--version')
)
$tools = foreach ($spec in $specs) {
    $command = Get-Command $spec[0] -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $entry = [ordered]@{ name=$spec[0]; path=$null; status='Unavailable'; version=$null; probeExitCode=$null }
    if ($command) {
        $entry.path = $command.Source
        $entry.status = 'Available'
        if ($spec[1]) {
            $process = [Diagnostics.Process]::new()
            try {
                $process.StartInfo = [Diagnostics.ProcessStartInfo]::new($command.Source)
                $process.StartInfo.UseShellExecute = $false
                $process.StartInfo.CreateNoWindow = $true
                $process.StartInfo.RedirectStandardOutput = $true
                $process.StartInfo.RedirectStandardError = $true
                $process.StartInfo.ArgumentList.Add($spec[1])
                $null = $process.Start()
                $stdout = $process.StandardOutput.ReadToEndAsync()
                $stderr = $process.StandardError.ReadToEndAsync()
                if (-not $process.WaitForExit(10000)) {
                    $process.Kill($true)
                    $process.WaitForExit()
                    $entry.status = 'ProbeTimedOut'
                } else {
                    $entry.probeExitCode = $process.ExitCode
                    $lines = ($stdout.GetAwaiter().GetResult() + "`n" + $stderr.GetAwaiter().GetResult()).Trim()
                    $entry.version = ($lines -split '\r?\n' | Select-Object -First 3) -join ' | '
                    if ($process.ExitCode -ne 0) { $entry.status = 'ProbeFailed' }
                }
            } catch { $entry.status = 'ProbeFailed' }
            finally { $process.Dispose() }
        }
    }
    [pscustomobject]$entry
}
$vswherePath = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$visualStudio = @()
if (Test-Path -LiteralPath $vswherePath -PathType Leaf) {
    $raw = & $vswherePath -all -products '*' -format json -utf8
    if ($LASTEXITCODE -eq 0) {
        $visualStudio = @($raw | ConvertFrom-Json | Select-Object installationPath,installationVersion,displayName)
    }
}
$sdkCandidates = @(
    $(if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }),
    $env:ANDROID_HOME, $env:ANDROID_SDK_ROOT
) | Where-Object { $_ } | Select-Object -Unique
$androidSdks = @($sdkCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Container } | ForEach-Object {
    [pscustomobject]@{ path=[IO.Path]::GetFullPath($_); directories=@(Get-ChildItem -LiteralPath $_ -Directory | Select-Object -ExpandProperty Name) }
})
$result = [pscustomobject]@{ schemaVersion=1; observedUtc=[DateTime]::UtcNow.ToString('o'); powerShellVersion=$PSVersionTable.PSVersion.ToString(); tools=@($tools); visualStudio=$visualStudio; androidSdks=$androidSdks }
if ($Json) { $result | ConvertTo-Json -Depth 8 } else { $result }
