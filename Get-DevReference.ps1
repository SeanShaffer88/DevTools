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
Uses lib/DevToolsCommon.psm1 for contained paths, bounded strict-UTF-8 reads and error redaction.
The index and notes must be valid UTF-8.
#>
[CmdletBinding()]
param([ValidateLength(0,256)][string]$Query,[ValidateSet('Dll','Wow','Android','Packaging','Templates','Toolkit','Runtime','Sdk','Dependencies','Crash','Contracts','Installer','Build','Fixtures','Cache','Recipes')][string]$Category,[switch]$Resources,[switch]$Json)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'lib\DevToolsCommon.psm1') -Force
$CATEGORIES=@('Dll','Wow','Android','Packaging','Templates','Toolkit','Runtime','Sdk','Dependencies','Crash','Contracts','Installer','Build','Fixtures','Cache','Recipes')
$MAX_INDEX_BYTES=262144
$MAX_NOTE_BYTES=65536
$MAX_TOTAL_BYTES=1048576
$MAX_ENTRIES=128
$result=[ordered]@{schemaVersion=1;observedUtc=[DateTime]::UtcNow.ToString('o');valid=$false;query=$Query;category=$Category;matches=@();error=$null;networkAccess='NotPerformed'}
try{
    $root=Resolve-DtLocalPath -Path (Join-Path $PSScriptRoot $(if($Resources){'resources'}else{'references'})) -Kind Directory
    $indexPath=Resolve-DtContainedPath -Root $root -RelativePath 'index.json' -Kind File
    if([IO.FileInfo]::new($indexPath).Length -gt $MAX_INDEX_BYTES){throw 'Reference index exceeds 256 KiB.'}
    $index=Read-DtJson -Path $indexPath -MaxBytes $MAX_INDEX_BYTES -Depth 10
    $valid=$index['entries'] -is [array] -and $index['entries'].Count -le $MAX_ENTRIES
    if($valid){try{$null=Assert-DtInteger -Value $index['schemaVersion'] -Minimum 1 -Maximum 1 -Name 'schemaVersion'}catch{$valid=$false}}
    if(-not $valid){throw 'Invalid or oversized reference index.'}
    $matches=[Collections.Generic.List[object]]::new();$bytesRead=0
    foreach($entry in $index.entries){
        if($entry -isnot [Collections.IDictionary]){throw 'Invalid reference entry.'}
        foreach($field in @('id','title','category','path','source','capturedUtc','versionScope','verification')){if([string]::IsNullOrWhiteSpace([string]$entry[$field])){throw "Reference entry missing $field."}}
        if($entry.category -notin $CATEGORIES){throw 'Invalid reference category.'}
        if($entry.path -isnot [string] -or [IO.Path]::IsPathRooted($entry.path) -or $entry.path -match '[:*?\[\]]' -or '..' -in $entry.path.Replace('\','/').Split('/')){throw 'Unsafe reference path.'}
        try{$path=Resolve-DtContainedPath -Root $root -RelativePath $entry.path -Kind File}
        catch{throw "Unsafe or missing reference path: $($_.Exception.Message)"}
        $length=[IO.FileInfo]::new($path).Length
        if($length -gt $MAX_NOTE_BYTES){throw 'Reference note must be a file no larger than 64 KiB.'}
        $bytesRead+=$length;if($bytesRead -gt $MAX_TOTAL_BYTES){throw 'Reference library exceeds 1 MiB read budget.'}
        $content=Read-DtText -Path $path -MaxBytes $MAX_NOTE_BYTES
        if($Category -and $entry.category -ine $Category){continue}
        $search=$entry.title+' '+(@($entry.tags)-join ' ')+' '+$content
        if($Query -and $search.IndexOf($Query,[StringComparison]::OrdinalIgnoreCase) -lt 0){continue}
        $matches.Add([pscustomobject]@{id=$entry.id;title=$entry.title;category=$entry.category;tags=@($entry.tags);path=$path;source=$entry.source;capturedUtc=$entry.capturedUtc;versionScope=$entry.versionScope;verification=$entry.verification;content=$content})
    }
    $result.matches=@($matches.ToArray());$result.valid=$true;$global:LASTEXITCODE=0
}catch{$result.error=Protect-DtText $_.Exception.Message;$global:LASTEXITCODE=2}
if($Json){$result | ConvertTo-Json -Depth 10}else{[pscustomobject]$result}
