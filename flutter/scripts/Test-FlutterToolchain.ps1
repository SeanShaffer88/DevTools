<#
.SYNOPSIS
    Checks whether this machine is ready for Flutter development.

.DESCRIPTION
    Read-only check - installs NOTHING and changes NOTHING.
    Verifies flutter / dart on PATH (with versions), git, the Visual
    Studio C++ workload (Windows desktop builds, via vswhere when
    present), the Android SDK pieces (ANDROID_HOME, cmdline-tools,
    platform-tools), and Chrome (Flutter web). Prints a per-item
    PASS / MISSING table with the exact fix step for every miss, then
    runs `flutter doctor -v` if Flutter exists and summarizes it.

.EXAMPLE
    pwsh -File Test-FlutterToolchain.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$results = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param([string]$Item, [bool]$Ok, [string]$Detail, [string]$Fix)
    $results.Add([pscustomobject]@{
        Item   = $Item
        Status = if ($Ok) { 'PASS' } else { 'MISSING' }
        Detail = $Detail
        Fix    = if ($Ok) { '' } else { $Fix }
    })
}

function Get-ToolVersion {
    param([string]$Name, [string]$VersionArg = '--version')
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $cmd) { return $null }
    try {
        $out = & $Name $VersionArg 2>&1 | Select-Object -First 3
        return ($out -join ' ').Trim()
    } catch { return $cmd.Source }
}

# --- Flutter / Dart -------------------------------------------------------
$flutter = Get-ToolVersion 'flutter'
if ($flutter) {
    $first = (& flutter --version 2>&1 | Select-Object -First 1)
    Add-Check 'Flutter' $true "$first" ''
} else {
    Add-Check 'Flutter' $false 'not on PATH' 'Install Flutter (manual download): https://docs.flutter.dev/get-started/install - then add <flutter>\bin to PATH. This script does not install it.'
}
$dart = Get-ToolVersion 'dart'
Add-Check 'Dart' ([bool]$dart) $(if ($dart) { $dart } else { 'not on PATH' }) 'Dart ships with Flutter - a missing dart usually means the Flutter install or PATH is broken.'

# --- Git ------------------------------------------------------------------
$git = Get-ToolVersion 'git'
Add-Check 'Git' ([bool]$git) $(if ($git) { $git } else { 'not on PATH' }) 'Install Git for Windows: https://git-scm.com/download/win'

# --- Visual Studio C++ workload (Windows desktop) -------------------------
$vsOk = $false; $vsDetail = 'vswhere not found'
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (Test-Path $vswhere) {
    $found = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property displayName 2>$null
    if ($found) { $vsOk = $true; $vsDetail = "$found (C++ x64/x86 build tools)" }
    else { $vsDetail = 'Visual Studio present, C++ workload missing' }
}
Add-Check 'Visual Studio C++ workload' $vsOk $vsDetail 'Install Visual Studio 2022 with the "Desktop development with C++" workload: https://visualstudio.microsoft.com/downloads/'

# --- Android SDK ----------------------------------------------------------
$sdkRoot = $env:ANDROID_HOME
if (-not $sdkRoot) { $sdkRoot = $env:ANDROID_SDK_ROOT }
if (-not $sdkRoot) {
    $default = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
    if (Test-Path $default) { $sdkRoot = $default }
}
Add-Check 'Android SDK (ANDROID_HOME)' ([bool]($sdkRoot -and (Test-Path $sdkRoot))) $(if ($sdkRoot) { $sdkRoot } else { 'ANDROID_HOME not set, no default SDK folder' }) 'Install Android Studio (it brings the SDK) or set ANDROID_HOME to your SDK folder: https://developer.android.com/studio'
if ($sdkRoot -and (Test-Path $sdkRoot)) {
    $cmdTools = Test-Path (Join-Path $sdkRoot 'cmdline-tools\latest\bin\sdkmanager.bat')
    Add-Check 'Android cmdline-tools' $cmdTools $(if ($cmdTools) { 'cmdline-tools\latest present' } else { 'missing' }) 'In Android Studio: Settings > Android SDK > SDK Tools > check "Android SDK Command-line Tools (latest)".'
    $adb = Join-Path $sdkRoot 'platform-tools\adb.exe'
    Add-Check 'Android platform-tools (adb)' (Test-Path $adb) $(if (Test-Path $adb) { $adb } else { 'missing' }) 'In Android Studio SDK Manager > SDK Tools > check "Android SDK Platform-Tools".'
    $platforms = Join-Path $sdkRoot 'platforms'
    $hasPlatform = (Test-Path $platforms) -and ((Get-ChildItem $platforms -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0)
    Add-Check 'Android platforms' $hasPlatform $(if ($hasPlatform) { (Get-ChildItem $platforms).Name -join ', ' } else { 'no platforms folder / empty' }) 'In Android Studio SDK Manager > SDK Platforms > install the latest Android API level.'
}

# --- Chrome (Flutter web) ---------------------------------------------------
$chrome = $env:CHROME_EXECUTABLE
if (-not $chrome) {
    $candidates = @(
        (Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe')
    )
    $chrome = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}
Add-Check 'Chrome (web builds)' ([bool]$chrome) $(if ($chrome) { $chrome } else { 'not found' }) 'Install Chrome, or set CHROME_EXECUTABLE to any Chromium-based browser exe: https://www.google.com/chrome/'

# --- Report -----------------------------------------------------------------
$results | Format-Table Item, Status, Detail -AutoSize | Out-String -Width 250 | Write-Host
foreach ($r in $results | Where-Object Status -eq 'MISSING') {
    Write-Host "FIX [$($r.Item)]: $($r.Fix)" -ForegroundColor Yellow
}
$missing = ($results | Where-Object Status -eq 'MISSING').Count
Write-Host "`n$($results.Count) checks, $missing missing."

if (Get-Command flutter -ErrorAction SilentlyContinue) {
    Write-Host "`n--- flutter doctor -v (summary) ---"
    $doctor = & flutter doctor -v 2>&1
    $okCount = ($doctor | Select-String -SimpleMatch '[✓]').Count
    $badCount = ($doctor | Select-String -SimpleMatch '[✗]').Count
    $doctor | Select-String -Pattern '^\[|Flutter \(Channel|Android toolchain|Visual Studio|Chrome' | ForEach-Object { $_.Line } | Write-Host
    Write-Host "doctor summary: $okCount section(s) OK, $badCount with errors (run 'flutter doctor -v' for full detail)."
}
exit $(if ($missing -gt 0) { 1 } else { 0 })
