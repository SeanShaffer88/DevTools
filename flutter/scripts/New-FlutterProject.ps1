<#
.SYNOPSIS
    Creates a new Flutter project with this pack's defaults.

.DESCRIPTION
    Thin wrapper over `flutter create` - installs nothing itself.
    Defaults: org com.example, platforms windows + android.
    Refuses to run if flutter is missing or the target folder exists.
    After creation, copies the pack templates when they are present:
      templates/analysis_options.yaml -> <project>\analysis_options.yaml
      templates/gitignore-flutter     -> <project>\.gitignore
    then prints the next steps.

.EXAMPLE
    pwsh -File New-FlutterProject.ps1 -Name my_app
.EXAMPLE
    pwsh -File New-FlutterProject.ps1 -Name my_app -Org com.acme -Platforms windows,android,web -Empty
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z][a-z0-9_]*$')]
    [string]$Name,

    [string]$Org = 'com.example',

    [string[]]$Platforms = @('windows', 'android'),

    [switch]$Empty,

    [string]$Path = '.'
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Error "flutter is not on PATH. Run scripts/Test-FlutterToolchain.ps1 first - this script does not install Flutter."
    exit 2
}
if ($Name -cne $Name.ToLower()) {
    Write-Error "Project name must be lowercase_with_underscores (Dart package rule): '$Name'"
    exit 2
}

$target = Join-Path (Resolve-Path $Path) $Name
if (Test-Path $target) {
    Write-Error "Folder already exists: $target - refusing to overwrite."
    exit 1
}

$createArgs = @('create', '--org', $Org, '--platforms', ($Platforms -join ','), '--project-name', $Name)
if ($Empty) { $createArgs += '--empty' }
$createArgs += $Name

Push-Location (Resolve-Path $Path)
try {
    Write-Host "Running: flutter $($createArgs -join ' ')"
    & flutter @createArgs
    if ($LASTEXITCODE -ne 0) { Write-Error "flutter create failed with exit code $LASTEXITCODE"; exit $LASTEXITCODE }
} finally { Pop-Location }

# Pack templates (only when present in this pack checkout)
$packRoot = Split-Path -Parent $PSScriptRoot
$templates = Join-Path $packRoot 'templates'
$analysis = Join-Path $templates 'analysis_options.yaml'
if (Test-Path $analysis) {
    Copy-Item $analysis (Join-Path $target 'analysis_options.yaml') -Force
    Write-Host "Applied pack template: analysis_options.yaml"
}
$gitignore = Join-Path $templates 'gitignore-flutter'
if (Test-Path $gitignore) {
    Copy-Item $gitignore (Join-Path $target '.gitignore') -Force
    Write-Host "Applied pack template: .gitignore"
}

Write-Host @"

Project created: $target
Next steps:
  cd $target
  flutter pub get
  flutter run -d windows        # or: flutter run -d android / -d chrome
  pwsh -File "$PSScriptRoot\Invoke-FlutterBuild.ps1" -Target windows-release -ProjectPath $target
"@
