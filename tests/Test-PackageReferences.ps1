#requires -Version 7.0
[CmdletBinding()]
param([string]$WorkRoot='C:\Users\Sean Shaffer\Documents\Codex\2026-11-03\a\work', [string]$EvidenceDirectory)
$ErrorActionPreference='Stop'
$evidencePath=& (Join-Path $PSScriptRoot 'Resolve-SuiteEvidencePath.ps1') 'validation-package-references.json' $EvidenceDirectory ($PSBoundParameters.ContainsKey('EvidenceDirectory'))
$toolRoot=Split-Path $PSScriptRoot -Parent;$fixture=Join-Path $WorkRoot ('package-reference-'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $fixture
$checks=[Collections.Generic.List[object]]::new();$skipped=[Collections.Generic.List[string]]::new()
function Assert([bool]$Condition,[string]$Name){if(-not $Condition){throw "FAILED: $Name"};$checks.Add([pscustomobject]@{name=$Name;passed=$true})}
function Save-Manifest([object]$Value){$Value | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $manifest -Encoding utf8}
function Check-Package([string]$Arch='',[switch]$Strict){$args=@{PackagePath=$package;ManifestPath=$manifest;Json=$true};if($Arch){$args.ExpectedArchitecture=$Arch};if($Strict){$args.Strict=$true};& (Join-Path $toolRoot 'Test-Package.ps1') @args | ConvertFrom-Json}
$exitCode=1;$failure=$null
try{
    foreach($name in @('Test-Package.ps1','Get-DevReference.ps1')){$tokens=$null;$errors=$null;$null=[Management.Automation.Language.Parser]::ParseFile((Join-Path $toolRoot $name),[ref]$tokens,[ref]$errors);Assert ($errors.Count -eq 0) "AST $name"}
    $package=Join-Path $fixture 'Package With Spaces';$null=New-Item -ItemType Directory -Path (Join-Path $package 'data')
    $data=Join-Path $package 'data\config.json';[IO.File]::WriteAllText($data,'{"example":true}')
    $hash=(Get-FileHash -LiteralPath $data).Hash;$manifest=Join-Path $package 'package-manifest.json'
    Save-Manifest @{schemaVersion=1;files=@(@{path='data/config.json';sha256=$hash})}
    $before=(Get-FileHash -LiteralPath $data).Hash
    $r=Check-Package -Strict;Assert ($r.valid -and $r.files.Count -eq 2 -and $global:LASTEXITCODE -eq 0) 'Valid package/hash/Strict and self-manifest exclusion'
    Assert ($before -eq (Get-FileHash -LiteralPath $data).Hash) 'Package inspection leaves payload unchanged'
    Assert ($r.installerUpgrade -eq 'NotPerformed' -and $r.settingsPreservation -eq 'NotPerformed' -and $r.signatureVerification -eq 'NotPerformed') 'Unperformed installer/runtime checks explicit'
    Save-Manifest @{schemaVersion=1;files=@(@{path='data/config.json';sha256=('0'*64)})}
    $r=Check-Package;Assert (-not $r.valid -and 'HashMismatch' -in $r.findings.code -and $global:LASTEXITCODE -eq 2) 'Hash mismatch fails with exit 2'
    Save-Manifest @{schemaVersion=1;files=@(@{path='missing.txt'})}
    $r=Check-Package;Assert (-not $r.valid -and 'MissingRequiredFile' -in $r.findings.code) 'Required file defaults true and missing fails'
    Save-Manifest @{schemaVersion=1;files=@(@{path='optional.txt';required=$false})}
    $r=Check-Package;Assert ($r.valid -and 'MissingOptionalFile' -in $r.findings.code -and 'UnexpectedFile' -in $r.findings.code) 'Optional missing informational and unexpected warning'
    $r=Check-Package -Strict;Assert (-not $r.valid -and @($r.findings | Where-Object {$_.code -eq 'UnexpectedFile' -and $_.severity -eq 'Error'}).Count -gt 0) 'Strict unexpected file fails'
    $r=& (Join-Path $toolRoot 'Test-Package.ps1') -PackagePath $package -Strict -Json | ConvertFrom-Json;Assert (-not $r.valid) 'Strict requires manifest'
    foreach($invalid in @(
        @{schemaVersion='1';files=@()},@{schemaVersion=2;files=@()},@{schemaVersion=1;files='bad'},@{schemaVersion=1;files=@();unknown=1},
        @{schemaVersion=1;files=@(@{path='data/config.json';required='true'})},@{schemaVersion=1;files=@(@{path='data/config.json';sha256='BAD'})},
        @{schemaVersion=1;files=@(@{path='data/config.json';unknown=1})},@{schemaVersion=1;files=@('plain')})){
        Save-Manifest $invalid;$r=Check-Package;Assert (-not $r.valid -and $r.files.Count -eq 0) 'Malformed manifest rejected before hashing'
    }
    Save-Manifest @{schemaVersion=1;files=@(@{path='data/config.json'},@{path='DATA\CONFIG.JSON'})}
    $r=Check-Package;Assert (-not $r.valid -and $r.files.Count -eq 0) 'Case-insensitive normalized duplicate rejected before hashing'
    foreach($unsafe in @('..\escape.txt','data/../config.json','C:\Windows\win.ini','data/config.json:stream','data/*.json','data/[x].json','data/config.json.','data//config.json','data/CON.json','NUL')){
        Save-Manifest @{schemaVersion=1;files=@(@{path=$unsafe})};$r=Check-Package;Assert (-not $r.valid -and $r.files.Count -eq 0) "Unsafe manifest path rejected: $unsafe"
    }
    [IO.File]::WriteAllText($manifest,'not json');$r=Check-Package;Assert (-not $r.valid) 'Invalid JSON rejected'
    [IO.File]::WriteAllBytes($manifest,[Text.Encoding]::ASCII.GetBytes('{"schemaVersion":1,"files":[{"path":"data/')+[byte[]](0xC3,0x28)+[Text.Encoding]::ASCII.GetBytes('.json"}]}'));$r=Check-Package;Assert (-not $r.valid -and $r.files.Count -eq 0) 'Invalid UTF-8 manifest rejected before hashing'
    $r=& (Join-Path $toolRoot 'Test-Package.ps1') -PackagePath (Join-Path $fixture 'missing') -Json | ConvertFrom-Json;Assert (-not $r.valid -and $r.findings[0].message -notmatch [regex]::Escape([Environment]::GetFolderPath('UserProfile'))) 'Package error messages redact profile path'
    Copy-Item -LiteralPath 'C:\Windows\System32\kernel32.dll' -Destination (Join-Path $package 'native.dll')
    Save-Manifest @{schemaVersion=1;files=@(@{path='data/config.json'},@{path='native.dll'})}
    $r=Check-Package 'x64';Assert ($r.valid -and ($r.files | Where-Object path -eq 'native.dll').architecture -eq 'x64') 'PE machine architecture and version metadata inspection'
    $r=Check-Package 'x86';Assert (-not $r.valid -and 'ArchitectureMismatch' -in $r.findings.code) 'Explicit architecture mismatch fails'
    [IO.File]::WriteAllText((Join-Path $package 'broken.dll'),'not PE');$r=Check-Package;Assert (-not $r.valid -and 'InvalidPe' -in $r.findings.code) 'Malformed packaged PE reported'
    try{
        $outside=Join-Path $fixture 'Outside';$null=New-Item -ItemType Directory -Path $outside;[IO.File]::WriteAllText((Join-Path $outside 'private.txt'),'outside')
        $null=New-Item -ItemType Junction -Path (Join-Path $package 'link') -Target $outside
        Save-Manifest @{schemaVersion=1;files=@(@{path='link/private.txt'})};$r=Check-Package;Assert (-not $r.valid -and $r.files.Count -eq 0) 'Manifest reparse escape rejected before hashing'
        $r=& (Join-Path $toolRoot 'Test-Package.ps1') -PackagePath $package -Json | ConvertFrom-Json
        Assert (-not $r.valid -and 'ReparsePoint' -in $r.findings.code -and 'link\private.txt' -notin $r.files.path) 'Inventory skips reparse content and reports failure'
    }catch{if($_.Exception.Message.StartsWith('FAILED:')){throw};$skipped.Add('Junction test unavailable: '+$_.Exception.Message)}
    $r=& (Join-Path $toolRoot 'Get-DevReference.ps1') -Json | ConvertFrom-Json
    Assert ($r.valid -and $r.matches.Count -eq 6 -and $r.networkAccess -eq 'NotPerformed') 'Reference library index and all original notes readable offline'
    $r=& (Join-Path $toolRoot 'Get-DevReference.ps1') -Query 'sha256' -Category Packaging -Json | ConvertFrom-Json
    Assert ($r.valid -and $r.matches.Count -eq 1 -and $r.matches[0].id -eq 'package-manifest' -and $r.matches[0].content.Contains('required')) 'Literal case-insensitive category search returns original note content'
    $r=& (Join-Path $toolRoot 'Get-DevReference.ps1') -Query 'NoSuchReference-42' -Json | ConvertFrom-Json;Assert ($r.valid -and $r.matches.Count -eq 0) 'Unknown reference query empty success'
    foreach($entry in (& (Join-Path $toolRoot 'Get-DevReference.ps1')).matches){Assert ([bool]$entry.source -and [bool]$entry.capturedUtc -and [bool]$entry.versionScope -and [bool]$entry.verification) "Reference provenance: $($entry.id)"}
    $copy=Join-Path $fixture 'ReferenceClone';$null=New-Item -ItemType Directory -Path (Join-Path $copy 'references'),(Join-Path $copy 'lib')
    Copy-Item -LiteralPath (Join-Path $toolRoot 'Get-DevReference.ps1') -Destination $copy
    Copy-Item -LiteralPath (Join-Path $toolRoot 'lib\DevToolsCommon.psm1') -Destination (Join-Path $copy 'lib')
    $index=Get-Content -LiteralPath (Join-Path $toolRoot 'references\index.json') -Raw | ConvertFrom-Json
    $first=$index.entries[0].path;Copy-Item -LiteralPath (Join-Path $toolRoot "references\$first") -Destination (Join-Path $copy "references\$first")
    $index.entries=@($index.entries[0]);$index | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $copy 'references\index.json')
    $r=& (Join-Path $copy 'Get-DevReference.ps1') -Json | ConvertFrom-Json;Assert ($r.valid -and $r.matches.Count -eq 1) 'Reference clone loads shared module'
    $index.entries[0].path='../outside.txt'
    $index | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $copy 'references\index.json')
    $r=& (Join-Path $copy 'Get-DevReference.ps1') -Json | ConvertFrom-Json;Assert (-not $r.valid -and $r.matches.Count -eq 0 -and $r.error -eq 'Unsafe reference path.') 'Reference traversal rejected'
    $index.entries[0].path='oversized.md';[IO.File]::WriteAllText((Join-Path $copy 'references\oversized.md'),('x'*65537))
    $index | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $copy 'references\index.json')
    $r=& (Join-Path $copy 'Get-DevReference.ps1') -Json | ConvertFrom-Json;Assert (-not $r.valid -and $r.error -eq 'Reference note must be a file no larger than 64 KiB.') 'Reference note size bound enforced'
    $index.entries[0].path="$first.";$index | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $copy 'references\index.json')
    $r=& (Join-Path $copy 'Get-DevReference.ps1') -Json | ConvertFrom-Json;Assert (-not $r.valid) 'Reference trailing-dot alias rejected'
    [IO.File]::WriteAllBytes((Join-Path $copy 'references\bad.md'),[byte[]](0x61,0xC3,0x28));$index.entries[0].path='bad.md';$index | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $copy 'references\index.json')
    $r=& (Join-Path $copy 'Get-DevReference.ps1') -Json | ConvertFrom-Json;Assert (-not $r.valid) 'Reference invalid UTF-8 note rejected'
    $index.entries[0].path='missing.md';$index | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $copy 'references\index.json')
    $r=& (Join-Path $copy 'Get-DevReference.ps1') -Json | ConvertFrom-Json;Assert (-not $r.valid -and $r.error -notmatch [regex]::Escape([Environment]::GetFolderPath('UserProfile'))) 'Reference error messages redact profile path'
    $exitCode=0
}catch{$failure=$_.Exception.Message;Write-Error $failure -ErrorAction Continue}
$evidence=[ordered]@{schemaVersion=1;observedUtc=[DateTime]::UtcNow.ToString('o');command="pwsh -NoProfile -File '$PSCommandPath'";exitCode=$exitCode;fixturePath=$fixture;checks=@($checks.ToArray());skipped=@($skipped.ToArray());failure=$failure;limitations=@('Installer upgrade/settings/runtime behavior not tested.','Package architecture compares PE machine fields; not a complete managed runtime policy.','Reference library is original local notes and pointers, not an SDK mirror.')}
$evidence | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $evidencePath -Encoding utf8
Write-Output "$($checks.Count) checks passed; $($skipped.Count) skipped; exit $exitCode; fixtures $fixture"
exit $exitCode
