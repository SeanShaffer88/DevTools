# Private reliability support; dot-sourcing performs no system operations.
. (Join-Path $PSScriptRoot 'QualityCommon.ps1')
function Assert-RNPath([string]$Path) {
 if([string]::IsNullOrWhiteSpace($Path) -or $Path.Length -gt 4096 -or $Path -match '[\x00-\x1f*?]' -or $Path -match '(^|[\\/])\.\.([\\/]|$)' -or $Path -match '^[\\/]{2}' -or ($Path -replace '^[A-Za-z]:[\\/]','') -match ':'){throw 'Invalid local path.'}
 Assert-QPath $Path
}
function Finish-RN($Result,[int]$Code,[switch]$Json) {
 $Result.status=switch($Code){0{'Pass'}2{'Fail'}3{'Unknown'}default{'SetupError'}}
 $Result.valid=$Code -eq 0
 Complete-QResult $Result -Json:$Json
 exit $Code
}
