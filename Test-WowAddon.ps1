#requires -Version 7.0
<#
.SYNOPSIS
Checks addon TOC metadata and the local Lua/XML load graph without executing code.
.PARAMETER AddonPath
Literal addon directory. References must remain inside this directory.
.PARAMETER TocPath
Explicit TOC, relative to AddonPath or an absolute path inside it. Required when multiple TOCs exist.
.PARAMETER InterfaceVersion
Optional client Interface number to match against declared TOC values.
.NOTES
Lua syntax, API availability, declared dependency installation, and in-game behavior
are not tested. Rejects reparse points, DTDs, external entities and reference cycles.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$AddonPath,[string]$TocPath,[ValidateRange(1,9999999)][int]$InterfaceVersion,[switch]$Json)
$ErrorActionPreference='Stop'
$findings=[Collections.Generic.List[object]]::new()
$order=[Collections.Generic.List[object]]::new()
$metadata=[ordered]@{}
$seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$active=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$result=[ordered]@{schemaVersion=1;observedUtc=[DateTime]::UtcNow.ToString('o');valid=$false;addonPath=$null;tocPath=$null;metadata=$metadata;declaredDependencies=@();loadOrder=@();findings=@();luaSyntax='NotPerformed';apiValidation='NotPerformed';runtimeValidation='NotPerformed';dependencyAvailability='NotPerformed'}
function Finding([string]$Code,[string]$Message,[string]$Severity='Error') { $findings.Add([pscustomobject]@{code=$Code;severity=$Severity;message=$Message}) }
function No-Reparse([string]$FullPath) {
    $part=$FullPath
    while($part) {
        if(Test-Path -LiteralPath $part) {
            $entry=Get-Item -LiteralPath $part -Force
            if(($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Reparse points are not allowed: $part" }
        }
        $parent=[IO.Path]::GetDirectoryName($part)
        if($parent -eq $part){break}; $part=$parent
    }
}
function Inside([string]$FullPath) {
    if(-not $FullPath.StartsWith($rootPrefix,[StringComparison]::OrdinalIgnoreCase)){throw 'Reference escapes the addon directory.'}
    No-Reparse $FullPath
    return $FullPath
}
function Reference([string]$Base,[string]$Value) {
    $normalized=$Value.Replace('/',[IO.Path]::DirectorySeparatorChar)
    if([IO.Path]::IsPathRooted($normalized) -or $normalized.Contains(':')){throw "Rooted or stream reference is not allowed: $Value"}
    if([string]::IsNullOrWhiteSpace($normalized)){throw 'Empty reference.'}
    return Inside ([IO.Path]::GetFullPath((Join-Path $Base $normalized)))
}
function Visit([string]$FullPath,[int]$Depth,[string]$Source) {
    if($Depth -gt 32){Finding 'DepthLimit' 'XML include depth exceeds 32.';return}
    if($order.Count -ge 10000){throw 'Load graph exceeds 10000 entries.'}
    $relative=[IO.Path]::GetRelativePath($root,$FullPath)
    if($active.Contains($FullPath)){Finding 'ReferenceCycle' "Include cycle: $relative";return}
    if(-not (Test-Path -LiteralPath $FullPath -PathType Leaf)){Finding 'MissingFile' "Missing file: $relative";return}
    if(-not $seen.Add($FullPath)){Finding 'RepeatedLoad' "Repeated load entry: $relative" 'Warning'}
    $order.Add([pscustomobject]@{path=$relative;source=$Source;depth=$Depth})
    $extension=[IO.Path]::GetExtension($FullPath)
    if($extension -ieq '.lua'){return}
    if($extension -ine '.xml'){Finding 'UnrecognizedFileType' "Load entry is neither Lua nor XML: $relative" 'Warning';return}
    if((Get-Item -LiteralPath $FullPath).Length -gt 2097152){Finding 'XmlSizeLimit' "XML exceeds 2 MiB: $relative";return}
    $null=$active.Add($FullPath)
    $reader=$null
    try {
        $settings=[Xml.XmlReaderSettings]::new();$settings.DtdProcessing=[Xml.DtdProcessing]::Prohibit;$settings.XmlResolver=$null;$settings.MaxCharactersInDocument=2097152
        $reader=[Xml.XmlReader]::Create($FullPath,$settings)
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
    $item=Get-Item -LiteralPath $AddonPath -Force
    if(-not $item.PSIsContainer){throw 'AddonPath must be a directory.'}
    $root=[IO.Path]::GetFullPath($item.FullName).TrimEnd([IO.Path]::DirectorySeparatorChar)
    No-Reparse $root
    $rootPrefix=$root+[IO.Path]::DirectorySeparatorChar;$result.addonPath=$root
    if($TocPath) {
        if([IO.Path]::IsPathRooted($TocPath)){$toc=Inside ([IO.Path]::GetFullPath($TocPath))}else{$toc=Reference $root $TocPath}
        if([IO.Path]::GetExtension($toc) -ine '.toc'){throw 'TocPath must have a .toc extension.'}
    } else {
        $tocs=@(Get-ChildItem -LiteralPath $root -File -Filter '*.toc' -Force)
        if($tocs.Count -ne 1){throw "Expected one TOC; found $($tocs.Count). Supply -TocPath when multiple exist."}
        $toc=Inside $tocs[0].FullName
    }
    if(-not (Test-Path -LiteralPath $toc -PathType Leaf)){throw 'TOC does not exist.'}
    if((Get-Item -LiteralPath $toc).Length -gt 1048576){throw 'TOC exceeds 1 MiB.'}
    $result.tocPath=$toc
    $entries=[Collections.Generic.List[string]]::new()
    foreach($line in [IO.File]::ReadAllLines($toc)) {
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
