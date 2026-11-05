#requires -Version 7.0
<#
.SYNOPSIS
Reads native PE headers, exports and imports without loading the inspected file.
.PARAMETER Path
Literal PE file path. EXE and managed PE images are also accepted.
.PARAMETER CompareTo
Optional baseline image for export identity and architecture comparison.
.NOTES
Read-only. Export comparison is not ABI certification. Delay imports, CLR APIs,
signature trust and dependency resolution are not inspected. LASTEXITCODE is 0 or 2.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Path,[string]$CompareTo,[switch]$Json)
$ErrorActionPreference='Stop'
$result=[ordered]@{schemaVersion=1;observedUtc=[DateTime]::UtcNow.ToString('o');valid=$false;image=$null;comparison=$null;error=$null;limitations=@('Export identities do not establish ABI compatibility.','Delay imports, managed APIs, dependency resolution, and signature trust are not checked.')}
try {
    if (-not ('LocalDevTools.PeInspector' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'lib\PeInspector.cs') }
    $item=Get-Item -LiteralPath $Path -ErrorAction Stop
    if ($item.PSIsContainer) { throw 'Path must be a file.' }
    $result.image=[LocalDevTools.PeInspector]::Inspect($item.FullName)
    if ($CompareTo) {
        $baseline=Get-Item -LiteralPath $CompareTo -ErrorAction Stop
        if ($baseline.PSIsContainer) {throw 'CompareTo must be a file.'}
        $before=[LocalDevTools.PeInspector]::Inspect($baseline.FullName)
        $old=@($before.Exports | ForEach-Object {"$($_.Ordinal):$($_.Name)"})
        $new=@($result.image.Exports | ForEach-Object {"$($_.Ordinal):$($_.Name)"})
        $result.comparison=[ordered]@{baselinePath=$baseline.FullName;architectureChanged=$before.Architecture -cne $result.image.Architecture;addedExports=@($new | Where-Object {$_ -cnotin $old});removedExports=@($old | Where-Object {$_ -cnotin $new});abiCompatibility='NotEstablished'}
    }
    $result.valid=$true; $global:LASTEXITCODE=0
} catch {$result.error=$_.Exception.Message; $global:LASTEXITCODE=2}
if($Json){$result | ConvertTo-Json -Depth 12}else{[pscustomobject]$result}
