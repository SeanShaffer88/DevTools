#requires -Version 7.0
[CmdletBinding()]
param([string]$WorkRoot='C:\Users\Sean Shaffer\Documents\Codex\2026-11-03\a\work\devtools-runtime-wave', [string]$EvidenceDirectory)
$ErrorActionPreference='Stop'
$evidencePath=& (Join-Path $PSScriptRoot 'Resolve-SuiteEvidencePath.ps1') 'validation-runtime-sdk-dependencies.json' $EvidenceDirectory ($PSBoundParameters.ContainsKey('EvidenceDirectory'))
$toolRoot=Split-Path $PSScriptRoot -Parent
$fixture=Join-Path $WorkRoot ('runtime-sdk-'+[guid]::NewGuid().ToString('N'));$null=New-Item -ItemType Directory -Path $fixture
$checks=[Collections.Generic.List[object]]::new();$hostChecks=[Collections.Generic.List[object]]::new();$failure=$null;$code=1
function Assert([bool]$Condition,[string]$Name){if(-not $Condition){throw "FAILED: $Name"};$checks.Add(@{name=$Name;passed=$true})}
function JsonFile([string]$Name,$Object){$path=Join-Path $fixture $Name;$Object | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath $path;return $path}
function Touch([string]$Path,[string]$Text='fixture'){$parent=Split-Path $Path -Parent;$null=New-Item -ItemType Directory -Path $parent -Force;[IO.File]::WriteAllText($Path,$Text)}
function Runtime($Requirements,$Inventory){$manifest=JsonFile 'requirements.json' @{schemaVersion=1;requirements=@($Requirements)};$inv=JsonFile 'inventory.json' $Inventory; & (Join-Path $toolRoot 'Test-RuntimeRequirements.ps1') -ManifestPath $manifest -InventoryPath $inv -Json | ConvertFrom-Json}
function New-Pe([string]$Path,[bool]$Plus=$true,[string]$ImportLibrary='',[string]$ImportName='Example',[string]$Forwarder=''){
    $m=[IO.MemoryStream]::new([byte[]]::new(4608),$true);$w=[IO.BinaryWriter]::new($m)
    function U16([long]$At,[uint16]$Value){$m.Position=$At;$w.Write($Value)};function U32([long]$At,[uint32]$Value){$m.Position=$At;$w.Write($Value)};function U64([long]$At,[uint64]$Value){$m.Position=$At;$w.Write($Value)};function Str([long]$At,[string]$Value){$m.Position=$At;$w.Write([Text.Encoding]::ASCII.GetBytes($Value));$w.Write([byte]0)}
    U16 0 0x5a4d;U32 0x3c 0x80;U32 0x80 0x4550;U16 0x84 $(if($Plus){0x8664}else{0x14c});U16 0x86 1;$os=if($Plus){0xf0}else{0xe0};U16 0x94 $os;U16 0x96 0x2002;$o=0x98;U16 $o $(if($Plus){0x20b}else{0x10b});U32 ($o+60) 0x200;$d=if($Plus){112}else{96};U32 ($o+$d-4) 16;U32 ($o+$d) 0x1000;U32 ($o+$d+4) 0x100
    if($ImportLibrary){U32 ($o+$d+8) 0x1100;U32 ($o+$d+12) 40}
    $s=$o+$os;Str $s '.rdata';U32 ($s+8) 0x1000;U32 ($s+12) 0x1000;U32 ($s+16) 0x1000;U32 ($s+20) 0x200
    U32 0x210 7;U32 0x214 1;U32 0x218 1;U32 0x21c 0x1060;U32 0x220 0x1040;U32 0x224 0x1050;U32 0x240 0x1070;U16 0x250 0;U32 0x260 $(if($Forwarder){0x10a0}else{0x1300});Str 0x270 'Example';if($Forwarder){Str 0x2a0 $Forwarder}
    if($ImportLibrary){U32 0x300 0x1200;U32 0x30c 0x1180;U32 0x310 0x1220;Str 0x380 $ImportLibrary;if($Plus){U64 0x400 0x1240;U64 0x408 ([uint64]::Parse('8000000000000007',[Globalization.NumberStyles]::HexNumber))}else{U32 0x400 0x1240;U32 0x404 ([uint32]::Parse('80000007',[Globalization.NumberStyles]::HexNumber))};U16 0x440 0;Str 0x442 $ImportName}
    [IO.File]::WriteAllBytes($Path,$m.ToArray());$w.Dispose();$m.Dispose()
}
function Resolve([string]$Path,[int]$Depth=12,[int]$Nodes=256){& (Join-Path $toolRoot 'Resolve-NativeDependencies.ps1') -Path $Path -MaxDepth $Depth -MaxNodes $Nodes -Json | ConvertFrom-Json}
try{
    foreach($name in @('Test-RuntimeRequirements.ps1','Test-SdkCompleteness.ps1','Resolve-NativeDependencies.ps1','lib\RuntimeCommon.ps1')){$tokens=$null;$errors=$null;$null=[Management.Automation.Language.Parser]::ParseFile((Join-Path $toolRoot $name),[ref]$tokens,[ref]$errors);Assert ($errors.Count -eq 0) "AST $name"}
    $req=@{id='core';kind='DotNet';name='Microsoft.NETCore.App';architecture='x64';minInclusive='9.0';maxExclusive='11.0'}
    $obs=@{kind='DotNet';name='Microsoft.NETCore.App';architecture='x64';version='10.0.14';status='Observed';evidence='Synthetic fixture'}
    $inv=@{schemaVersion=1;coverage=@{DotNet='Complete'};observations=@($obs)};$r=Runtime $req $inv;Assert ($r.valid -and $r.source -eq 'Supplied' -and $LASTEXITCODE -eq 0) 'Numeric 10 vs 9 comparison and supplied evidence provenance'
    $obs.version='8.0.99';$r=Runtime $req $inv;Assert (-not $r.valid -and $LASTEXITCODE -eq 2) 'Complete evidence wrong version fails'
    $obs.version='10.0.14';$obs.architecture='x86';$r=Runtime $req $inv;Assert ($LASTEXITCODE -eq 2) 'Wrong runtime architecture fails'
    $obs.architecture='Unknown';$r=Runtime $req $inv;Assert ($LASTEXITCODE -eq 3 -and $r.findings[0].status -eq 'unknown') 'Unknown runtime architecture never passes'
    $req.architecture='Any';$r=Runtime $req $inv;Assert $r.valid 'Any architecture requirement does not demand architecture evidence';$req.architecture='x64'
    $obs.status='Unavailable';$r=Runtime $req $inv;Assert ($LASTEXITCODE -eq 3) 'Unavailable observation remains unknown';$obs.status='Observed'
    $inv.observations=@();$r=Runtime $req $inv;Assert ($LASTEXITCODE -eq 2) 'Complete absent runtime fails'
    $inv.coverage.DotNet='Partial';$r=Runtime $req $inv;Assert ($LASTEXITCODE -eq 3) 'Partial absent runtime remains unknown'
    $inv.coverage.DotNet='Complete';$obs.architecture='x64';$obs.version='10.0.0-preview.1';$inv.observations=@($obs);$r=Runtime $req $inv;Assert ($LASTEXITCODE -eq 2) 'Prerelease excluded by default'
    $req.allowPrerelease=$true;$r=Runtime $req $inv;Assert $r.valid 'Explicit prerelease policy honored'
    $req2=@{id='java';kind='Java';architecture='x64';minInclusive='21';maxExclusive='22'};$inv2=@{schemaVersion=1;coverage=@{Java='Complete'};observations=@(@{kind='Java';name='Java';architecture='x64';version='21.0.1+12-LTS';status='Observed'})};$r=Runtime $req2 $inv2;Assert $r.valid 'Java build metadata LTS is stable'
    $inv2.observations[0].version='21-ea+12';$r=Runtime $req2 $inv2;Assert ($LASTEXITCODE -eq 2) 'Java early access is prerelease'
    $inv2.observations[0].version='21.0.13.0.2';$r=Runtime $req2 $inv2;Assert $r.valid 'Five-component Java vendor runtime supported'
    $req2.minInclusive='21.0.13.0.3';$r=Runtime $req2 $inv2;Assert ($LASTEXITCODE -eq 2) 'Java vendor tail compared without truncation'
    $req2.minInclusive='8';$req2.maxExclusive='9';$inv2.observations[0].version='1.8.0_443';$r=Runtime $req2 $inv2;Assert $r.valid 'Legacy Java8 update normalized'
    $req.id='same';$bad=JsonFile 'bad-requirements.json' @{schemaVersion=1;requirements=@($req,$req)};$r=& (Join-Path $toolRoot 'Test-RuntimeRequirements.ps1') -ManifestPath $bad -InventoryPath (Join-Path $fixture 'inventory.json') -Json | ConvertFrom-Json;Assert ($LASTEXITCODE -eq 125 -and $r.error) 'Duplicate requirement rejected before observation evaluation'
    $hostManifest=JsonFile 'host-requirements.json' @{schemaVersion=1;requirements=@(@{id='windows';kind='Windows';architecture='Any';minInclusive='6'},@{id='host-java';kind='Java';architecture='Any';minInclusive='1'})};$r=& (Join-Path $toolRoot 'Test-RuntimeRequirements.ps1') -ManifestPath $hostManifest -Json | ConvertFrom-Json;Assert (-not $r.error -and $r.source -eq 'Host' -and @($r.observations | Where-Object kind -eq Windows).Count -eq 1) 'Real host runtime inventory without inspected-app execution';Assert (@($r.observations | Where-Object {$_.kind -eq 'Java' -and $_.version -eq '21.0.13.0.2'}).Count -ge 1 -and $r.findings[1].status -eq 'pass') 'Actual installed Java vendor version evaluated'
    $native=Join-Path $fixture 'MSVC';$sdk=Join-Path $fixture 'Windows Kits';$sv='10.0.12345.0'
    foreach($part in @('bin\Hostx64\x64\cl.exe','bin\Hostx64\x64\link.exe','bin\Hostx64\x64\lib.exe','include\vcruntime.h','include\vadefs.h','lib\x64\vcruntime.lib','lib\x64\libcmt.lib')){Touch (Join-Path $native $part)}
    foreach($part in @("Include\$sv\um\Windows.h","Include\$sv\shared\sdkddkver.h","Include\$sv\ucrt\stdlib.h","Include\$sv\ucrt\stddef.h","Lib\$sv\um\x64\kernel32.lib","Lib\$sv\ucrt\x64\ucrt.lib","Lib\$sv\ucrt\x64\libucrt.lib","bin\$sv\x64\rc.exe")){Touch (Join-Path $sdk $part)}
    $r=& (Join-Path $toolRoot 'Test-SdkCompleteness.ps1') -Profile NativeWindows -Root $native -WindowsSdkRoot $sdk -WindowsSdkVersion $sv -Json | ConvertFrom-Json;Assert ($r.valid -and $LASTEXITCODE -eq 0) 'Coherent synthetic native SDK structural completeness'
    Remove-Item -LiteralPath (Join-Path $sdk "Lib\$sv\ucrt\x64\libucrt.lib");$r=& (Join-Path $toolRoot 'Test-SdkCompleteness.ps1') -Profile NativeWindows -Root $native -WindowsSdkRoot $sdk -WindowsSdkVersion $sv -Json | ConvertFrom-Json;Assert ($LASTEXITCODE -eq 2 -and ($r.findings | Where-Object id -eq 'windows.library.libucrt.lib').status -eq 'fail') 'Missing CRT library detected despite compiler presence'
    Touch (Join-Path $sdk "Lib\$sv\ucrt\x64\libucrt.lib");$r=& (Join-Path $toolRoot 'Test-SdkCompleteness.ps1') -Profile NativeWindows -Root $native -Architecture Arm64 -WindowsSdkRoot $sdk -WindowsSdkVersion $sv -Json | ConvertFrom-Json;Assert ($LASTEXITCODE -eq 2) 'Wrong target architecture SDK directories fail'
    Remove-Item -LiteralPath (Join-Path $sdk "bin\$sv\x64\rc.exe");$r=& (Join-Path $toolRoot 'Test-SdkCompleteness.ps1') -Profile NativeWindows -Root $native -WindowsSdkRoot $sdk -WindowsSdkVersion $sv -Json | ConvertFrom-Json;Assert (-not $r.valid) 'Missing resource compiler fails'
    $r=& (Join-Path $toolRoot 'Test-SdkCompleteness.ps1') -Profile NativeWindows -Root $native -Version '99.0.0' -WindowsSdkRoot $sdk -WindowsSdkVersion $sv -Json | ConvertFrom-Json;Assert ($LASTEXITCODE -eq 125 -and $r.error -match 'conflicts') 'Direct toolset root cannot silently ignore explicit version'
    foreach($profile in @('DotNet','NativeWindows','Android','Java')){$r=& (Join-Path $toolRoot 'Test-SdkCompleteness.ps1') -Profile $profile -Json | ConvertFrom-Json;Assert (-not $r.error -and $r.findings.Count -gt 0) "Host $profile SDK checked without configuration mutation";if($profile -eq 'NativeWindows'){Assert $r.valid 'Actual coherent Windows SDK structural inventory passes'};$hostChecks.Add(@{profile=$profile;valid=$r.valid;findings=$r.findings;exitCode=$LASTEXITCODE})}
    $r=& (Join-Path $toolRoot 'Test-SdkCompleteness.ps1') -Profile DotNet -Version '..\bad' -Json | ConvertFrom-Json;Assert ($LASTEXITCODE -eq 125) 'SDK selector traversal rejected'
    $graph=Join-Path $fixture 'Graph';$null=New-Item -ItemType Directory -Path $graph;$app=Join-Path $graph 'root.dll';$dep=Join-Path $graph 'localdep.dll';New-Pe $app $true 'localdep.dll';New-Pe $dep
    $before=(Get-FileHash -LiteralPath $app).Hash;$r=Resolve $app;Assert ($r.valid -and $r.nodes.Count -eq 2 -and $r.edges[0].symbols.Count -eq 2 -and $LASTEXITCODE -eq 0) 'Native named and ordinal dependency checks pass'
    Assert ((Get-FileHash -LiteralPath $app).Hash -eq $before) 'Native graph leaves image bytes unchanged'
    New-Pe $app $true 'missingdep.dll';$r=Resolve $app;Assert ($LASTEXITCODE -eq 2 -and 'MissingLibrary' -in $r.findings.id) 'Missing native DLL fails explicitly'
    New-Pe $app $true 'localdep.dll';New-Pe $dep $false;$r=Resolve $app;Assert ($LASTEXITCODE -eq 2 -and 'ArchitectureMismatch' -in $r.findings.id) 'Native candidate architecture mismatch fails'
    New-Pe $dep;New-Pe $app $true 'localdep.dll' 'NotExported';$r=Resolve $app;Assert ($LASTEXITCODE -eq 2 -and 'MissingExport' -in $r.findings.id) 'Missing named export fails'
    New-Pe $app $true 'localdep.dll';New-Pe $dep $true '' 'Example' 'forward.Example';New-Pe (Join-Path $graph 'forward.dll');$r=Resolve $app;Assert ($r.valid -and $r.nodes.Count -eq 3 -and $r.edges[0].symbols[0].forwarder -eq 'forward.Example') 'Forwarded named and ordinal exports resolved'
    New-Pe (Join-Path $graph 'forward.dll') $true '' 'Example' 'localdep.Example';$r=Resolve $app;Assert ($LASTEXITCODE -eq 3 -and 'ForwarderCycle' -in $r.findings.id) 'Forwarder cycles remain unknown without recursion runaway'
    $caseDir=Join-Path $fixture 'Case Sensitive Exports';$null=New-Item -ItemType Directory -Path $caseDir;$caseApp=Join-Path $caseDir 'caller.dll';$caseDll=Join-Path $caseDir 'case.dll';New-Pe $caseApp $true 'case.dll' 'Foo';New-Pe $caseDll $true '' 'Example' 'case.foo';$bytes=[IO.File]::ReadAllBytes($caseDll)
    foreach($pair in @(@(0x214,2),@(0x218,2),@(0x244,0x1080),@(0x264,0x1300))){[BitConverter]::GetBytes([uint32]$pair[1]).CopyTo($bytes,$pair[0])};[BitConverter]::GetBytes([uint16]1).CopyTo($bytes,0x252);[Text.Encoding]::ASCII.GetBytes("Foo`0").CopyTo($bytes,0x270);[Text.Encoding]::ASCII.GetBytes("foo`0").CopyTo($bytes,0x280);[IO.File]::WriteAllBytes($caseDll,$bytes)
    $r=Resolve $caseApp;Assert ($r.valid -and 'ForwarderCycle' -notin $r.findings.id) 'Foo forwarder to distinct case-sensitive foo export is not a cycle'
    [Text.Encoding]::ASCII.GetBytes("case.Foo`0").CopyTo($bytes,0x2a0);[IO.File]::WriteAllBytes($caseDll,$bytes);$r=Resolve $caseApp;Assert ($LASTEXITCODE -eq 3 -and 'ForwarderCycle' -in $r.findings.id) 'Actual same-symbol self-forwarder remains a cycle'
    New-Pe $dep $true 'root.dll';$r=Resolve $app;Assert ($r.valid -and 'ImportCycle' -in $r.cycles.kind) 'Import graph cycles detected and bounded'
    New-Pe $app $true 'api-ms-win-fixture-l1-1-0.dll';$r=Resolve $app;Assert ($LASTEXITCODE -eq 3 -and 'ApiSetMappingUnknown' -in $r.findings.id -and 'MissingLibrary' -notin $r.findings.id) 'API-set contract not misreported as missing DLL'
    New-Pe $app;$bytes=[IO.File]::ReadAllBytes($app);[BitConverter]::GetBytes([uint32]0x1500).CopyTo($bytes,(0x98+112+13*8));[IO.File]::WriteAllBytes($app,$bytes);$r=Resolve $app;Assert ($LASTEXITCODE -eq 3 -and 'DelayImportsUnsupported' -in $r.findings.id) 'Nonzero delay imports explicitly unknown'
    New-Pe $app $true 'localdep.dll';New-Pe $dep;$r=Resolve $app 12 1;Assert ($LASTEXITCODE -eq 3 -and 'GraphLimit' -in $r.findings.id) 'Dependency graph node bound explicit'
    Touch (Join-Path $graph 'invalid.dll') 'not-pe';$r=Resolve (Join-Path $graph 'invalid.dll');Assert ($LASTEXITCODE -eq 125 -and $r.error) 'Malformed root PE rejected cleanly'
    $r=Resolve 'C:\Windows\System32\ntdll.dll';Assert (-not $r.error -and $r.nodes.Count -ge 1) 'Real system native image inspected without loading'
    $code=0
}catch{$failure=$_.Exception.Message;Write-Error $failure -ErrorAction Continue}
$evidence=@{schemaVersion=1;observedUtc=[DateTime]::UtcNow.ToString('o');command="pwsh -NoProfile -File '$PSCommandPath'";exitCode=$code;fixturePath=$fixture;checks=@($checks.ToArray());hostChecks=@($hostChecks.ToArray());failure=$failure;limitations=@('Host checks structural/read-only; no installation or compile/link executed.','Supplied runtime evidence and synthetic PE fixture checks are not host compatibility guarantees.','API-set, nonzero delay imports, activation-context and dynamic loading not emulated.');routing='Actual implementation/testing used local fallback after Ruflo worker reads blocked by policy.'}
$evidence | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $evidencePath
Write-Output "$($checks.Count) checks passed; exit $code; fixture $fixture";exit $code
