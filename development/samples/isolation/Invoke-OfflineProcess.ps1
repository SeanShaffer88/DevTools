[CmdletBinding()]
param([Parameter(Mandatory)][string]$Request, [Parameter(Mandatory)][string]$Result)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (!$IsWindows -or ![Environment]::Is64BitProcess) { throw 'Requires 64-bit PowerShell 7 on Windows.' }

function Get-SafePath([string]$Value, [bool]$MustExist = $true) {
    if (!$Value -or ![IO.Path]::IsPathFullyQualified($Value) -or $Value.Contains([char]0)) { throw 'An absolute local path is required.' }
    $full = [IO.Path]::GetFullPath($Value)
    if ($full.StartsWith('\\')) { throw 'Network and device paths are refused.' }
    if ($full.Substring(2).Contains(':')) { throw 'Alternate streams are refused.' }
    $walk = $full
    while ($walk) {
        if (Test-Path -LiteralPath $walk) {
            if ((Get-Item -LiteralPath $walk -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Linked paths are refused.' }
        }
        $next = Split-Path -Parent $walk
        if ($next -eq $walk) { break }
        $walk = $next
    }
    if ($MustExist -and !(Test-Path -LiteralPath $full)) { throw "Required path missing: $full" }
    return $full
}
function Require-Owned([string]$Value) {
    $path = Get-SafePath $Value
    if ($path -ne $script:owned -and !$path.StartsWith($script:owned + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Path lies outside the disposable root.' }
    return $path
}
function Map-AliasPath([string]$Value) {
    if (!$script:driveAlias) { return $Value }
    if ($Value.Equals($script:owned,[StringComparison]::OrdinalIgnoreCase)) { return $script:driveAlias+'\' }
    foreach ($separator in @('\','/')) {
        $prefix=$script:owned+$separator
        if ($Value.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) { return $script:driveAlias+'\'+$Value.Substring($prefix.Length) }
    }
    return $Value
}
if ((Get-Item -LiteralPath $Request).Length -gt 1048576) { throw 'Request exceeds 1 MiB.' }
$config = Get-Content -LiteralPath $Request -Raw | ConvertFrom-Json -AsHashtable
if ($config -isnot [System.Collections.IDictionary]) { throw 'Request must be an object.' }
$owned = Get-SafePath $config.ownedRoot
$markerPath = Join-Path $owned '.devtools-offline-owned.json'
Get-SafePath $markerPath | Out-Null
$marker = Get-Content -LiteralPath $markerPath -Raw | ConvertFrom-Json -AsHashtable
if ($marker.schemaVersion -ne 1 -or $marker.purpose -ne 'DevTools disposable offline build root' -or $marker.root -ne $owned) { throw 'Invalid disposable-root ownership marker.' }
if (!(Test-Path -LiteralPath $owned -PathType Container)) { throw 'Owned root must be a directory.' }
$executable = Require-Owned $config.executable
$working = Require-Owned $config.workingDirectory
if (!(Test-Path -LiteralPath $executable -PathType Leaf) -or !(Test-Path -LiteralPath $working -PathType Container)) { throw 'Invalid executable or working directory.' }
$arguments = @()
if ($config.arguments -isnot [array] -or $config.arguments.Count -gt 512) { throw 'Arguments must be a bounded array.' }
foreach ($arg in $config.arguments) {
    if ($arg -isnot [string] -or $arg.Contains([char]0)) { throw 'Arguments must be strings without NUL.' }
    $arguments += $arg
}
if ($config.timeoutSeconds -isnot [long] -and $config.timeoutSeconds -isnot [int]) { throw 'Timeout must be an integer.' }
$timeout = [int]$config.timeoutSeconds
if ($timeout -lt 1 -or $timeout -gt 1800) { throw 'Timeout must be 1–1800 seconds.' }
$writeRoots = @()
foreach ($value in @($config.writableRoots)) {
    $path = Require-Owned $value
    if (!(Test-Path -LiteralPath $path -PathType Container)) { throw 'Writable root must be an existing directory.' }
    $writeRoots += $path
}
foreach ($value in @($config.readOnlyRoots)) { Require-Owned $value | Out-Null }
$resultPath = Get-SafePath $Result $false
if (Test-Path -LiteralPath $resultPath) { throw 'Result already exists.' }
$resultParent = Split-Path -Parent $resultPath
if (!(Test-Path -LiteralPath $resultParent -PathType Container)) { throw 'Result parent must exist.' }
$stdout = $resultPath + '.stdout.txt'
$stderr = $resultPath + '.stderr.txt'
if ((Test-Path -LiteralPath $stdout) -or (Test-Path -LiteralPath $stderr)) { throw 'Logs already exist.' }
$environment = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($name in @('SystemRoot', 'WINDIR', 'SystemDrive')) { $environment[$name] = [Environment]::GetEnvironmentVariable($name) }
if ($config.ContainsKey('environment')) {
    if ($config.environment -isnot [System.Collections.IDictionary]) { throw 'Environment must be an object.' }
    foreach ($name in $config.environment.Keys) {
        if ($config.environment[$name] -isnot [string]) { throw 'Environment values must be strings.' }
        $environment[$name] = $config.environment[$name]
    }
}
$lockPath = Get-SafePath (Join-Path $owned '.devtools-offline.lock') $false
try { $rootLock = [IO.File]::Open($lockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None) }
catch { throw 'Another offline operation holds this disposable root, or its lock cannot be opened.' }
try {
if (!('OfflineNative' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'OfflineNative.cs') }
$profile = 'DevTools.Offline.' + [guid]::NewGuid().ToString('N')
$sidText = $null
$driveAlias = $null
$aliasMutex = $null
$aliasMutexHeld = $false
$originalAcls = [Collections.Generic.List[object]]::new()
$record = [ordered]@{schemaVersion=1; profile=$profile; networkPolicy='AppContainer with zero capabilities'; executable=$executable; workingDirectory=$working; exitCode=$null; valid=$false; profileDeleted=$false; aclsRestored=$false; stdout=$stdout; stderr=$stderr; error=$null; artifacts=@()}
try {
    if ($config.ContainsKey('useDriveAlias')) {
        if ($config.useDriveAlias -isnot [bool]) { throw 'useDriveAlias must be boolean.' }
        if ($config.useDriveAlias) {
            # Serialize cooperating roots within this user's interactive session.
            $userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
            $aliasMutex=[Threading.Mutex]::new($false,('Local\DevTools.Offline.DriveAlias.'+$userSid))
            try { $aliasMutexHeld=$aliasMutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $aliasMutexHeld=$true }
            if (!$aliasMutexHeld) { throw 'Another offline operation owns the session drive-alias lease.' }
            $driveAlias=[OfflineNative]::CreateDriveAlias($owned)
            $record.driveAlias=$driveAlias+'\'
            $record.driveAliasRawTarget='\??\'+$owned
            $record.driveAliasRemoved=$false
            $environment['DEVTOOLS_DRIVE_ALIAS']=$driveAlias+'\'
            $environment['DEVTOOLS_PHYSICAL_ROOT']=$owned
        }
    }
    $sidText = [OfflineNative]::CreateProfile($profile)
    $sid = [Security.Principal.SecurityIdentifier]::new($sidText)
    $record.appContainerSid = $sidText
    $grantPaths = @($owned) + @($writeRoots | Select-Object -Unique)
    foreach ($path in $grantPaths) {
        if ($originalAcls | Where-Object path -EQ $path) { continue }
        $acl = Get-Acl -LiteralPath $path
        $originalAcls.Add(@{path=$path;sddl=$acl.Sddl})
        $rights = if ($writeRoots -contains $path) { [Security.AccessControl.FileSystemRights]::Modify } else { [Security.AccessControl.FileSystemRights]::ReadAndExecute }
        $rule = [Security.AccessControl.FileSystemAccessRule]::new($sid,$rights,([Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [Security.AccessControl.InheritanceFlags]::ObjectInherit),[Security.AccessControl.PropagationFlags]::None,[Security.AccessControl.AccessControlType]::Allow)
        $acl.AddAccessRule($rule)
        Set-Acl -LiteralPath $path -AclObject $acl
    }
    $runExecutable=Map-AliasPath $executable
    $runWorking=Map-AliasPath $working
    $runArguments=@($arguments|ForEach-Object {Map-AliasPath $_})
    if ($driveAlias) {
        foreach($name in @($environment.Keys)) {
            if($name -eq 'DEVTOOLS_PHYSICAL_ROOT' -or $name -eq 'DEVTOOLS_DRIVE_ALIAS'){continue}
            if($name -eq 'PATH') {$environment[$name]=(@($environment[$name].Split(';')|ForEach-Object {Map-AliasPath $_}) -join ';')}
            else {$environment[$name]=Map-AliasPath $environment[$name]}
        }
    }
    $run = [OfflineNative]::Run($runExecutable,[string[]]$runArguments,$runWorking,$environment,$sidText,$timeout,$stdout,$stderr)
    $record.exitCode = $run.ExitCode
    $record.isAppContainer = $run.IsAppContainer
    $record.capabilityCount = $run.CapabilityCount
    $record.processId = $run.ProcessId
    $record.timedOut = $run.TimedOut
    $record.outputLimit = $run.OutputLimit
    $record.descendantsTerminated = $run.DescendantsTerminated
    foreach ($artifact in @($config.artifacts)) {
        $path = Require-Owned $artifact
        if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw 'Expected artifact is not a regular file.' }
        $record.artifacts += @{path=$path;bytes=(Get-Item -LiteralPath $path).Length;sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()}
    }
    $record.valid = $run.ExitCode -eq 0 -and !$run.TimedOut -and !$run.OutputLimit
} catch {
    $record.error = $_.Exception.Message
} finally {
    $aclErrors = @()
    for ($i=$originalAcls.Count-1; $i -ge 0; $i--) {
        try {
            $saved = $originalAcls[$i]
            $restore = [Security.AccessControl.DirectorySecurity]::new()
            $restore.SetSecurityDescriptorSddlForm($saved.sddl)
            Set-Acl -LiteralPath $saved.path -AclObject $restore
        } catch { $aclErrors += $_.Exception.Message }
    }
    $record.aclsRestored = $aclErrors.Count -eq 0
    $record.aclCleanupErrors = $aclErrors
    if ($sidText) {
        try {
            $residual = @([OfflineNative]::FindSidEntries($owned,$sidText))
            $record.residualSidPaths = $residual
            $record.aclSidAbsentRecursively = $residual.Count -eq 0
            $record.aclsRestored = $record.aclsRestored -and $record.aclSidAbsentRecursively
        } catch {
            $record.aclsRestored = $false
            $record.aclSidAbsentRecursively = $false
            $record.aclCleanupErrors += $_.Exception.Message
        }
    }
    if ($sidText) {
        $hr = [OfflineNative]::DeleteAppContainerProfile($profile)
        $record.profileDeleted = $hr -eq 0
        $record.profileDeleteHResult = $hr
    }
    if ($driveAlias) {
        try { [OfflineNative]::RemoveDriveAlias($driveAlias,$owned);$record.driveAliasRemoved=$true }
        catch {$record.error='Drive alias cleanup failed: '+$_.Exception.Message;$record.valid=$false}
    }
    if ($aliasMutexHeld) { $aliasMutex.ReleaseMutex() }
    if ($aliasMutex) { $aliasMutex.Dispose() }
    $record.valid = $record.valid -and $record.aclsRestored -and $record.profileDeleted
    $json = $record | ConvertTo-Json -Depth 12
    $stream = [IO.File]::Open($resultPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
    try { $bytes=[Text.Encoding]::UTF8.GetBytes($json); $stream.Write($bytes); $stream.Flush($true) } finally { $stream.Dispose() }
}
} finally { $rootLock.Dispose() }
if ($record.valid) { exit 0 } else { exit 2 }
