<#
.SYNOPSIS
    Maintenance helper for THIS Flutter pack: what to re-check, and
    (only with -Fetch) the current Flutter stable version.

.DESCRIPTION
    Default behavior makes NO network calls. It prints:
      * the Flutter releases manifest URL (the JSON that lists every
        stable/beta/dev release), and
      * the pub.dev API endpoint for every package named in this
        pack's reference/dependencies.md (falling back to the package
        list in tools/package-snapshot.json when the reference file
        is not found),
    so a maintainer can re-verify the pack's version snapshot by hand.

    With -Fetch, it additionally downloads the Flutter releases
    manifest, prints the CURRENT stable Flutter version, and compares
    it with the snapshot recorded in reference/versions.md. It writes
    nothing - updating the pack files stays a deliberate, reviewed
    edit.

.EXAMPLE
    pwsh -File Update-FlutterPack.ps1
.EXAMPLE
    pwsh -File Update-FlutterPack.ps1 -Fetch
#>
[CmdletBinding()]
param([switch]$Fetch)

$ErrorActionPreference = 'Stop'
$packRoot = Split-Path -Parent $PSScriptRoot

$releasesUrl = 'https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json'
Write-Host "Flutter releases manifest (Windows):"
Write-Host "  $releasesUrl"
Write-Host "  (macOS: releases_macos.json, Linux: releases_linux.json, same folder)"
Write-Host ""

# Packages to re-check: prefer reference/dependencies.md pub.dev links,
# fall back to tools/package-snapshot.json keys.
$packages = @()
$depsFile = Join-Path $packRoot 'reference\dependencies.md'
if (Test-Path $depsFile) {
    $text = Get-Content $depsFile -Raw
    $packages = [regex]::Matches($text, 'pub\.dev/packages/([a-z0-9_]+)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
}
if (-not $packages) {
    $snapFile = Join-Path $packRoot 'tools\package-snapshot.json'
    if (Test-Path $snapFile) {
        $snap = Get-Content $snapFile -Raw | ConvertFrom-Json
        $packages = $snap.packages.PSObject.Properties.Name | Sort-Object
    }
}
Write-Host "pub.dev API endpoints to re-check ($($packages.Count) packages):"
foreach ($p in $packages) { Write-Host "  https://pub.dev/api/packages/$p" }
Write-Host ""

# Snapshot recorded in the pack
$snapshotVersion = $null
$versionsFile = Join-Path $packRoot 'reference\versions.md'
if (Test-Path $versionsFile) {
    $m = [regex]::Match((Get-Content $versionsFile -Raw), 'Flutter\s+(\d+\.\d+\.\d+)')
    if ($m.Success) { $snapshotVersion = $m.Groups[1].Value }
}
if ($snapshotVersion) { Write-Host "Pack snapshot (reference/versions.md): Flutter $snapshotVersion" }
else { Write-Host "Pack snapshot: reference/versions.md not found or no Flutter version parsed." }

if (-not $Fetch) {
    Write-Host "`nNo network calls made. Re-run with -Fetch to download the releases manifest and compare the current stable."
    return
}

Write-Host "`nFetching $releasesUrl ..."
$manifest = Invoke-RestMethod -Uri $releasesUrl
$stableHash = $manifest.current_release.stable
$current = $manifest.releases | Where-Object { $_.hash -eq $stableHash } | Select-Object -First 1
if (-not $current) { Write-Error "Could not resolve the current stable release from the manifest."; exit 1 }
Write-Host "Current stable: Flutter $($current.version) (Dart $($current.dart_sdk_version), released $($current.release_date))"
if ($snapshotVersion) {
    if ($current.version -eq $snapshotVersion) {
        Write-Host "MATCH: the pack snapshot is the current stable."
    } else {
        Write-Host "STALE: pack snapshot is $snapshotVersion, current stable is $($current.version)." -ForegroundColor Yellow
        Write-Host "Update reference/versions.md, reference/dependencies.md and tools/package-snapshot.json, then run tools/build-ai-bundle.py."
    }
}
