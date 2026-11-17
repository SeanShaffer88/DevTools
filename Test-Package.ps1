#requires -Version 7.0
<#
.SYNOPSIS
Checks a local package folder, optional file manifest, and explicit PE architecture.
.PARAMETER ManifestPath
JSON schemaVersion 1 and files array: path, optional Boolean required, optional SHA256. UTF-8 (BOM optional).
.PARAMETER Strict
Treat unexpected payload files as errors. Requires ManifestPath. The manifest itself is excluded from unexpected files.
.PARAMETER MaxHashBytes
Optional cumulative byte limit for file hashes. Zero permits only empty files. A skipped file makes the result incomplete and returns exit 2.
.NOTES
Read-only. Does not execute installers or validate upgrades, signatures, runtime
dependencies, or settings preservation. ExpectedArchitecture compares PE machine headers.
Uses lib/DevToolsCommon.psm1 for local path validation, bounded strict-UTF-8 manifest reading,
contained manifest paths, bounded inventory, streamed hashing and message redaction.
PackagePath and ManifestPath must be local drive paths (UNC/device paths are refused).
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$PackagePath,[string]$ManifestPath,[ValidateSet('x86','x64','Arm64')][string]$ExpectedArchitecture,[switch]$Strict,[switch]$Json,[ValidateRange('NonNegative')][long]$MaxHashBytes)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'lib\DevToolsCommon.psm1') -Force
$MAX_ENTRIES=10000
$MAX_DEPTH=32
$MAX_MANIFEST_BYTES=2097152
$files=[Collections.Generic.List[object]]::new();$findings=[Collections.Generic.List[object]]::new()
$expected=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::OrdinalIgnoreCase)
$result=[ordered]@{schemaVersion=1;observedUtc=[DateTime]::UtcNow.ToString('o');valid=$false;packagePath=$null;manifestPath=$null;strict=[bool]$Strict;expectedArchitecture=$ExpectedArchitecture;files=@();findings=@();installerUpgrade='NotPerformed';settingsPreservation='NotPerformed';runtimeDependencies='NotPerformed';signatureVerification='NotPerformed';limits=@{entries=$MAX_ENTRIES;depth=$MAX_DEPTH;manifestBytes=$MAX_MANIFEST_BYTES}}
$hashBudgeted=$PSBoundParameters.ContainsKey('MaxHashBytes')
$budgetExceeded=$false
if ($hashBudgeted) {
    $result.limits.maxHashBytes=$MaxHashBytes
    $result.hashedBytes=0L
    $result.hashCoverage='Incomplete'
}
function Finding([string]$Code,[string]$Message,[string]$Severity='Error'){$findings.Add([pscustomobject]@{code=$Code;severity=$Severity;message=(Protect-DtText $Message)})}
function Manifest-File([string]$Value){
    # Manifest-specific strictness on top of Resolve-DtContainedPath: no wildcard brackets,
    # empty or '.' segments, so each manifest entry names exactly one canonical path.
    if([string]::IsNullOrWhiteSpace($Value) -or $Value.IndexOfAny([char[]]'[]') -ge 0){throw "Invalid manifest file path: $Value"}
    $parts=$Value.Replace('\','/').Split('/')
    foreach($part in $parts){if($part -in @('','.','..') -or $part.TrimEnd(' ','.') -cne $part){throw "Ambiguous or traversing manifest file path: $Value"}}
    try{$full=Resolve-DtContainedPath -Root $root -RelativePath ($parts -join '\')}
    catch{throw "Invalid manifest file path: $Value ($($_.Exception.Message))"}
    return [IO.Path]::GetRelativePath($root,$full)
}
try{
    $root=(Resolve-DtLocalPath -Path $PackagePath -Kind Directory).TrimEnd([IO.Path]::DirectorySeparatorChar)
    $result.packagePath=$root
    if($Strict -and -not $ManifestPath){throw '-Strict requires -ManifestPath.'}
    $manifestFull=$null
    if($ManifestPath){
        $manifestFull=Resolve-DtLocalPath -Path $ManifestPath -Kind File;$result.manifestPath=$manifestFull
        if([IO.FileInfo]::new($manifestFull).Length -gt $MAX_MANIFEST_BYTES){throw 'Manifest must be a file no larger than 2 MiB.'}
        $manifest=Read-DtJson -Path $manifestFull -MaxBytes $MAX_MANIFEST_BYTES -Depth 20
        if($manifest['files'] -isnot [array]){throw 'Manifest requires integer schemaVersion 1 and a files array.'}
        try{$null=Assert-DtInteger -Value $manifest['schemaVersion'] -Minimum 1 -Maximum 1 -Name 'schemaVersion'}
        catch{throw 'Manifest requires integer schemaVersion 1 and a files array.'}
        if(@($manifest.Keys | Where-Object {$_ -notin @('schemaVersion','files')}).Count){throw 'Manifest has unknown root fields.'}
        foreach($entry in $manifest.files){
            if($entry -isnot [Collections.IDictionary] -or $entry['path'] -isnot [string]){throw 'Each manifest file must be an object with a string path.'}
            if(@($entry.Keys | Where-Object {$_ -notin @('path','required','sha256')}).Count){throw 'Manifest file has unknown fields.'}
            if($entry.Contains('required') -and $entry.required -isnot [bool]){throw 'Manifest required must be Boolean.'}
            $sha=$null
            if($entry.Contains('sha256')){
                if($entry.sha256 -isnot [string]){throw 'Manifest SHA256 must be 64 hexadecimal characters.'}
                try{$sha=Assert-DtSha256 -Value $entry.sha256}catch{throw 'Manifest SHA256 must be 64 hexadecimal characters.'}
            }
            $relative=Manifest-File $entry.path
            if($expected.ContainsKey($relative)){throw "Duplicate manifest path: $relative"}
            $expected.Add($relative,[pscustomobject]@{required=if($entry.Contains('required')){$entry.required}else{$true};sha256=$sha})
        }
    }
    $actual=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach($entry in Get-DtFileTree -Root $root -MaxEntries $MAX_ENTRIES -MaxDepth $MAX_DEPTH -MaxTotalBytes ([long]::MaxValue) -IncludeReparsePoints){
        $relative=[IO.Path]::GetRelativePath($root,$entry.FullName)
        if($entry.IsReparsePoint){Finding 'ReparsePoint' "Skipped reparse point: $relative";continue}
        $null=$actual.Add($relative)
        $size=$entry.Length
        $hash=$null
        if ($hashBudgeted) {
            $remaining=$MaxHashBytes - $result.hashedBytes
            if ($size -gt $remaining) {
                $budgetExceeded=$true
                Finding 'HashBudgetExceeded' "Skipped hash and PE inspection for $relative because its size exceeds the remaining hash budget."
            } else {
                $hash=Get-DtFileSha256 -Path $entry.FullName -MaxBytes $remaining
                $result.hashedBytes+=$size
            }
        } else {
            $hash=Get-DtFileSha256 -Path $entry.FullName -MaxBytes ([long]::MaxValue)
        }
        $info=[ordered]@{path=$relative;size=$size;sha256=$hash;architecture=$null;hasClrHeader=$null;fileVersion=$null}
        if($null -ne $hash -and [IO.Path]::GetExtension($entry.FullName) -in @('.exe','.dll')){
            $pe=& (Join-Path $PSScriptRoot 'Get-DllInfo.ps1') -Path $entry.FullName
            if(-not $pe.valid){Finding 'InvalidPe' "$relative : $($pe.error)"}
            else{
                $info.architecture=$pe.image.Architecture;$info.hasClrHeader=$pe.image.HasClrHeader
                if($ExpectedArchitecture -and $info.architecture -ine $ExpectedArchitecture){Finding 'ArchitectureMismatch' "$relative has PE machine $($info.architecture); expected $ExpectedArchitecture."}
                $info.fileVersion=[Diagnostics.FileVersionInfo]::GetVersionInfo($entry.FullName).FileVersion
            }
        }
        $files.Add([pscustomobject]$info)
        if($expected.ContainsKey($relative)){
            if($null -ne $hash -and $expected[$relative].sha256 -and $expected[$relative].sha256 -ine $hash){Finding 'HashMismatch' "SHA256 mismatch: $relative"}
        }elseif($ManifestPath -and $entry.FullName -ine $manifestFull){Finding 'UnexpectedFile' "Unexpected file: $relative" $(if($Strict){'Error'}else{'Warning'})}
    }
    foreach($key in $expected.Keys){if(-not $actual.Contains($key)){Finding $(if($expected[$key].required){'MissingRequiredFile'}else{'MissingOptionalFile'}) "Missing file: $key" $(if($expected[$key].required){'Error'}else{'Information'})}}
    if ($hashBudgeted -and -not $budgetExceeded) { $result.hashCoverage='Complete' }
}catch{Finding 'InvalidPackage' $_.Exception.Message}
$result.files=@($files.ToArray());$result.findings=@($findings.ToArray());$result.valid=@($findings | Where-Object severity -eq 'Error').Count -eq 0
$global:LASTEXITCODE=if($result.valid){0}else{2}
if($Json){$result | ConvertTo-Json -Depth 12}else{[pscustomobject]$result}
