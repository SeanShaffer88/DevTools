#requires -Version 7.0
<#
.SYNOPSIS
Checks addon TOC metadata and the local Lua/XML load graph without executing code.
.PARAMETER AddonPath
Literal local addon directory. References must remain inside this directory.
.PARAMETER TocPath
Explicit TOC, relative to AddonPath or an absolute path inside it. Required when multiple TOCs exist.
.PARAMETER InterfaceVersion
Optional client Interface number to match against declared TOC values.
.NOTES
Lua syntax, API availability, declared dependency installation, and in-game behavior
are not tested. Rejects reparse points, DTDs, external entities and reference cycles.
Uses lib/DevToolsCommon.psm1 for local path validation (UNC/device paths, streams, reserved
device names, trailing dots/spaces and reparse points are refused), bounded reads and redaction.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$AddonPath,[string]$TocPath,[ValidateRange(1,9999999)][int]$InterfaceVersion,[switch]$Json)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'lib\DevToolsCommon.psm1') -Force
$MAX_TOC_BYTES=1048576
$MAX_XML_BYTES=2097152
$MAX_LOAD_ENTRIES=10000
$MAX_INCLUDE_DEPTH=32
$findings=[Collections.Generic.List[object]]::new()
$order=[Collections.Generic.List[object]]::new()
$metadata=[ordered]@{}
$seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$active=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$result=[ordered]@{schemaVersion=1;observedUtc=[DateTime]::UtcNow.ToString('o');valid=$false;addonPath=$null;tocPath=$null;metadata=$metadata;declaredDependencies=@();loadOrder=@();findings=@();luaSyntax='NotPerformed';apiValidation='NotPerformed';runtimeValidation='NotPerformed';dependencyAvailability='NotPerformed'}
function Finding([string]$Code,[string]$Message,[string]$Severity='Error') { $findings.Add([pscustomobject]@{code=$Code;severity=$Severity;message=(Protect-DtText $Message)}) }
function Inside([string]$Path) {
    # Containment is decided on the normalised path; Resolve-DtLocalPath then rejects the raw text
    # if Windows would silently rewrite it (trailing dots/spaces) or it names a device/stream/reparse point.
    $full=[IO.Path]::GetFullPath($Path)
    if(-not $full.StartsWith($rootPrefix,[StringComparison]::OrdinalIgnoreCase)){throw 'Reference escapes the addon directory.'}
    return Resolve-DtLocalPath -Path $Path
}
function Reference([string]$Base,[string]$Value) {
    $normalized=$Value.Replace('/',[IO.Path]::DirectorySeparatorChar)
    if([IO.Path]::IsPathRooted($normalized) -or $normalized.Contains(':')){throw "Rooted or stream reference is not allowed: $Value"}
    if([string]::IsNullOrWhiteSpace($normalized)){throw 'Empty reference.'}
    # '..' is allowed (XML commonly includes ..\Shared\x.xml) as long as the result stays inside the addon.
    return Inside ($Base.TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar+$normalized)
}
function Read-TocLines([string]$Path) {
    # Bounded read on one handle, then the same decoding File.ReadAllLines uses
    # (UTF-8 default, BOM detection, lenient) so legacy TOCs keep working.
    $bytes=Read-DtBytes -Path $Path -MaxBytes $MAX_TOC_BYTES
    $reader=[IO.StreamReader]::new([IO.MemoryStream]::new($bytes,$false),[Text.Encoding]::UTF8,$true)
    try{$lines=[Collections.Generic.List[string]]::new();while($null -ne ($line=$reader.ReadLine())){$lines.Add($line)};return ,$lines.ToArray()}
    finally{$reader.Dispose()}
}
function Visit([string]$FullPath,[int]$Depth,[string]$Source) {
    if($Depth -gt $MAX_INCLUDE_DEPTH){Finding 'DepthLimit' "XML include depth exceeds $MAX_INCLUDE_DEPTH.";return}
    if($order.Count -ge $MAX_LOAD_ENTRIES){throw "Load graph exceeds $MAX_LOAD_ENTRIES entries."}
    $relative=[IO.Path]::GetRelativePath($root,$FullPath)
    if($active.Contains($FullPath)){Finding 'ReferenceCycle' "Include cycle: $relative";return}
    if(-not [IO.File]::Exists($FullPath)){Finding 'MissingFile' "Missing file: $relative";return}
    if(-not $seen.Add($FullPath)){Finding 'RepeatedLoad' "Repeated load entry: $relative" 'Warning'}
    $order.Add([pscustomobject]@{path=$relative;source=$Source;depth=$Depth})
    $extension=[IO.Path]::GetExtension($FullPath)
    if($extension -ieq '.lua'){return}
    if($extension -ine '.xml'){Finding 'UnrecognizedFileType' "Load entry is neither Lua nor XML: $relative" 'Warning';return}
    if([IO.FileInfo]::new($FullPath).Length -gt $MAX_XML_BYTES){Finding 'XmlSizeLimit' "XML exceeds 2 MiB: $relative";return}
    $null=$active.Add($FullPath)
    $reader=$null
    try {
        $bytes=Read-DtBytes -Path $FullPath -MaxBytes $MAX_XML_BYTES
        $settings=[Xml.XmlReaderSettings]::new();$settings.DtdProcessing=[Xml.DtdProcessing]::Prohibit;$settings.XmlResolver=$null;$settings.MaxCharactersInDocument=$MAX_XML_BYTES
        $reader=[Xml.XmlReader]::Create([IO.MemoryStream]::new($bytes,$false),$settings)
        $doc=[Xml.XmlDocument]::new();$doc.XmlResolver=$null;$doc.Load($reader)
        foreach($node in $doc.SelectNodes('//*')) {
            if($node.LocalName -notin @('Include','Script') -or -not $node.HasAttribute('file')){continue}
            try { $next=Reference ([IO.Path]::GetDirectoryName($FullPath)) $node.GetAttribute('file'); Visit $next ($Depth+1) $relative }
            catch {Finding 'UnsafeReference' "$relative : $($_.Exception.Message)"}
        }
    } catch {Finding 'InvalidXml' "$relative : $($_.Exception.Message)"}
    finally {if($reader){$reader.Dispose()};$null=$active.Remove($FullPath)}
}
try {
    if([IO.File]::Exists([IO.Path]::GetFullPath($AddonPath))){throw 'AddonPath must be a directory.'}
    $root=(Resolve-DtLocalPath -Path $AddonPath -Kind Directory).TrimEnd([IO.Path]::DirectorySeparatorChar)
    $rootPrefix=$root+[IO.Path]::DirectorySeparatorChar;$result.addonPath=$root
    if($TocPath) {
        if([IO.Path]::IsPathRooted($TocPath)){$toc=Inside $TocPath}else{$toc=Reference $root $TocPath}
        if([IO.Path]::GetExtension($toc) -ine '.toc'){throw 'TocPath must have a .toc extension.'}
    } else {
        # Exact extension match: '*.toc' alone can also match 8.3 short names such as X~1.TOC for 'x.tocx'.
        $tocs=@([IO.Directory]::EnumerateFiles($root,'*.toc') | Where-Object {[IO.Path]::GetExtension($_) -ieq '.toc'})
        if($tocs.Count -ne 1){throw "Expected one TOC; found $($tocs.Count). Supply -TocPath when multiple exist."}
        $toc=Inside $tocs[0]
    }
    if(-not [IO.File]::Exists($toc)){throw 'TOC does not exist.'}
    if([IO.FileInfo]::new($toc).Length -gt $MAX_TOC_BYTES){throw 'TOC exceeds 1 MiB.'}
    $result.tocPath=$toc
    $entries=[Collections.Generic.List[string]]::new()
    foreach($line in (Read-TocLines $toc)) {
        $value=$line.Trim()
        if($value -match '^##\s*([^:]+):\s*(.*)$') {
            $key=$Matches[1].Trim();$val=$Matches[2].Trim()
            if($metadata.Contains($key)){Finding 'RepeatedMetadata' "Repeated metadata: $key" 'Warning'}
            $metadata[$key]=$val
        } elseif($value -and -not $value.StartsWith('#')) {$entries.Add($value)}
    }
    foreach($required in @('Interface','Title')){if(-not $metadata.Contains($required) -or [string]::IsNullOrWhiteSpace($metadata[$required])){Finding 'MissingMetadata' "Missing metadata: $required"}}
    if($metadata.Contains('Interface')) {
        $versions=@($metadata['Interface'] -split '[,\s]+' | Where-Object {$_})
        if($versions.Count -eq 0 -or @($versions | Where-Object {$_ -notmatch '^\d{1,7}$'}).Count){Finding 'InvalidInterface' 'Interface must contain numeric values.'}
        elseif($InterfaceVersion -and [string]$InterfaceVersion -notin $versions){Finding 'InterfaceMismatch' "Requested Interface $InterfaceVersion does not match $($metadata['Interface'])."}
    }
    foreach($key in @('Dependencies','RequiredDeps','OptionalDeps')) {if($metadata.Contains($key)){$result.declaredDependencies+=@($metadata[$key] -split '[,\s]+' | Where-Object {$_} | ForEach-Object {[pscustomobject]@{kind=$key;name=$_}})}}
    foreach($entry in $entries){try{$file=Reference ([IO.Path]::GetDirectoryName($toc)) $entry;Visit $file 0 ([IO.Path]::GetRelativePath($root,$toc))}catch{Finding 'UnsafeReference' $_.Exception.Message}}
} catch {Finding 'InvalidAddon' $_.Exception.Message}
$result.loadOrder=@($order.ToArray());$result.findings=@($findings.ToArray());$result.valid=@($findings | Where-Object severity -eq 'Error').Count -eq 0
$global:LASTEXITCODE=if($result.valid){0}else{2}
if($Json){$result | ConvertTo-Json -Depth 12}else{[pscustomobject]$result}
