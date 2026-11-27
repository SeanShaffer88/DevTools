<#
.SYNOPSIS
    Builds a Flutter project for one target and reports the artifact.

.DESCRIPTION
    Runs the matching `flutter build` for the target, then reports the
    artifact path, its size, and its SHA256:
      windows-release  -> build\windows\x64\runner\Release (folder +
                          the app .exe hash; folder is NOT zipped)
      android-aab      -> build\app\outputs\bundle\release\app-release.aab
      android-apk-debug-> build\app\outputs\flutter-apk\app-debug.apk
      web              -> build\web (folder + main.dart.js hash)
    Fails clearly (nonzero exit, the flutter output left on screen) if
    the build fails or the expected artifact is not produced.

.EXAMPLE
    pwsh -File Invoke-FlutterBuild.ps1 -Target android-aab -ProjectPath C:\dev\my_app
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('windows-release', 'android-aab', 'android-apk-debug', 'web')]
    [string]$Target,

    [string]$ProjectPath = '.'
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Error "flutter is not on PATH. Run scripts/Test-FlutterToolchain.ps1 first."
    exit 2
}
$project = Resolve-Path $ProjectPath
if (-not (Test-Path (Join-Path $project 'pubspec.yaml'))) {
    Write-Error "$project has no pubspec.yaml - not a Flutter project folder."
    exit 2
}

$buildArgs = switch ($Target) {
    'windows-release'   { @('build', 'windows', '--release') }
    'android-aab'       { @('build', 'appbundle', '--release') }
    'android-apk-debug' { @('build', 'apk', '--debug') }
    'web'               { @('build', 'web', '--release') }
}

Push-Location $project
try {
    Write-Host "Running: flutter $($buildArgs -join ' ')  (in $project)"
    & flutter @buildArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Error "flutter build failed with exit code $LASTEXITCODE for target $Target."
        exit $LASTEXITCODE
    }
} finally { Pop-Location }

function Show-Artifact {
    param([string]$Label, [string]$FilePath)
    $item = Get-Item $FilePath
    $hash = (Get-FileHash $FilePath -Algorithm SHA256).Hash.ToLower()
    Write-Host "$Label : $($item.FullName)"
    Write-Host "Size  : $($item.Length) bytes"
    Write-Host "SHA256: $hash"
}

switch ($Target) {
    'windows-release' {
        $dir = Join-Path $project 'build\windows\x64\runner\Release'
        if (-not (Test-Path $dir)) {
            $found = Get-ChildItem (Join-Path $project 'build\windows') -Recurse -Filter '*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) { $dir = $found.DirectoryName } else { Write-Error "Build reported success but no Release folder/exe found under build\windows."; exit 1 }
        }
        $exe = Get-ChildItem $dir -Filter '*.exe' | Where-Object Name -NotMatch '.*test.*' | Select-Object -First 1
        Write-Host "Artifact folder: $dir"
        $total = (Get-ChildItem $dir -Recurse -File | Measure-Object Length -Sum).Sum
        Write-Host "Folder size    : $total bytes"
        if ($exe) { Show-Artifact 'App exe' $exe.FullName }
    }
    'android-aab' {
        $aab = Join-Path $project 'build\app\outputs\bundle\release\app-release.aab'
        if (-not (Test-Path $aab)) { Write-Error "Build reported success but $aab was not produced."; exit 1 }
        Show-Artifact 'AAB' $aab
    }
    'android-apk-debug' {
        $apk = Join-Path $project 'build\app\outputs\flutter-apk\app-debug.apk'
        if (-not (Test-Path $apk)) { Write-Error "Build reported success but $apk was not produced."; exit 1 }
        Show-Artifact 'APK (debug)' $apk
    }
    'web' {
        $dir = Join-Path $project 'build\web'
        if (-not (Test-Path $dir)) { Write-Error "Build reported success but $dir was not produced."; exit 1 }
        Write-Host "Artifact folder: $dir"
        $total = (Get-ChildItem $dir -Recurse -File | Measure-Object Length -Sum).Sum
        Write-Host "Folder size    : $total bytes"
        $main = Join-Path $dir 'main.dart.js'
        if (Test-Path $main) { Show-Artifact 'Web bundle' $main }
    }
}
