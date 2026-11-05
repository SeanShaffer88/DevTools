#requires -Version 7.0
<#
.SYNOPSIS
Searches original, locally stored DevTools operational notes without network access.
.PARAMETER Query
Case-insensitive literal text to find in titles, tags, and note text.
.PARAMETER Resources
Search resources/index.json versioned original notes/recipes instead of the original six-note library.
.NOTES
Reads the selected references/index.json or resources/index.json and contained text files only; never fetches upstream
links. This library is operational notes, not a complete offline SDK mirror.
#>
[CmdletBinding()]
param([ValidateLength(0,256)][string]$Query,[ValidateSet('Dll','Wow','Android','Packaging','Templates','Toolkit','Runtime','Sdk','Dependencies','Crash','Contracts','Installer','Build','Fixtures','Cache','Recipes')][string]$Category,[switch]$Resources,[switch]$Json)
$ErrorActionPreference='Stop'
$result=[ordered]@{schemaVersion=1;observedUtc=[DateTime]::UtcNow.ToString('o');valid=$false;query=$Query;category=$Category;matches=@();error=$null;networkAccess='NotPerformed'}
function No-Reparse([string]$Path){$part=$Path;while($part){if(Test-Path -LiteralPath $part){$item=Get-Item -LiteralPath $part -Force;if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw "Reparse point not allowed: $part"}};$parent=[IO.Path]::GetDirectoryName($part);if($parent -eq $part){break};$part=$parent}}
try{
    $root=Join-Path $PSScriptRoot $(if($Resources){'resources'}else{'references'});$prefix=[IO.Path]::GetFullPath($root)+[IO.Path]::DirectorySeparatorChar
    $indexPath=Join-Path $root 'index.json';No-Reparse $indexPath
    if((Get-Item -LiteralPath $indexPath).Length -gt 262144){throw 'Reference index exceeds 256 KiB.'}
    $index=Get-Content -LiteralPath $indexPath -Raw | ConvertFrom-Json
    if($index.schemaVersion -ne 1 -or $index.entries -isnot [array] -or $index.entries.Count -gt 128){throw 'Invalid or oversized reference index.'}
    $matches=[Collections.Generic.List[object]]::new();$bytesRead=0
    foreach($entry in $index.entries){
        foreach($field in @('id','title','category','path','source','capturedUtc','versionScope','verification')){if([string]::IsNullOrWhiteSpace([string]$entry.$field)){throw "Reference entry missing $field."}}
        if($entry.category -notin @('Dll','Wow','Android','Packaging','Templates','Toolkit','Runtime','Sdk','Dependencies','Crash','Contracts','Installer','Build','Fixtures','Cache','Recipes')){throw 'Invalid reference category.'}
        if($entry.path -isnot [string] -or [IO.Path]::IsPathRooted($entry.path) -or $entry.path -match '[:*?\[\]]' -or '..' -in $entry.path.Replace('\','/').Split('/')){throw 'Unsafe reference path.'}
        $path=[IO.Path]::GetFullPath((Join-Path $root $entry.path));if(-not $path.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw 'Reference path escapes library.'};No-Reparse $path
        $file=Get-Item -LiteralPath $path;if($file.PSIsContainer -or $file.Length -gt 65536){throw 'Reference note must be a file no larger than 64 KiB.'}
        $bytesRead+=$file.Length;if($bytesRead -gt 1048576){throw 'Reference library exceeds 1 MiB read budget.'}
        $content=[IO.File]::ReadAllText($path)
        if($Category -and $entry.category -ine $Category){continue}
        $search=$entry.title+' '+(@($entry.tags)-join ' ')+' '+$content
        if($Query -and $search.IndexOf($Query,[StringComparison]::OrdinalIgnoreCase) -lt 0){continue}
        $matches.Add([pscustomobject]@{id=$entry.id;title=$entry.title;category=$entry.category;tags=@($entry.tags);path=$path;source=$entry.source;capturedUtc=$entry.capturedUtc;versionScope=$entry.versionScope;verification=$entry.verification;content=$content})
    }
    $result.matches=@($matches.ToArray());$result.valid=$true;$global:LASTEXITCODE=0
}catch{$result.error=$_.Exception.Message;$global:LASTEXITCODE=2}
if($Json){$result | ConvertTo-Json -Depth 10}else{[pscustomobject]$result}
