# Download the pinned fixtures into fixtures/ and verify their hashes:
# the ONNX Runtime NuGet package (SHA-512), plus the e2e model + vocab
# (SHA-256). Nothing fetched here is ever committed; fixtures/ is
# gitignored, and ONNX Runtime is a runtime component the DLL loads
# dynamically — the fetch exists for the e2e proof and as a known-good
# source for users.
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$pins = @{}
Get-Content pins.txt | Where-Object { $_ -match '=' -and $_ -notmatch '^#' } | ForEach-Object {
    $k, $v = $_ -split '=', 2; $pins[$k.Trim()] = $v.Trim()
}
New-Item -ItemType Directory -Force fixtures | Out-Null

function Fetch([string]$Url, [string]$File, [string]$Want, [string]$Algorithm = 'SHA256') {
    $path = Join-Path fixtures $File
    if (-not (Test-Path $path)) {
        Write-Host "downloading $Url"
        Invoke-WebRequest -Uri $Url -OutFile $path
    }
    $got = (Get-FileHash $path -Algorithm $Algorithm).Hash.ToLower()
    if ($got -ne $Want) {
        throw "$Algorithm MISMATCH for $File`n  pinned: $Want`n  actual: $got"
    }
    Write-Host "verified $File ($Algorithm $got)"
}

Fetch $pins['ORT_NUPKG_URL'] $pins['ORT_NUPKG_FILE'] $pins['ORT_NUPKG_SHA512'] 'SHA512'
Fetch $pins['TEST_MODEL_URL'] $pins['TEST_MODEL_NAME'] $pins['TEST_MODEL_SHA256']
Fetch $pins['TEST_VOCAB_URL'] $pins['TEST_VOCAB_NAME'] $pins['TEST_VOCAB_SHA256']

# Lay the runtime out as fixtures/ort/lib/onnxruntime.dll (the path the
# e2e test uses). A .nupkg is a zip archive; only the win-x64 native
# DLLs are taken from it.
Remove-Item -Recurse -Force fixtures/ort -ErrorAction SilentlyContinue
$lib = New-Item -ItemType Directory -Force fixtures/ort/lib
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead((Resolve-Path (Join-Path fixtures $pins['ORT_NUPKG_FILE'])).Path)
try {
    $native = @($zip.Entries | Where-Object { $_.FullName -like 'runtimes/win-x64/native/*.dll' })
    if ($native.Name -notcontains 'onnxruntime.dll') { throw 'onnxruntime.dll not found in the NuGet package' }
    foreach ($entry in $native) {
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $lib.FullName $entry.Name), $true)
    }
} finally { $zip.Dispose() }
Write-Host "runtime ready under fixtures/ort; model at fixtures/$($pins['TEST_MODEL_NAME']); vocab at fixtures/$($pins['TEST_VOCAB_NAME'])"
Write-Host "e2e: `$env:EK_ORT_LIB='fixtures/ort/lib/onnxruntime.dll'; `$env:EK_MODEL='fixtures/$($pins['TEST_MODEL_NAME'])'; `$env:EK_VOCAB='fixtures/$($pins['TEST_VOCAB_NAME'])'; cargo test --test e2e -- --ignored --nocapture"
