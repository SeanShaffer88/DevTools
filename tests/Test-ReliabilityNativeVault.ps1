param([string]$Destination)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
. "$root/lib/QualityCommon.ps1"
if(-not $Destination){$Destination=Join-Path $root ('work/devtools-reliability-wave/native/vault/run-'+[Guid]::NewGuid().ToString('N'))}
$dest=Assert-QPath $Destination -New;$null=New-Item -ItemType Directory $dest
$compiler=Get-Command cl.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1
$cl=$compiler.Source
$builds=@();$cases=[Collections.Generic.List[object]]::new()
foreach($n in 1,2){$d=Join-Path $dest "build $n";$null=New-Item -ItemType Directory $d;"__declspec(dllexport) int arithmetic(int x) { return x + $n; }"|Set-Content (Join-Path $d 'fixture.c');$argsList=@('/nologo','/LD','/Zi','/Od',"/Fo$d/fixture.obj","/Fd$d/compiler.pdb",(Join-Path $d 'fixture.c'),'/link','/NOENTRY','/NODEFAULTLIB','/DEBUG:FULL','/INCREMENTAL:NO',"/OUT:$d/fixture.dll","/PDB:$d/fixture.pdb");$process=Invoke-QProcess $cl $argsList $d 60 65536;$process|ConvertTo-Json -Depth 10|Set-Content (Join-Path $d 'compiler-result.json');$builds+=@{executable=$cl;arguments=$argsList;result=$process};if($process.exitCode -ne 0){throw "Compiler failed: $($process|ConvertTo-Json -Compress)"}}
$pe=Join-Path $dest 'build 1/fixture.dll';$pdb=Join-Path $dest 'build 1/fixture.pdb';$other=Join-Path $dest 'build 2/fixture.pdb';$vault=Join-Path $dest 'vault with spaces'
function Manifest($id,$files){$m=Join-Path $dest "$id.json";@{schemaVersion=1;buildId=$id;source=@{revision='fixture';dirty=$false};artifacts=@($files)}|ConvertTo-Json -Depth 12|Set-Content $m;return $m}
function Run($name,$arguments,$expected){$result=Invoke-QProcess (Get-Command pwsh).Source (@('-NoProfile','-File',"$root/Manage-CrashSymbolVault.ps1")+$arguments+@('-Json')) $root 30 131072;$result|ConvertTo-Json -Depth 10|Set-Content (Join-Path $dest "$name-result.json");$json=[Text.Encoding]::UTF8.GetString($result.Output)|ConvertFrom-Json -AsHashtable;$ok=$result.exitCode -eq $expected;$cases.Add(@{name=$name;expectedExit=$expected;actualExit=$result.exitCode;pass=$ok;status=$json.status});if(-not $ok){throw "$name expected $expected, got $($result.exitCode): $([Text.Encoding]::UTF8.GetString($result.Output)) $($result.Error)"};return $json}
$correct=Manifest 'correct' @(@{path=$pe;kind='pe'},@{path=$pdb;kind='pdb';binaryFor=$pe})
$added=Run 'correct' @('-Mode','Add','-VaultRoot',$vault,'-BuildManifestPath',$correct) 0;$entry=$added.artifacts[0].path
$null=Run 'verify' @('-Mode','Verify','-EntryPath',$entry) 0
$null=Run 'duplicate' @('-Mode','Add','-VaultRoot',$vault,'-BuildManifestPath',$correct) 125
$null=Run 'find' @('-Mode','Find','-VaultRoot',$vault,'-BuildId','correct') 3
$wrong=Manifest 'wrong' @(@{path=$pe;kind='pe'},@{path=$other;kind='pdb';binaryFor=$pe});$null=Run 'wrong' @('-Mode','Add','-VaultRoot',$vault,'-BuildManifestPath',$wrong) 2
$missing=Manifest 'missing' @(@{path=$pe;kind='pe'},@{path=(Join-Path $dest 'missing.pdb');kind='pdb';binaryFor=$pe});$null=Run 'missing' @('-Mode','Add','-VaultRoot',$vault,'-BuildManifestPath',$missing) 3
$noPdb=Manifest 'no-pdb' @(@{path=$pe;kind='pe'});$null=Run 'no-pdb' @('-Mode','Add','-VaultRoot',$vault,'-BuildManifestPath',$noPdb) 3
$map=Join-Path $dest 'mapping.txt';'original -> a:'|Set-Content $map;$mapping=Manifest 'mapping' @(@{path=$map;kind='mapping';declaredBuildId='correct'});$null=Run 'mapping' @('-Mode','Add','-VaultRoot',$vault,'-BuildManifestPath',$mapping) 3
# Locate actual PDB stream 1 page from its MSF directory for controlled identity mutations.
$bytes=[IO.File]::ReadAllBytes($pdb);$block=[BitConverter]::ToUInt32($bytes,32);$mapBlock=[BitConverter]::ToUInt32($bytes,52);$directoryBlock=[BitConverter]::ToUInt32($bytes,$mapBlock*$block);$streamCount=[BitConverter]::ToUInt32($bytes,$directoryBlock*$block);$cursor=$directoryBlock*$block+4+$streamCount*4;$stream0Length=[BitConverter]::ToUInt32($bytes,$directoryBlock*$block+4);$cursor+=4*[int][Math]::Ceiling($stream0Length/[double]$block);$infoBlock=[BitConverter]::ToUInt32($bytes,$cursor);$infoOffset=$infoBlock*$block
foreach($case in @(@{name='age';offset=$infoOffset+8},@{name='guid';offset=$infoOffset+12},@{name='bounds';offset=52},@{name='stream-bounds';offset=$cursor})){$b=[byte[]]$bytes.Clone();if($case.name -like '*bounds'){[Array]::Copy([BitConverter]::GetBytes([uint32]::MaxValue),0,$b,$case.offset,4)}else{$b[$case.offset]=$b[$case.offset] -bxor 1};$p=Join-Path $dest ($case.name+'.pdb');[IO.File]::WriteAllBytes($p,$b);$m=Manifest $case.name @(@{path=$pe;kind='pe'},@{path=$p;kind='pdb';binaryFor=$pe});$null=Run $case.name @('-Mode','Add','-VaultRoot',$vault,'-BuildManifestPath',$m) 2}
$portable=Join-Path $dest 'portable.pdb';[IO.File]::WriteAllBytes($portable,[Text.Encoding]::ASCII.GetBytes('BSJBfixture'));$m=Manifest 'portable' @(@{path=$pe;kind='pe'},@{path=$portable;kind='pdb';binaryFor=$pe});$null=Run 'portable' @('-Mode','Add','-VaultRoot',$vault,'-BuildManifestPath',$m) 3
$payload=Join-Path $entry 'payload-000.pe';$b=[IO.File]::ReadAllBytes($payload);$b[100]=$b[100] -bxor 1;[IO.File]::WriteAllBytes($payload,$b);$null=Run 'payload-tamper' @('-Mode','Verify','-EntryPath',$entry) 2
$mp=Join-Path $entry 'entry.json';[IO.File]::AppendAllText($mp,' ');$null=Run 'manifest-tamper' @('-Mode','Verify','-EntryPath',$entry) 2
foreach($bad in @(@{name='traversal';path="$dest/../escape.dll"},@{name='ads';path="$pe`:extra"},@{name='unc';path='\\localhost\share\a.dll'})){$m=Manifest $bad.name @(@{path=$bad.path;kind='pe'});$null=Run $bad.name @('-Mode','Add','-VaultRoot',$vault,'-BuildManifestPath',$m) 125}
$large=Join-Path $dest 'large.dll';$f=[IO.File]::Create($large);$f.SetLength(268435457);$f.Dispose();$m=Manifest 'large' @(@{path=$large;kind='pe'});$null=Run 'size-limit' @('-Mode','Add','-VaultRoot',$vault,'-BuildManifestPath',$m) 125
$many=Manifest 'count-limit' (@(1..129|ForEach-Object {@{path=$pe;kind='pe'}}));$null=Run 'count-limit' @('-Mode','Add','-VaultRoot',$vault,'-BuildManifestPath',$many) 125
$junction=Join-Path $dest 'junction';$null=New-Item -ItemType Junction -Path $junction -Target (Join-Path $dest 'build 1');$m=Manifest 'reparse' @(@{path=(Join-Path $junction 'fixture.dll');kind='pe'});$null=Run 'reparse' @('-Mode','Add','-VaultRoot',$vault,'-BuildManifestPath',$m) 125
$bindings=foreach($p in @('Manage-CrashSymbolVault.ps1','lib/ReliabilityNativeSymbols.cs','lib/ReliabilityNativeSymbols.ps1','tests/Test-ReliabilityNativeVault.ps1')){@{path=$p;sha256=(Get-FileHash (Join-Path $root $p)).Hash}}
@{schemaVersion=1;status='Pass';passed=$cases.Count;failed=0;cases=$cases.ToArray();builds=$builds;bindings=@($bindings);limitations=@('No target DLL execution.','Junction coverage is local Windows filesystem behavior; adversarial races are not tested.')}|ConvertTo-Json -Depth 30|Set-Content (Join-Path $dest 'validation.json')
Write-Output "PASS $($cases.Count) cases; evidence: $dest"

