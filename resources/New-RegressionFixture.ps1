#requires -Version 7.0
<#
.SYNOPSIS
Creates inert, original known-good/broken inspection fixtures in a new directory.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Destination,[switch]$Json)
$ErrorActionPreference='Stop';$tool=Split-Path $PSScriptRoot -Parent;. (Join-Path $tool 'lib\PlatformResources.ps1');$r=New-PlatformResult 'New-RegressionFixture' 'OriginalInertFixtures';$global:LASTEXITCODE=125
try{
 $dest=Assert-PlatformPath $Destination -New;$null=[IO.Directory]::CreateDirectory($dest);$bytes=[byte[]]::new(512)
 function Put16([int]$Offset,[uint16]$Value){[BitConverter]::GetBytes($Value).CopyTo($bytes,$Offset)};function Put32([int]$Offset,[uint32]$Value){[BitConverter]::GetBytes($Value).CopyTo($bytes,$Offset)}
 Put16 0 0x5a4d;Put32 0x3c 0x80;Put32 0x80 0x4550;Put16 0x84 0x8664;Put16 0x94 0xf0;Put16 0x96 0x2002;Put16 0x98 0x20b;Put32 (0x98+60) 512
 [IO.File]::WriteAllBytes((Join-Path $dest 'header-only-x64.dll'),$bytes);[IO.File]::WriteAllBytes((Join-Path $dest 'truncated.dll'),[byte[]](0x4d,0x5a,0x00))
 foreach($kind in @('GoodAddon','BadAddon')){$dir=Join-Path $dest $kind;$null=[IO.Directory]::CreateDirectory($dir);"## Interface: 30300`n## Title: $kind`n## Author: Malikor`nmain.lua`n"|Set-Content -LiteralPath (Join-Path $dir "$kind.toc");if($kind -eq 'GoodAddon'){'-- Original harmless syntax fixture'|Set-Content -LiteralPath (Join-Path $dir 'main.lua')}}
 $zip=[IO.Compression.ZipFile]::Open((Join-Path $dest 'metadata-only.apk'),[IO.Compression.ZipArchiveMode]::Create);try{$entry=$zip.CreateEntry('AndroidManifest.xml');$stream=[IO.StreamWriter]::new($entry.Open());try{$stream.Write('<manifest package="local.fixture"/>')}finally{$stream.Dispose()}}finally{$zip.Dispose()};[IO.File]::WriteAllText((Join-Path $dest 'broken.apk'),'not zip')
 @{schemaVersion=1;requirements=@(@{id='sample';kind='DotNet';name='Microsoft.NETCore.App';architecture='x64';minInclusive='10.0.0';maxExclusive='11.0.0'})}|ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $dest 'runtime-requirements.json')
 @{schemaVersion=1;files=@(@{path='required-missing.txt';required=$true})}|ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $dest 'missing-package-manifest.json')
 $expected=@(@{path='header-only-x64.dll';helper='Get-DllInfo.ps1';expectedExit=0;scope='Header reader only; not runnable/loadable'},@{path='truncated.dll';helper='Get-DllInfo.ps1';expectedExit=2},@{path='GoodAddon';helper='Test-WowAddon.ps1';expectedExit=0},@{path='BadAddon';helper='Test-WowAddon.ps1';expectedExit=2},@{path='metadata-only.apk';helper='Get-AndroidDiagnostics.ps1';expectedExit=0;scope='ZIP metadata only, not an installable APK'},@{path='broken.apk';helper='Get-AndroidDiagnostics.ps1';expectedExit=2})
 $records=@(Get-PlatformFiles $dest|ForEach-Object{@{path=[IO.Path]::GetRelativePath($dest,$_.FullName).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName).Hash;source='Original DevTools inert fixture generator';license='User-owned fixture; redistribution rights not assessed'}})
 @{schemaVersion=1;generatedUtc=[DateTime]::UtcNow.ToString('o');generator='resources/New-RegressionFixture.ps1';files=$records;expected=$expected}|ConvertTo-Json -Depth 10|Set-Content -LiteralPath (Join-Path $dest 'fixtures.json');$r.destination=$dest;$r.expected=$expected;$r.valid=$true;$global:LASTEXITCODE=0
}catch{$r.error=$_.Exception.Message};Write-PlatformResult $r -Json:$Json
