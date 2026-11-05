#requires -Version 7.0
<#
.SYNOPSIS
Checks a local package folder, optional file manifest, and explicit PE architecture.
.PARAMETER ManifestPath
JSON schemaVersion 1 and files array: path, optional Boolean required, optional SHA256.
.PARAMETER Strict
Treat unexpected payload files as errors. Requires ManifestPath. The manifest itself is excluded from unexpected files.
.PARAMETER MaxHashBytes
Optional cumulative byte limit for file hashes. Zero permits only empty files. A skipped file makes the result incomplete and returns exit 2.
.NOTES
Read-only. Does not execute installers or validate upgrades, signatures, runtime
dependencies, or settings preservation. ExpectedArchitecture compares PE machine headers.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$PackagePath,[string]$ManifestPath,[ValidateSet('x86','x64','Arm64')][string]$ExpectedArchitecture,[switch]$Strict,[switch]$Json,[ValidateRange('NonNegative')][long]$MaxHashBytes)
$ErrorActionPreference='Stop'
$files=[Collections.Generic.List[object]]::new();$findings=[Collections.Generic.List[object]]::new()
$expected=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::OrdinalIgnoreCase)
$result=[ordered]@{schemaVersion=1;observedUtc=[DateTime]::UtcNow.ToString('o');valid=$false;packagePath=$null;manifestPath=$null;strict=[bool]$Strict;expectedArchitecture=$ExpectedArchitecture;files=@();findings=@();installerUpgrade='NotPerformed';settingsPreservation='NotPerformed';runtimeDependencies='NotPerformed';signatureVerification='NotPerformed';limits=@{entries=10000;depth=32;manifestBytes=2097152}}
$hashBudgeted=$PSBoundParameters.ContainsKey('MaxHashBytes')
$budgetExceeded=$false
if ($hashBudgeted) {
    $result.limits.maxHashBytes=$MaxHashBytes
    $result.hashedBytes=0L
    $result.hashCoverage='Incomplete'
}
function Finding([string]$Code,[string]$Message,[string]$Severity='Error'){$findings.Add([pscustomobject]@{code=$Code;severity=$Severity;message=$Message})}
function No-Reparse([string]$Path){
    $part=$Path
    while($part){
        if(Test-Path -LiteralPath $part){$entry=Get-Item -LiteralPath $part -Force;if(($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw "Reparse point not permitted: $part"}}
        $parent=[IO.Path]::GetDirectoryName($part);if($parent -eq $part){break};$part=$parent
    }
}
function Manifest-File([string]$Value){
    if([string]::IsNullOrWhiteSpace($Value) -or [IO.Path]::IsPathRooted($Value) -or $Value.IndexOfAny([char[]]':*?[]') -ge 0){throw "Invalid manifest file path: $Value"}
    $parts=$Value.Replace('\','/').Split('/')
    foreach($part in $parts){if($part -in @('','.','..') -or $part.TrimEnd(' ','.') -cne $part){throw "Ambiguous or traversing manifest file path: $Value"}}
    $full=[IO.Path]::GetFullPath((Join-Path $root ($parts -join [IO.Path]::DirectorySeparatorChar)))
    if(-not $full.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw 'Manifest path escapes package root.'}
    No-Reparse $full
    return [IO.Path]::GetRelativePath($root,$full)
}
try{
    $item=Get-Item -LiteralPath $PackagePath -Force;if(-not $item.PSIsContainer){throw 'PackagePath must be a directory.'}
    $root=[IO.Path]::GetFullPath($item.FullName).TrimEnd([IO.Path]::DirectorySeparatorChar);$prefix=$root+[IO.Path]::DirectorySeparatorChar
    No-Reparse $root;$result.packagePath=$root
    if($Strict -and -not $ManifestPath){throw '-Strict requires -ManifestPath.'}
    $manifestFull=$null
    if($ManifestPath){
        $manifestItem=Get-Item -LiteralPath $ManifestPath -Force
        if($manifestItem.PSIsContainer -or $manifestItem.Length -gt 2097152){throw 'Manifest must be a file no larger than 2 MiB.'}
        No-Reparse $manifestItem.FullName;$manifestFull=$manifestItem.FullName;$result.manifestPath=$manifestFull
        $manifest=Get-Content -LiteralPath $manifestFull -Raw | ConvertFrom-Json -AsHashtable -Depth 20
        if($manifest -isnot [Collections.IDictionary] -or $manifest.schemaVersion -isnot [long] -and $manifest.schemaVersion -isnot [int] -or $manifest.schemaVersion -ne 1 -or $manifest.files -isnot [array]){throw 'Manifest requires integer schemaVersion 1 and a files array.'}
        if(@($manifest.Keys | Where-Object {$_ -notin @('schemaVersion','files')}).Count){throw 'Manifest has unknown root fields.'}
        foreach($entry in $manifest.files){
            if($entry -isnot [Collections.IDictionary] -or $entry.path -isnot [string]){throw 'Each manifest file must be an object with a string path.'}
            if(@($entry.Keys | Where-Object {$_ -notin @('path','required','sha256')}).Count){throw 'Manifest file has unknown fields.'}
            if($entry.Contains('required') -and $entry.required -isnot [bool]){throw 'Manifest required must be Boolean.'}
            if($entry.Contains('sha256') -and ($entry.sha256 -isnot [string] -or $entry.sha256 -notmatch '^[0-9a-fA-F]{64}$')){throw 'Manifest SHA256 must be 64 hexadecimal characters.'}
            $relative=Manifest-File $entry.path
            if($expected.ContainsKey($relative)){throw "Duplicate manifest path: $relative"}
            $expected.Add($relative,[pscustomobject]@{required=if($entry.Contains('required')){$entry.required}else{$true};sha256=$entry.sha256})
        }
    }
    $queue=[Collections.Generic.Queue[object]]::new();$queue.Enqueue([pscustomobject]@{path=$root;depth=0});$entryCount=0
    $actual=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    while($queue.Count){
        $dir=$queue.Dequeue()
        foreach($entryPath in [IO.Directory]::EnumerateFileSystemEntries($dir.path)){
            if(++$entryCount -gt 10000){throw 'Package inventory exceeds 10000 entries.'}
            $entry=Get-Item -LiteralPath $entryPath -Force
            if(($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){Finding 'ReparsePoint' "Skipped reparse point: $([IO.Path]::GetRelativePath($root,$entry.FullName))";continue}
            if($entry.PSIsContainer){if($dir.depth -ge 32){throw 'Package inventory exceeds depth 32.'};$queue.Enqueue([pscustomobject]@{path=$entry.FullName;depth=$dir.depth+1});continue}
            $relative=[IO.Path]::GetRelativePath($root,$entry.FullName);$null=$actual.Add($relative)
            if ($hashBudgeted) {
                $stream=[IO.File]::Open($entry.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
                try {
                    $size=$stream.Length
                    $hash=$null
                    if ($size -gt $MaxHashBytes - $result.hashedBytes) {
                        $budgetExceeded=$true
                        Finding 'HashBudgetExceeded' "Skipped hash and PE inspection for $relative because its size exceeds the remaining hash budget."
                    } else {
                        $hash=(Get-FileHash -InputStream $stream -Algorithm SHA256).Hash
                        $result.hashedBytes+=$size
                    }
                } finally { $stream.Dispose() }
            } else {
                $hash=(Get-FileHash -LiteralPath $entry.FullName -Algorithm SHA256).Hash
                $size=$entry.Length
            }
            $info=[ordered]@{path=$relative;size=$size;sha256=$hash;architecture=$null;hasClrHeader=$null;fileVersion=$null}
            if($null -ne $hash -and $entry.Extension -in @('.exe','.dll')){
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
    }
    foreach($key in $expected.Keys){if(-not $actual.Contains($key)){Finding $(if($expected[$key].required){'MissingRequiredFile'}else{'MissingOptionalFile'}) "Missing file: $key" $(if($expected[$key].required){'Error'}else{'Information'})}}
    if ($hashBudgeted -and -not $budgetExceeded) { $result.hashCoverage='Complete' }
}catch{Finding 'InvalidPackage' $_.Exception.Message}
$result.files=@($files.ToArray());$result.findings=@($findings.ToArray());$result.valid=@($findings | Where-Object severity -eq 'Error').Count -eq 0
$global:LASTEXITCODE=if($result.valid){0}else{2}
if($Json){$result | ConvertTo-Json -Depth 12}else{[pscustomobject]$result}
