#requires -Version 7.0
[CmdletBinding()]
param([string]$WorkRoot='C:\Users\Sean Shaffer\Documents\Codex\2026-11-03\a\work', [string]$EvidenceDirectory)
$ErrorActionPreference='Stop'
$evidencePath=& (Join-Path $PSScriptRoot 'Resolve-SuiteEvidencePath.ps1') 'validation-binary-addon.json' $EvidenceDirectory ($PSBoundParameters.ContainsKey('EvidenceDirectory'))
$toolRoot=Split-Path $PSScriptRoot -Parent
$fixture=Join-Path $WorkRoot ('binary-addon-'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $fixture
$checks=[Collections.Generic.List[object]]::new()
$skipped=[Collections.Generic.List[string]]::new()
function Assert([bool]$Condition,[string]$Name){if(-not $Condition){throw "FAILED: $Name"};$checks.Add([pscustomobject]@{name=$Name;passed=$true})}
function Write-Text([string]$Path,[string]$Text){[IO.File]::WriteAllText($Path,$Text)}
function New-Pe([string]$Path,[bool]$Plus=$false,[string]$ExportName='Example'){
    $memory=[IO.MemoryStream]::new([byte[]]::new(4608),$true);$w=[IO.BinaryWriter]::new($memory)
    function U16([long]$At,[uint16]$Value){$memory.Position=$At;$w.Write($Value)}
    function U32([long]$At,[uint32]$Value){$memory.Position=$At;$w.Write($Value)}
    function U64([long]$At,[uint64]$Value){$memory.Position=$At;$w.Write($Value)}
    function Str([long]$At,[string]$Value){$memory.Position=$At;$w.Write([Text.Encoding]::ASCII.GetBytes($Value));$w.Write([byte]0)}
    U16 0 0x5a4d;U32 0x3c 0x80;U32 0x80 0x4550;U16 0x84 $(if($Plus){0x8664}else{0x14c});U16 0x86 1
    $optSize=if($Plus){0xf0}else{0xe0};U16 0x94 $optSize;U16 0x96 0x2002
    $opt=0x98;U16 $opt $(if($Plus){0x20b}else{0x10b});U32 ($opt+60) 0x200
    $dir=if($Plus){112}else{96};U32 ($opt+$dir-4) 16
    U32 ($opt+$dir) 0x1000;U32 ($opt+$dir+4) 0x100;U32 ($opt+$dir+8) 0x1100;U32 ($opt+$dir+12) 40
    $sec=$opt+$optSize;Str $sec '.rdata';U32 ($sec+8) 0x1000;U32 ($sec+12) 0x1000;U32 ($sec+16) 0x1000;U32 ($sec+20) 0x200
    U32 0x210 1;U32 0x214 2;U32 0x218 1;U32 0x21c 0x1060;U32 0x220 0x1040;U32 0x224 0x1050
    U32 0x240 0x1070;U16 0x250 0;U32 0x260 0x1300;U32 0x264 0x10a0;Str 0x270 $ExportName;Str 0x2a0 'KERNEL32.Sleep'
    U32 0x300 0x1200;U32 0x30c 0x1180;U32 0x310 0x1220;Str 0x380 'KERNEL32.dll'
    if($Plus){U64 0x400 0x1240;U64 0x408 ([uint64]::Parse('8000000000000007',[Globalization.NumberStyles]::HexNumber))}else{U32 0x400 0x1240;U32 0x404 ([uint32]::Parse('80000007',[Globalization.NumberStyles]::HexNumber))}
    U16 0x440 0;Str 0x442 'Sleep';$memory.Position=0x500;$w.Write([byte]0xc3)
    [IO.File]::WriteAllBytes($Path,$memory.ToArray());$w.Dispose();$memory.Dispose()
}
function Wow([string]$Path,[string]$Toc='',[int]$Version=0){
    $args=@{AddonPath=$Path;Json=$true};if($Toc){$args.TocPath=$Toc};if($Version){$args.InterfaceVersion=$Version}
    & (Join-Path $toolRoot 'Test-WowAddon.ps1') @args | ConvertFrom-Json
}
$exitCode=1;$failure=$null
try{
    foreach($name in @('Get-DllInfo.ps1','Test-WowAddon.ps1')){
        $tokens=$null;$errors=$null;$null=[Management.Automation.Language.Parser]::ParseFile((Join-Path $toolRoot $name),[ref]$tokens,[ref]$errors)
        Assert ($errors.Count -eq 0) "AST $name"
    }
    $real=& (Join-Path $toolRoot 'Get-DllInfo.ps1') -Path 'C:\Windows\System32\kernel32.dll' -Json | ConvertFrom-Json
    Assert ($real.valid -and $real.image.Exports.Count -gt 0) 'Real kernel32 inspected without loading target'
    $pe32=Join-Path $fixture 'sample x86.dll';$pe64=Join-Path $fixture 'sample x64.dll';New-Pe $pe32;New-Pe $pe64 $true 'Changed'
    foreach($file in @($pe32,$pe64)){
        $info=& (Join-Path $toolRoot 'Get-DllInfo.ps1') -Path $file -Json | ConvertFrom-Json
        Assert ($info.valid -and $info.image.Exports.Count -eq 2 -and $info.image.Imports.Count -eq 1) "Synthetic image tables: $([IO.Path]::GetFileName($file))"
        Assert ($info.image.Imports[0].Symbols[0].Name -eq 'Sleep' -and $info.image.Imports[0].Symbols[1].Ordinal -eq 7) "Named and ordinal imports: $($info.image.Format)"
        Assert ($info.image.Exports[1].Forwarder -eq 'KERNEL32.Sleep' -and $info.image.Exports[1].Ordinal -eq 2) "Ordinal forwarded export: $($info.image.Format)"
    }
    $comp=& (Join-Path $toolRoot 'Get-DllInfo.ps1') -Path $pe64 -CompareTo $pe32 -Json | ConvertFrom-Json
    Assert ($comp.comparison.architectureChanged -and $comp.comparison.addedExports.Count -eq 1 -and $comp.comparison.removedExports.Count -eq 1) 'Architecture and export comparison'
    $bss=Join-Path $fixture 'virtual-export.dll';$bytes=[IO.File]::ReadAllBytes($pe32)
    [BitConverter]::GetBytes([uint32]0x2000).CopyTo($bytes,0x180);[BitConverter]::GetBytes([uint32]0x2800).CopyTo($bytes,0x260);[IO.File]::WriteAllBytes($bss,$bytes)
    $r=& (Join-Path $toolRoot 'Get-DllInfo.ps1') -Path $bss -Json | ConvertFrom-Json
    Assert ($r.valid -and $r.image.Exports.Count -eq 2) 'Export target in zero-filled virtual section accepted'
    $bad=Join-Path $fixture 'bad.dll';[IO.File]::WriteAllBytes($bad,[byte[]](1,2,3))
    $r=& (Join-Path $toolRoot 'Get-DllInfo.ps1') -Path $bad -Json | ConvertFrom-Json
    Assert (-not $r.valid -and $global:LASTEXITCODE -eq 2) 'Truncated PE rejected with failure exit'
    $badRva=Join-Path $fixture 'bad-rva.dll';$bytes=[IO.File]::ReadAllBytes($pe32);[BitConverter]::GetBytes([uint32]0x7fffffff).CopyTo($bytes,0xf8);[IO.File]::WriteAllBytes($badRva,$bytes)
    $r=& (Join-Path $toolRoot 'Get-DllInfo.ps1') -Path $badRva -Json | ConvertFrom-Json
    Assert (-not $r.valid) 'Off-file export RVA rejected'
    $addon=Join-Path $fixture 'ExampleAddon';$null=New-Item -ItemType Directory -Path (Join-Path $addon 'ui')
    Write-Text (Join-Path $addon 'ExampleAddon.toc') "## Interface: 30300`n## Title: Example Addon`n## Dependencies: LibExample`nmain.lua`nui\main.xml`n"
    Write-Text (Join-Path $addon 'main.lua') '-- fixture'
    Write-Text (Join-Path $addon 'ui\main.xml') '<Ui><Include file="nested.xml"/></Ui>'
    Write-Text (Join-Path $addon 'ui\nested.xml') '<Ui><Script file="nested.lua"/></Ui>'
    Write-Text (Join-Path $addon 'ui\nested.lua') '-- nested'
    $before=@(Get-ChildItem -LiteralPath $addon -File -Recurse | ForEach-Object {"$($_.FullName):$((Get-FileHash -LiteralPath $_.FullName).Hash)"}) -join '|'
    $r=Wow $addon '' 30300
    Assert ($r.valid -and $r.loadOrder.Count -eq 4 -and $r.loadOrder[3].path -eq 'ui\nested.lua') 'Valid TOC and XML-relative nested load order'
    Assert ($r.declaredDependencies[0].name -eq 'LibExample' -and $r.luaSyntax -eq 'NotPerformed' -and $r.apiValidation -eq 'NotPerformed') 'Declared dependencies and runtime limits explicit'
    $after=@(Get-ChildItem -LiteralPath $addon -File -Recurse | ForEach-Object {"$($_.FullName):$((Get-FileHash -LiteralPath $_.FullName).Hash)"}) -join '|'
    Assert ($before -eq $after) 'Addon inspection leaves all files unchanged'
    $r=Wow $addon '' 30400;Assert (-not $r.valid -and 'InterfaceMismatch' -in $r.findings.code) 'Interface mismatch rejected'
    Write-Text (Join-Path $addon 'Second.toc') "## Interface: 30300`n## Title: Second`nmain.lua"
    $r=Wow $addon;Assert (-not $r.valid) 'Multiple TOCs require explicit selection'
    $r=Wow $addon 'ExampleAddon.toc';Assert $r.valid 'Explicit TOC selection'
    $empty=Join-Path $fixture 'EmptyAddon';$null=New-Item -ItemType Directory -Path $empty
    $r=Wow $empty;Assert (-not $r.valid) 'Missing TOC rejected'
    Write-Text (Join-Path $addon 'Second.toc') "## Interface: 30300`n## Title: Second`nmissing.lua"
    $r=Wow $addon 'Second.toc';Assert (-not $r.valid -and 'MissingFile' -in $r.findings.code) 'Missing referenced file rejected'
    Write-Text (Join-Path $addon 'Second.toc') "## Interface: nonsense`nmain.lua"
    $r=Wow $addon 'Second.toc';Assert (-not $r.valid -and 'MissingMetadata' -in $r.findings.code -and 'InvalidInterface' -in $r.findings.code) 'Required metadata and numeric Interface checked'
    Write-Text (Join-Path $addon 'Second.toc') "## Interface: 30300`n## Title: Second`nmain.lua`nmain.lua"
    $r=Wow $addon 'Second.toc';Assert ($r.valid -and 'RepeatedLoad' -in $r.findings.code) 'Repeated loads reported as warnings'
    foreach($reference in @('..\outside.lua','C:\Windows\win.ini','/Windows/win.ini','main.lua:stream','main.lua.','CON.lua','ui\..\..\outside.lua')){
        Write-Text (Join-Path $addon 'Second.toc') "## Interface: 30300`n## Title: Second`n$reference"
        $r=Wow $addon 'Second.toc';Assert (-not $r.valid -and 'UnsafeReference' -in $r.findings.code) "Unsafe path rejected: $reference"
    }
    Write-Text (Join-Path $addon 'ui\parent.xml') '<Ui><Script file="..\main.lua"/></Ui>'
    Write-Text (Join-Path $addon 'Second.toc') "## Interface: 30300`n## Title: Second`nui\parent.xml"
    $r=Wow $addon 'Second.toc';Assert ($r.valid -and $r.loadOrder[1].path -eq 'main.lua') 'Parent-relative XML include inside addon accepted'
    Write-Text (Join-Path $addon 'ui\parent.xml') '<Ui><Script file="nested.lua."/></Ui>'
    $r=Wow $addon 'Second.toc';Assert (-not $r.valid -and 'UnsafeReference' -in $r.findings.code) 'Trailing-dot XML include alias rejected'
    $r=Wow (Join-Path $fixture 'MissingAddon');Assert (-not $r.valid -and $r.findings[0].message -notmatch [regex]::Escape([Environment]::GetFolderPath('UserProfile'))) 'Addon error messages redact profile path'
    Write-Text (Join-Path $addon 'ui\nested.xml') '<Ui><Include file="main.xml"/></Ui>'
    $r=Wow $addon 'ExampleAddon.toc';Assert (-not $r.valid -and 'ReferenceCycle' -in $r.findings.code) 'XML cycle rejected'
    Write-Text (Join-Path $addon 'ui\nested.xml') '<!DOCTYPE Ui [<!ENTITY xxe SYSTEM "file:///C:/Windows/win.ini">]><Ui>&xxe;</Ui>'
    $r=Wow $addon 'ExampleAddon.toc';Assert (-not $r.valid -and 'InvalidXml' -in $r.findings.code) 'DTD and external entity rejected'
    try{
        $outside=Join-Path $fixture 'Outside';$null=New-Item -ItemType Directory -Path $outside;Write-Text (Join-Path $outside 'outside.lua') '-- outside'
        $null=New-Item -ItemType Junction -Path (Join-Path $addon 'linked') -Target $outside
        Write-Text (Join-Path $addon 'Second.toc') "## Interface: 30300`n## Title: Second`nlinked\outside.lua"
        $r=Wow $addon 'Second.toc';Assert (-not $r.valid -and 'UnsafeReference' -in $r.findings.code) 'Reparse-point escape rejected'
    }catch{if($_.Exception.Message.StartsWith('FAILED:')){throw};$skipped.Add('Junction test unavailable: '+$_.Exception.Message)}
    $exitCode=0
}catch{$failure=$_.Exception.Message;Write-Error $failure -ErrorAction Continue}
$evidence=[ordered]@{schemaVersion=1;observedUtc=[DateTime]::UtcNow.ToString('o');command="pwsh -NoProfile -File '$PSCommandPath'";exitCode=$exitCode;fixturePath=$fixture;checks=@($checks.ToArray());skipped=@($skipped.ToArray());failure=$failure;limitations=@('Lua syntax/API/runtime not tested.','Synthetic PE fixtures and real system image exercised; not full PE-format conformance certification.')}
$evidence | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $evidencePath -Encoding utf8
Write-Output "$($checks.Count) checks passed; $($skipped.Count) skipped; exit $exitCode; fixtures $fixture"
exit $exitCode
