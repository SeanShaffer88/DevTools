#requires -Version 7.0
<#
.SYNOPSIS
    Hardened shared helpers for DevTools entry points (paths, bounded I/O, JSON,
    validation, hashing, processes, result envelopes, redaction).
.DESCRIPTION
    Consolidates the path/JSON/process/result boilerplate repeated across the
    toolkit's helpers and lib/*Common.ps1 files. Importing performs no system
    operations. Every function throws on invalid input; none calls `exit`.
    See lib/DevToolsCommon.md for per-function security notes.
.EXAMPLE
    Import-Module (Join-Path $PSScriptRoot 'lib/DevToolsCommon.psm1') -Force
#>
Set-StrictMode -Version 3.0

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
$script:MAX_PATH_CHARS = 4096
$script:DEFAULT_JSON_BYTES = 4MB
$script:DEFAULT_TEXT_BYTES = 16MB
$script:REGEX_TIMEOUT = [TimeSpan]::FromSeconds(2)
$script:RESERVED_DEVICE = '^(CON|PRN|AUX|NUL|CONIN\$|CONOUT\$|COM[0-9\u00b9\u00b2\u00b3]|LPT[0-9\u00b9\u00b2\u00b3])$'
$script:STRICT_UTF8 = [Text.UTF8Encoding]::new($false, $true)
$script:SEP = [IO.Path]::DirectorySeparatorChar

# ===========================================================================
# 1. Paths
# ===========================================================================

function Test-DtReparseFreeAncestry {
    # Internal: throws if the path or any existing ancestor is a reparse point
    # (symlink, junction, mount point, cloud placeholder).
    param([Parameter(Mandatory)][string]$FullPath)
    $cursor = $FullPath
    while ($cursor) {
        $info = [IO.FileInfo]::new($cursor)
        if ($info.Exists -or [IO.Directory]::Exists($cursor)) {
            if ($info.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Reparse points are refused: $cursor"
            }
        }
        $next = [IO.Path]::GetDirectoryName($cursor)
        if (-not $next -or $next -eq $cursor) { break }
        $cursor = $next
    }
}

function Assert-DtPathText {
    # Internal: lexical checks on caller-supplied path text before normalisation.
    param([AllowEmptyString()][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { throw 'A path is required.' }
    if ($Path.Length -gt $script:MAX_PATH_CHARS) { throw 'Path is too long.' }
    if ($Path -match '[\x00-\x1f"<>|*?]') { throw 'Path contains control, wildcard or reserved characters.' }
    if ($Path -match '^[\\/]{2}') { throw 'UNC and device paths (\\server, \\?\, \\.\) are refused.' }
    foreach ($segment in $Path -split '[\\/]') {
        if ($segment -eq '' -or $segment -eq '.' -or $segment -eq '..') { continue }
        if ($segment -match '[. ]$') { throw "Path segment ends with a dot or space: '$segment'" }
        $stem = ($segment -split '\.')[0]
        if ($stem -match $script:RESERVED_DEVICE) { throw "Reserved device name in path: '$segment'" }
    }
}

function Resolve-DtLocalPath {
    <#
    .SYNOPSIS  Normalise a caller-supplied path to a safe, absolute, local path.
    .PARAMETER Path  Absolute or relative path text (relative resolves against the process CWD).
    .PARAMETER Kind  Any (default), File or Directory: require that the path exists as that kind.
    .PARAMETER New   Require that the path does not exist yet; its parent must be an existing directory.
    .OUTPUTS   [string] fully qualified path.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Path,
        [ValidateSet('Any', 'File', 'Directory')][string]$Kind = 'Any',
        [switch]$New
    )
    Assert-DtPathText $Path
    $full = [IO.Path]::GetFullPath($Path)
    if ($full -notmatch '^[A-Za-z]:\\') { throw 'Only drive-letter local paths are accepted.' }
    if ($full.Substring(3).Contains(':')) { throw 'Alternate data streams are refused.' }
    Test-DtReparseFreeAncestry $full
    $isFile = [IO.File]::Exists($full)
    $isDir = [IO.Directory]::Exists($full)
    if ($New) {
        if ($isFile -or $isDir) { throw "Destination already exists: $full" }
        $parent = [IO.Path]::GetDirectoryName($full)
        if (-not $parent -or -not [IO.Directory]::Exists($parent)) { throw 'Parent directory must exist.' }
    }
    elseif ($Kind -eq 'File' -and -not $isFile) { throw "File not found: $full" }
    elseif ($Kind -eq 'Directory' -and -not $isDir) { throw "Directory not found: $full" }
    return $full
}

function Resolve-DtContainedPath {
    <#
    .SYNOPSIS  Resolve an untrusted relative path strictly inside a trusted root.
    .PARAMETER Root          Trusted directory (must exist).
    .PARAMETER RelativePath  Untrusted relative path (from a manifest, TOC, archive, etc.).
    .PARAMETER Kind          Any, File or Directory existence requirement.
    .OUTPUTS   [string] fully qualified path under Root.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][AllowEmptyString()][string]$RelativePath,
        [ValidateSet('Any', 'File', 'Directory')][string]$Kind = 'Any'
    )
    Assert-DtPathText $RelativePath
    if ([IO.Path]::IsPathRooted($RelativePath) -or $RelativePath.Contains(':')) {
        throw 'Contained paths must be relative and must not name a drive or stream.'
    }
    if (($RelativePath -split '[\\/]') -contains '..') { throw 'Parent-directory segments are refused.' }
    $base = (Resolve-DtLocalPath -Path $Root -Kind Directory).TrimEnd('\')
    $full = Resolve-DtLocalPath -Path ([IO.Path]::Combine($base, $RelativePath)) -Kind $Kind
    if (-not $full.StartsWith($base + $script:SEP, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Path escapes the declared root.'
    }
    return $full
}

function Get-DtFileTree {
    <#
    .SYNOPSIS  Breadth-first, bounded enumeration of files under a root.
    .PARAMETER MaxEntries     Total files+directories visited (default 10000).
    .PARAMETER MaxDepth       Directory depth below Root (default 16).
    .PARAMETER MaxTotalBytes  Sum of file lengths (default 1 GiB).
    .PARAMETER ExcludeDirectoryName  Directory names to skip (e.g. .git, node_modules).
    .PARAMETER SkipReparsePoints     Skip instead of refusing reparse entries.
    .PARAMETER IncludeReparsePoints  Emit reparse entries (IsReparsePoint=$true, never followed) so callers can report them.
    .OUTPUTS   [pscustomobject] FullName, RelativePath ('/' separated), Length, IsReparsePoint.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Root,
        [ValidateRange(1, 1000000)][int]$MaxEntries = 10000,
        [ValidateRange(0, 64)][int]$MaxDepth = 16,
        [ValidateRange(0, [long]::MaxValue)][long]$MaxTotalBytes = 1GB,
        [string[]]$ExcludeDirectoryName = @(),
        [switch]$SkipReparsePoints,
        [switch]$IncludeReparsePoints
    )
    if ($SkipReparsePoints -and $IncludeReparsePoints) { throw 'Use either -SkipReparsePoints or -IncludeReparsePoints.' }
    $base = Resolve-DtLocalPath -Path $Root -Kind Directory
    $exclude = [Collections.Generic.HashSet[string]]::new([string[]]$ExcludeDirectoryName, [StringComparer]::OrdinalIgnoreCase)
    $queue = [Collections.Generic.Queue[object]]::new()
    $queue.Enqueue([pscustomobject]@{ Path = $base; Depth = 0 })
    $count = 0
    $bytes = 0L
    $options = [IO.EnumerationOptions]@{ AttributesToSkip = 0; IgnoreInaccessible = $false; RecurseSubdirectories = $false }
    while ($queue.Count -gt 0) {
        $dir = $queue.Dequeue()
        foreach ($item in [IO.DirectoryInfo]::new($dir.Path).EnumerateFileSystemInfos('*', $options)) {
            if (++$count -gt $MaxEntries) { throw "Tree exceeds $MaxEntries entries." }
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                if ($SkipReparsePoints) { continue }
                if ($IncludeReparsePoints) {
                    [pscustomobject]@{
                        FullName       = $item.FullName
                        RelativePath   = [IO.Path]::GetRelativePath($base, $item.FullName).Replace('\', '/')
                        Length         = 0L
                        IsReparsePoint = $true
                    }
                    continue
                }
                throw "Reparse entry refused: $($item.FullName)"
            }
            if ($item -is [IO.DirectoryInfo]) {
                if ($exclude.Contains($item.Name)) { continue }
                if ($dir.Depth + 1 -gt $MaxDepth) { throw "Tree exceeds depth $MaxDepth." }
                $queue.Enqueue([pscustomobject]@{ Path = $item.FullName; Depth = $dir.Depth + 1 })
                continue
            }
            $bytes += $item.Length
            if ($bytes -gt $MaxTotalBytes) { throw "Tree exceeds $MaxTotalBytes bytes." }
            [pscustomobject]@{
                FullName       = $item.FullName
                RelativePath   = [IO.Path]::GetRelativePath($base, $item.FullName).Replace('\', '/')
                Length         = $item.Length
                IsReparsePoint = $false
            }
        }
    }
}

function New-DtRunDirectory {
    <#
    .SYNOPSIS  Create a unique evidence directory: <Parent>/<yyyyMMddTHHmmssfffZ>-<random>.
    .OUTPUTS   [string] path of the created directory.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string])]
    param([Parameter(Mandatory)][string]$Parent)
    $base = Resolve-DtLocalPath -Path $Parent -Kind Directory
    $name = [DateTime]::UtcNow.ToString('yyyyMMdd\THHmmssfff\Z') + '-' + [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(6)).ToLowerInvariant()
    $path = Resolve-DtLocalPath -Path (Join-Path $base $name) -New
    if ($PSCmdlet.ShouldProcess($path, 'Create run directory')) {
        $null = [IO.Directory]::CreateDirectory($path)
    }
    return $path
}

# ===========================================================================
# 2. Bounded I/O and atomic writes
# ===========================================================================

function Read-DtBytes {
    <#
    .SYNOPSIS  Read a whole file with a hard byte cap enforced on the open handle.
    .OUTPUTS   [byte[]] (returned unenumerated).
    #>
    [CmdletBinding()]
    [OutputType([byte[]])]
    param(
        [Parameter(Mandatory)][string]$Path,
        [ValidateRange(0, 1GB)][long]$MaxBytes = $script:DEFAULT_TEXT_BYTES
    )
    $full = Resolve-DtLocalPath -Path $Path -Kind File
    $stream = [IO.FileStream]::new($full, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
        if ($stream.Length -gt $MaxBytes) { throw "File exceeds $MaxBytes bytes." }
        $buffer = [byte[]]::new([int]$stream.Length)
        $offset = 0
        while ($offset -lt $buffer.Length) {
            $read = $stream.Read($buffer, $offset, $buffer.Length - $offset)
            if ($read -eq 0) { throw 'File shrank while reading.' }
            $offset += $read
        }
        if ($stream.ReadByte() -ne -1) { throw 'File grew while reading.' }
        return , $buffer
    }
    finally { $stream.Dispose() }
}

function Read-DtText {
    <#
    .SYNOPSIS  Read a bounded file as strict UTF-8 (invalid byte sequences throw). A BOM is stripped.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$Path,
        [ValidateRange(0, 1GB)][long]$MaxBytes = $script:DEFAULT_TEXT_BYTES
    )
    $bytes = Read-DtBytes -Path $Path -MaxBytes $MaxBytes
    $start = if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { 3 } else { 0 }
    try { return $script:STRICT_UTF8.GetString($bytes, $start, $bytes.Length - $start) }
    catch [Text.DecoderFallbackException] { throw 'File is not valid UTF-8.' }
}

function Write-DtFileAtomic {
    <#
    .SYNOPSIS  Write a file via same-directory temp file + flush + rename.
    .PARAMETER Content    [string] (written as UTF-8 without BOM) or [byte[]].
    .PARAMETER Overwrite  Replace an existing file; otherwise an existing target throws.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][object]$Content,
        [switch]$Overwrite,
        [ValidateRange(0, 1GB)][long]$MaxBytes = 256MB
    )
    $full = if ($Overwrite -and [IO.File]::Exists($Path)) { Resolve-DtLocalPath -Path $Path -Kind File } else { Resolve-DtLocalPath -Path $Path -New }
    $bytes = if ($Content -is [byte[]]) { $Content }
             elseif ($Content -is [string]) { $script:STRICT_UTF8.GetBytes($Content) }
             else { throw 'Content must be a string or byte[].' }
    if ($bytes.LongLength -gt $MaxBytes) { throw "Content exceeds $MaxBytes bytes." }
    if (-not $PSCmdlet.ShouldProcess($full, 'Write file')) { return }
    $temp = Join-Path ([IO.Path]::GetDirectoryName($full)) ('.' + [IO.Path]::GetFileName($full) + '.' + [Guid]::NewGuid().ToString('N') + '.tmp')
    try {
        $stream = [IO.FileStream]::new($temp, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try { $stream.Write($bytes, 0, $bytes.Length); $stream.Flush($true) }
        finally { $stream.Dispose() }
        [IO.File]::Move($temp, $full, [bool]$Overwrite)
    }
    finally {
        if ([IO.File]::Exists($temp)) { [IO.File]::Delete($temp) }
    }
}

# ===========================================================================
# 3. JSON
# ===========================================================================

function Read-DtJson {
    <#
    .SYNOPSIS  Read bounded, strict-UTF-8 JSON as ordered hashtables.
    .PARAMETER MaxBytes  Default 4 MiB.  .PARAMETER Depth  Nesting limit (default 64).
    .PARAMETER AllowNonObjectRoot  Accept arrays/scalars at the root.
    .PARAMETER SchemaVersion       When set, require root.schemaVersion to equal it.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [ValidateRange(1, 1GB)][long]$MaxBytes = $script:DEFAULT_JSON_BYTES,
        [ValidateRange(1, 256)][int]$Depth = 64,
        [switch]$AllowNonObjectRoot,
        [int]$SchemaVersion
    )
    $text = Read-DtText -Path $Path -MaxBytes $MaxBytes
    if ([string]::IsNullOrWhiteSpace($text)) { throw 'JSON document is empty.' }
    $value = ConvertFrom-Json -InputObject $text -AsHashtable -Depth $Depth -NoEnumerate -ErrorAction Stop
    if (-not $AllowNonObjectRoot -and $value -isnot [Collections.IDictionary]) { throw 'JSON root must be an object.' }
    if ($PSBoundParameters.ContainsKey('SchemaVersion')) {
        if ($value -isnot [Collections.IDictionary] -or -not $value.Contains('schemaVersion')) { throw 'schemaVersion is missing.' }
        $actual = Assert-DtInteger -Value $value['schemaVersion'] -Minimum 0 -Maximum ([int]::MaxValue) -Name 'schemaVersion'
        if ($actual -ne $SchemaVersion) { throw "schemaVersion must be $SchemaVersion." }
    }
    return , $value
}

function ConvertTo-DtCanonicalJson {
    <#
    .SYNOPSIS  Deterministic compact JSON (ordinal-sorted keys) for hashing/comparison.
    .NOTES     Non-finite numbers, non-string keys and depth > MaxDepth throw.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][AllowNull()][AllowEmptyString()][AllowEmptyCollection()][object]$InputObject,
        [ValidateRange(1, 256)][int]$MaxDepth = 64
    )
    function Write-Node($Node, [int]$Level) {
        if ($Level -gt $MaxDepth) { throw "Canonical JSON exceeds depth $MaxDepth." }
        if ($null -eq $Node) { return 'null' }
        if ($Node -is [string] -or $Node -is [char] -or $Node -is [guid]) { return ConvertTo-Json -InputObject ([string]$Node) -Compress }
        if ($Node -is [bool]) { return $(if ($Node) { 'true' } else { 'false' }) }
        if ($Node -is [datetime]) { return ConvertTo-Json -InputObject $Node.ToUniversalTime().ToString('o') -Compress }
        if ($Node -is [double] -or $Node -is [single]) {
            if ([double]::IsNaN($Node) -or [double]::IsInfinity($Node)) { throw 'Non-finite numbers are not valid JSON.' }
            return ([double]$Node).ToString('R', [Globalization.CultureInfo]::InvariantCulture)
        }
        if ($Node -is [ValueType] -and $Node.GetType().IsPrimitive -or $Node -is [decimal] -or $Node -is [Numerics.BigInteger]) {
            return ([IFormattable]$Node).ToString($null, [Globalization.CultureInfo]::InvariantCulture)
        }
        if ($Node -is [Collections.IDictionary]) {
            $keys = [Collections.Generic.List[string]]::new()
            foreach ($k in $Node.Keys) { if ($k -isnot [string]) { throw 'Object keys must be strings.' }; $keys.Add($k) }
            $keys.Sort([StringComparer]::Ordinal)
            $parts = foreach ($k in $keys) { (ConvertTo-Json -InputObject $k -Compress) + ':' + (Write-Node $Node[$k] ($Level + 1)) }
            return '{' + ($parts -join ',') + '}'
        }
        if ($Node -is [Collections.IEnumerable]) {
            $parts = foreach ($x in $Node) { Write-Node $x ($Level + 1) }
            return '[' + ($parts -join ',') + ']'
        }
        if ($Node -is [psobject]) {
            $map = [ordered]@{}
            foreach ($p in $Node.PSObject.Properties) { $map[$p.Name] = $p.Value }
            return Write-Node $map $Level
        }
        throw "Unsupported type for canonical JSON: $($Node.GetType().FullName)"
    }
    Write-Node $InputObject 0
}

function Get-DtJsonPointer {
    <#
    .SYNOPSIS  Resolve an RFC 6901 JSON Pointer. Returns @{ Exists; Value }.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()][object]$InputObject,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Pointer
    )
    if ($Pointer -eq '') { return @{ Exists = $true; Value = $InputObject } }
    if (-not $Pointer.StartsWith('/')) { throw 'JSON Pointer must be empty or start with /.' }
    $node = $InputObject
    foreach ($raw in $Pointer.Substring(1).Split('/')) {
        $key = $raw.Replace('~1', '/').Replace('~0', '~')
        if ($node -is [Collections.IDictionary]) {
            if (-not $node.Contains($key)) { return @{ Exists = $false; Value = $null } }
            $node = $node[$key]
        }
        elseif ($node -is [Collections.IList] -and $key -match '^(0|[1-9][0-9]{0,8})$' -and [int]$key -lt $node.Count) {
            $node = $node[[int]$key]
        }
        else { return @{ Exists = $false; Value = $null } }
    }
    return @{ Exists = $true; Value = $node }
}

# ===========================================================================
# 4. Validation
# ===========================================================================

function Assert-DtInteger {
    <#
    .SYNOPSIS  Require a true integer (not string, bool or float) within [Minimum, Maximum]. Returns [long].
    #>
    [CmdletBinding()]
    [OutputType([long])]
    param(
        [AllowNull()][object]$Value,
        [long]$Minimum = [long]::MinValue,
        [long]$Maximum = [long]::MaxValue,
        [string]$Name = 'value'
    )
    $ok = $Value -is [int] -or $Value -is [long] -or $Value -is [short] -or $Value -is [byte] -or $Value -is [Numerics.BigInteger]
    if (-not $ok -or $Value -lt $Minimum -or $Value -gt $Maximum) { throw "Invalid integer for $Name (expected $Minimum..$Maximum)." }
    return [long]$Value
}

function Assert-DtSafeName {
    <#
    .SYNOPSIS  Require a portable identifier usable as a file, folder or project name.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Name,
        [ValidateRange(1, 255)][int]$MaxLength = 64
    )
    if ($Name.Length -gt $MaxLength -or $Name -cnotmatch '^[A-Za-z][A-Za-z0-9._-]*$' -or $Name.EndsWith('.') -or $Name.Contains('..')) {
        throw "Invalid name '$Name': use a letter followed by letters, digits, '.', '_' or '-'."
    }
    if (($Name -split '\.')[0] -match $script:RESERVED_DEVICE) { throw "Reserved device name: '$Name'" }
    return $Name
}

function Assert-DtSha256 {
    <#
    .SYNOPSIS  Require exactly 64 hex characters. Returns the uppercase form.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)
    if ($Value -cnotmatch '^[0-9A-Fa-f]{64}$') { throw 'SHA-256 must be 64 hexadecimal characters.' }
    return $Value.ToUpperInvariant()
}

# ===========================================================================
# 5. Hashing
# ===========================================================================

function Get-DtFileSha256 {
    <#
    .SYNOPSIS  Stream a file through SHA-256 with a byte cap. Returns uppercase hex.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$Path,
        [ValidateRange(0, [long]::MaxValue)][long]$MaxBytes = 4GB
    )
    $full = Resolve-DtLocalPath -Path $Path -Kind File
    $stream = [IO.FileStream]::new($full, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read, 81920, [IO.FileOptions]::SequentialScan)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        if ($stream.Length -gt $MaxBytes) { throw "File exceeds hash budget of $MaxBytes bytes." }
        $buffer = [byte[]]::new(81920)
        $total = 0L
        while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $total += $read
            if ($total -gt $MaxBytes) { throw 'File grew past the hash budget while reading.' }
            $null = $sha.TransformBlock($buffer, 0, $read, $null, 0)
        }
        $null = $sha.TransformFinalBlock([byte[]]::new(0), 0, 0)
        return [Convert]::ToHexString($sha.Hash)
    }
    finally { $sha.Dispose(); $stream.Dispose() }
}

function Get-DtTreeHash {
    <#
    .SYNOPSIS  Hash a directory tree as SHA-256 over canonical {relativePath: fileSha256}.
    .OUTPUTS   [pscustomobject] Sha256, FileCount, TotalBytes.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Root,
        [ValidateRange(1, 1000000)][int]$MaxEntries = 10000,
        [ValidateRange(0, [long]::MaxValue)][long]$MaxTotalBytes = 1GB,
        [string[]]$ExcludeDirectoryName = @()
    )
    $map = [ordered]@{}
    $total = 0L
    foreach ($file in Get-DtFileTree -Root $Root -MaxEntries $MaxEntries -MaxTotalBytes $MaxTotalBytes -ExcludeDirectoryName $ExcludeDirectoryName) {
        # Default mode throws on reparse entries, so every record here is a regular file.
        $map[$file.RelativePath] = Get-DtFileSha256 -Path $file.FullName -MaxBytes ($MaxTotalBytes - $total)
        $total += $file.Length
    }
    $canonical = ConvertTo-DtCanonicalJson -InputObject $map
    $digest = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($script:STRICT_UTF8.GetBytes($canonical)))
    [pscustomobject]@{ Sha256 = $digest; FileCount = $map.Count; TotalBytes = $total }
}

# ===========================================================================
# 6. Processes
# ===========================================================================

function Resolve-DtExecutable {
    <#
    .SYNOPSIS  Resolve a native .exe/.com by absolute path or PATH lookup (never the CWD).
    .NOTES     .bat/.cmd/.ps1 are refused: cmd.exe re-parses their arguments (injection).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][string]$Name)
    if ([IO.Path]::IsPathRooted($Name)) {
        $candidate = $Name
    }
    else {
        if ($Name -match '[\\/]') { throw 'Use an absolute path or a bare command name.' }
        Assert-DtPathText $Name
        $candidate = (Get-Command -Name $Name -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
    }
    # Store-app execution aliases (e.g. pwsh.exe from the Microsoft Store) are reparse-point
    # files that exist only in %LOCALAPPDATA%\Microsoft\WindowsApps. Allow exactly that case:
    # the file itself may be a reparse point there, every ancestor must still be ordinary.
    $aliasDir = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Microsoft\WindowsApps'
    $full = [IO.Path]::GetFullPath($candidate)
    $parent = [IO.Path]::GetDirectoryName($full)
    $isAlias = ($parent -ieq $aliasDir -or $parent.StartsWith($aliasDir + $script:SEP, [StringComparison]::OrdinalIgnoreCase)) -and
               [IO.File]::Exists($full) -and ([IO.File]::GetAttributes($full) -band [IO.FileAttributes]::ReparsePoint)
    if ($isAlias) {
        Assert-DtPathText $full
        $null = Resolve-DtLocalPath -Path $parent -Kind Directory
    }
    else {
        $full = Resolve-DtLocalPath -Path $candidate -Kind File
    }
    if ([IO.Path]::GetExtension($full) -notin '.exe', '.com') {
        throw "Only native .exe/.com executables are accepted; select an interpreter explicitly for '$([IO.Path]::GetFileName($full))'."
    }
    return $full
}

function Invoke-DtProcess {
    <#
    .SYNOPSIS  Run a native executable without a shell, with timeout, output caps and tree cleanup.
    .PARAMETER Executable        Absolute path or bare name resolved via PATH (see Resolve-DtExecutable).
    .PARAMETER ArgumentList      Each element is passed as one argv entry; no quoting needed.
    .PARAMETER WorkingDirectory  Required; must be an existing local directory.
    .PARAMETER TimeoutSeconds    1..86400 (default 60). Timeout => ExitCode 124.
    .PARAMETER MaxOutputBytes    Per stream (default 2 MiB). Excess is drained and discarded.
    .PARAMETER Environment       Variables to add/override for the child.
    .PARAMETER CleanEnvironment  Start from a minimal environment (drops tokens/secrets in the parent env).
    .PARAMETER MaxProcessMemoryBytes  Optional per-process commit limit via Job Object (0 = none).
    .OUTPUTS   [pscustomobject] ExitCode, TimedOut, Stdout, Stderr, StdoutTruncated, StderrTruncated,
               JobAssigned, DescendantsTerminated, ElapsedMilliseconds, Executable. Arguments are not echoed.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$Executable,
        [AllowEmptyCollection()][string[]]$ArgumentList = @(),
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [ValidateRange(1, 86400)][int]$TimeoutSeconds = 60,
        [ValidateRange(0, 256MB)][int]$MaxOutputBytes = 2MB,
        [hashtable]$Environment,
        [switch]$CleanEnvironment,
        [ValidateRange(0, [long]::MaxValue)][long]$MaxProcessMemoryBytes = 0
    )
    $exe = Resolve-DtExecutable -Name $Executable
    $cwd = Resolve-DtLocalPath -Path $WorkingDirectory -Kind Directory
    if ($ArgumentList.Count -gt 4096) { throw 'Too many arguments.' }
    $length = 0
    foreach ($a in $ArgumentList) {
        if ($null -eq $a) { throw 'Null arguments are not allowed.' }
        if ($a.Contains([char]0)) { throw 'Arguments must not contain NUL.' }
        $length += $a.Length + 3
    }
    if ($length -gt 32000) { throw 'Command line exceeds the Windows limit.' }
    $envMap = $null
    if ($Environment) {
        $envMap = [Collections.Generic.Dictionary[string, string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($k in $Environment.Keys) {
            $key = [string]$k
            $val = [string]$Environment[$k]
            if ($key -notmatch '^[A-Za-z_][A-Za-z0-9_().-]*$' -or $val.Contains([char]0)) { throw "Invalid environment variable '$key'." }
            $envMap[$key] = $val
        }
    }
    if (-not $PSCmdlet.ShouldProcess($exe, 'Run process')) { return }
    if (-not ('LocalDevTools.Common.BoundedProcess' -as [type])) {
        Add-Type -Path (Join-Path $PSScriptRoot 'DevToolsProcess.cs')
    }
    $r = [LocalDevTools.Common.BoundedProcess]::Run($exe, [string[]]$ArgumentList, $cwd, $TimeoutSeconds, $MaxOutputBytes, $envMap, [bool]$CleanEnvironment, $MaxProcessMemoryBytes)
    $lossy = [Text.UTF8Encoding]::new($false, $false)
    [pscustomobject]@{
        Executable            = $exe
        ExitCode              = $r.ExitCode
        TimedOut              = $r.TimedOut
        Stdout                = $lossy.GetString($r.Stdout)
        Stderr                = $lossy.GetString($r.Stderr)
        StdoutTruncated       = $r.StdoutTruncated
        StderrTruncated       = $r.StderrTruncated
        JobAssigned           = $r.JobAssigned
        DescendantsTerminated = $r.DescendantsTerminated
        ElapsedMilliseconds   = $r.ElapsedMilliseconds
    }
}

# ===========================================================================
# 7. Result envelopes and redaction
# ===========================================================================

function New-DtResult {
    <#
    .SYNOPSIS  Create the toolkit's standard schemaVersion 1 result envelope.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Tool,
        [string]$Scope = ''
    )
    [ordered]@{
        schemaVersion = 1
        observedUtc   = [DateTime]::UtcNow.ToString('o')
        tool          = $Tool
        scope         = $Scope
        status        = 'Unknown'
        valid         = $false
        findings      = [Collections.Generic.List[object]]::new()
        limitations   = [Collections.Generic.List[string]]::new()
        error         = $null
    }
}

function Add-DtFinding {
    <#
    .SYNOPSIS  Append a finding; message and path are redacted with Protect-DtText.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][Collections.IDictionary]$Result,
        [Parameter(Mandatory)][ValidatePattern('^[A-Za-z][A-Za-z0-9.]{0,63}$')][string]$Code,
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('Info', 'Warning', 'Error')][string]$Severity = 'Error',
        [string]$Path = ''
    )
    if ($Result.findings.Count -ge 10000) { throw 'Finding limit reached.' }
    $Result.findings.Add([ordered]@{
        code     = $Code
        severity = $Severity
        message  = Protect-DtText $Message
        path     = Protect-DtText $Path
    })
}

function Complete-DtResult {
    <#
    .SYNOPSIS  Set status/valid from an exit code and emit JSON or an object. Never calls exit.
    .NOTES     0 Pass, 2 Fail, 3 Unknown, 124 TimedOut, anything else SetupError.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][Collections.IDictionary]$Result,
        [Parameter(Mandatory)][int]$ExitCode,
        [AllowNull()][object]$ErrorRecord,
        [switch]$Json
    )
    $Result.status = switch ($ExitCode) { 0 { 'Pass' } 2 { 'Fail' } 3 { 'Unknown' } 124 { 'TimedOut' } default { 'SetupError' } }
    $Result.valid = $ExitCode -eq 0
    if ($ErrorRecord) { $Result.error = Protect-DtText ([string]$ErrorRecord) }
    if ($Json) { return ConvertTo-Json -InputObject $Result -Depth 32 }
    return [pscustomobject]$Result
}

function Protect-DtText {
    <#
    .SYNOPSIS  Redact common secrets (tokens, keys, passwords, URL credentials, private keys)
               and the user profile path from text before it is logged or shared.
    .NOTES     Best effort; pattern redaction cannot prove text is free of secrets.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)][AllowEmptyString()][AllowNull()][string]$Text,
        [ValidateRange(0, 64MB)][int]$MaxChars = 16MB
    )
    process {
        if ([string]::IsNullOrEmpty($Text)) { return [string]$Text }
        if ($Text.Length -gt $MaxChars) { throw "Text exceeds $MaxChars characters." }
        $o = [Text.RegularExpressions.RegexOptions]'CultureInvariant'
        $i = $o -bor [Text.RegularExpressions.RegexOptions]::IgnoreCase
        $rules = @(
            @('-----BEGIN [A-Z ]{0,40}PRIVATE KEY-----[\s\S]{0,20000}?-----END [A-Z ]{0,40}PRIVATE KEY-----', $o, '[REDACTED-PRIVATE-KEY]'),
            @('\b(?:gh[pousr]_[A-Za-z0-9]{36,255}|github_pat_[A-Za-z0-9_]{22,255})\b', $o, '[REDACTED-TOKEN]'),
            @('\bsk-(?:ant-)?[A-Za-z0-9_-]{20,}', $o, '[REDACTED-TOKEN]'),
            @('\b(?:AKIA|ASIA)[A-Z0-9]{16}\b', $o, '[REDACTED-TOKEN]'),
            @('\bxox[abposr]-[A-Za-z0-9-]{10,}', $o, '[REDACTED-TOKEN]'),
            @('\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}', $o, '[REDACTED-JWT]'),
            @('\b(bearer|basic)\s+[A-Za-z0-9._~+/=-]{12,}', $i, '$1 [REDACTED]'),
            @('\b([a-z][a-z0-9+.-]{0,30}://)[^\s/:@]{1,256}:[^\s/@]{1,256}@', $i, '$1[REDACTED]@'),
            @('\b(password|passwd|pwd|secret|token|api[_-]?key|client[_-]?secret|access[_-]?key)(\s*[:=]\s*)("[^"\r\n]*"|''[^''\r\n]*''|[^\s;,&]+)', $i, '$1$2[REDACTED]')
        )
        foreach ($rule in $rules) {
            $Text = [regex]::new($rule[0], $rule[1], $script:REGEX_TIMEOUT).Replace($Text, $rule[2])
        }
        $userProfile = [Environment]::GetFolderPath('UserProfile')
        if ($userProfile) {
            $Text = [regex]::new([regex]::Escape($userProfile), $i, $script:REGEX_TIMEOUT).Replace($Text, '%USERPROFILE%')
        }
        return $Text
    }
}

Export-ModuleMember -Function @(
    'Resolve-DtLocalPath', 'Resolve-DtContainedPath', 'Get-DtFileTree', 'New-DtRunDirectory',
    'Read-DtBytes', 'Read-DtText', 'Write-DtFileAtomic',
    'Read-DtJson', 'ConvertTo-DtCanonicalJson', 'Get-DtJsonPointer',
    'Assert-DtInteger', 'Assert-DtSafeName', 'Assert-DtSha256',
    'Get-DtFileSha256', 'Get-DtTreeHash',
    'Resolve-DtExecutable', 'Invoke-DtProcess',
    'New-DtResult', 'Add-DtFinding', 'Complete-DtResult', 'Protect-DtText'
)
