[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$WorkRoot,
    [string]$AndroidSdkPath,
    [string]$SdkPlatform = 'android-34',
    [string]$SdkBuildTools = '36.0.0',
    [ValidateSet('website','userscript','userstyle','dependency','windows','android-app','godot-games','wow-addon','portableapps')]
    [string[]]$Targets = @('website','userscript','userstyle','dependency','windows','android-app','godot-games','wow-addon','portableapps')
)
$ErrorActionPreference = 'Stop'
$Targets = @($Targets | ForEach-Object { $_.ToLowerInvariant() })
if (($Targets -contains 'android-app' -or $Targets -contains 'godot-games') -and !$AndroidSdkPath) { throw 'Android targets require an explicit private licensed -AndroidSdkPath.' }
if ($PSVersionTable.PSVersion.Major -lt 7 -or !$IsWindows) { throw 'Windows and PowerShell 7 are required.' }
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$root = [IO.Path]::GetFullPath($WorkRoot)
$repoPrefix = $repo.TrimEnd('\') + '\'
if ($root.StartsWith($repoPrefix,[StringComparison]::OrdinalIgnoreCase) -or $repo.StartsWith($root.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Use a new private build root outside the repository.' }
& (Join-Path $PSScriptRoot 'isolation\Initialize-OfflineRoot.ps1') -Path $root | Out-Null
$acquisition = Join-Path $repo 'development\acquisitions'
$inventory = Get-Content -LiteralPath (Join-Path $acquisition 'inventory.json') -Raw | ConvertFrom-Json
$pythonArtifact = @($inventory.artifacts | Where-Object id -EQ 'python-embed-win-x64')
if ($pythonArtifact.Count -ne 1 -or $pythonArtifact[0].pieces.Count -ne 1) { throw 'Expected one pinned Python bootstrap archive.' }
$piece = $pythonArtifact[0].pieces[0]
$archivePath = [IO.Path]::GetFullPath((Join-Path $acquisition $piece.path))
if (!$archivePath.StartsWith($acquisition+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Bootstrap archive escapes repository acquisition folder.' }
if ((Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $pythonArtifact[0].sha256 -or (Get-Item -LiteralPath $archivePath).Length -ne $pythonArtifact[0].sizeBytes) { throw 'Saved Python bootstrap identity mismatch.' }
$bootstrap = Join-Path $root 'tools\python-bootstrap'
[IO.Directory]::CreateDirectory($bootstrap) | Out-Null
$zip = [IO.Compression.ZipFile]::OpenRead($archivePath)
try {
    $total = 0L
    if ($zip.Entries.Count -gt 512) { throw 'Bootstrap archive entry limit exceeded.' }
    foreach ($entry in $zip.Entries) {
        if ($entry.FullName.EndsWith('/')) { continue }
        if ($entry.FullName.Contains('\') -or $entry.FullName.Contains(':') -or $entry.FullName.Split('/') -contains '..' -or $entry.FullName.StartsWith('/')) { throw 'Unsafe bootstrap ZIP member.' }
        if (($entry.ExternalAttributes -shr 16 -band 0xF000) -eq 0xA000) { throw 'Linked bootstrap ZIP member refused.' }
        $total += $entry.Length
        if ($entry.Length -gt 64MB -or $total -gt 512MB) { throw 'Bootstrap ZIP expansion limit exceeded.' }
        $destination = [IO.Path]::GetFullPath((Join-Path $bootstrap $entry.FullName))
        if (!$destination.StartsWith($bootstrap+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Bootstrap ZIP path escape.' }
        [IO.Directory]::CreateDirectory((Split-Path -Parent $destination)) | Out-Null
        $entryStream = $entry.Open()
        try {
            $output = [IO.File]::Open($destination,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
            try { $entryStream.CopyTo($output) } finally { $output.Dispose() }
        } finally { $entryStream.Dispose() }
    }
} finally { $zip.Dispose() }
$python = Join-Path $bootstrap 'python.exe'
$prepareArgs = @((Join-Path $PSScriptRoot 'tools\prepare.py'),'--repository',$repo,'--root',$root,'--sdk-platform',$SdkPlatform,'--sdk-build-tools',$SdkBuildTools,'--targets',($Targets -join ','))
if ($AndroidSdkPath) { $prepareArgs += @('--android-sdk',$AndroidSdkPath) }
& $python @prepareArgs
if ($LASTEXITCODE -ne 0) { throw 'Saved-resource preparation failed; see the task-root extraction logs.' }
$tools = Get-Content -LiteralPath (Join-Path $root 'tool-paths.json') -Raw | ConvertFrom-Json -AsHashtable
$output = Join-Path $root 'outputs\build'
[IO.Directory]::CreateDirectory($output) | Out-Null
$config = @{ownedRoot=$root; sources=(Join-Path $root 'sources\samples'); output=$output; tools=$tools; targets=$Targets}
$configPath = Join-Path $root 'requests\build.json'
$config | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $configPath -Encoding utf8
$javaBin = if ($tools.ContainsKey('java')) { Split-Path -Parent $tools.java } else { $null }
$sampleHome = Join-Path $root 'home'
$environment = @{
    USERPROFILE=$sampleHome; HOME=$sampleHome; APPDATA=(Join-Path $sampleHome 'AppData\Roaming'); LOCALAPPDATA=(Join-Path $sampleHome 'AppData\Local')
    TEMP=(Join-Path $root 'temp'); TMP=(Join-Path $root 'temp'); TMPDIR=(Join-Path $root 'temp')
    PATH=(@((Join-Path $env:SystemRoot 'System32'),(Split-Path -Parent $tools.node)) -join ';')
    ZIG_GLOBAL_CACHE_DIR=(Join-Path $root 'cache\zig-global'); ZIG_LOCAL_CACHE_DIR=(Join-Path $root 'cache\zig-local')
}
if ($javaBin) { $environment.JAVA_HOME = Split-Path -Parent $javaBin; $environment.PATH += ';'+$javaBin }
if ($tools.ContainsKey('zig')) { $environment.PATH += ';'+(Split-Path -Parent $tools.zig) }
if ($tools.ContainsKey('androidSdk')) { $environment.ANDROID_SDK_ROOT=$tools.androidSdk; $environment.ANDROID_HOME=$tools.androidSdk }
[IO.Directory]::CreateDirectory($environment.ZIG_GLOBAL_CACHE_DIR) | Out-Null
[IO.Directory]::CreateDirectory($environment.ZIG_LOCAL_CACHE_DIR) | Out-Null
$request = @{ownedRoot=$root; executable=$tools.node; arguments=@('--preserve-symlinks-main','--preserve-symlinks',(Join-Path $root 'sources\samples\tools\build.mjs'),$configPath)
    workingDirectory=$output; readOnlyRoots=@((Join-Path $root 'tools'),(Join-Path $root 'sources'),(Join-Path $root 'requests'))
    writableRoots=@((Join-Path $root 'outputs'),$sampleHome,(Join-Path $root 'temp'),(Join-Path $root 'cache')); timeoutSeconds=1200
    environment=$environment; artifacts=@(); useDriveAlias=$true}
$requestPath = Join-Path $root 'requests\offline.json'
$resultPath = Join-Path $root 'results\offline.json'
$request | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath $requestPath -Encoding utf8
$pwsh = (Get-Process -Id $PID).Path
& (Join-Path $repo 'Invoke-DevBuild.ps1') -ProjectPath $output -Executable $pwsh -ArgumentList @('-NoProfile','-File',(Join-Path $PSScriptRoot 'isolation\Invoke-OfflineProcess.ps1'),'-Request',$requestPath,'-Result',$resultPath) -TimeoutSeconds 1300 | Out-Null
$buildExit = $LASTEXITCODE
$result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
if ($buildExit -ne 0 -or !$result.valid) { Write-Output "Build failed. Isolation receipt: $resultPath"; exit 2 }
$summaryPath = Join-Path $output 'build-results.json'
$summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
if ($summary.status -ne 'Passed') { throw 'Builder did not record a passing result.' }
@{status='Passed';isolationReceipt=$resultPath;buildReceipt=$summaryPath;targetCount=$summary.results.Count;artifacts=$summary.artifacts} | ConvertTo-Json -Depth 8
exit 0
