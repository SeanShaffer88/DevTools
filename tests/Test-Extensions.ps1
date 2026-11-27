#requires -Version 7.0
[CmdletBinding()]
param([string]$WorkRoot='C:\Users\Sean Shaffer\Documents\Codex\2026-11-03\a\work\devtools-expansion', [string]$EvidenceDirectory)
$ErrorActionPreference='Stop'
$evidencePath=& (Join-Path $PSScriptRoot 'Resolve-SuiteEvidencePath.ps1') 'validation-extensions.json' $EvidenceDirectory ($PSBoundParameters.ContainsKey('EvidenceDirectory'))
$toolRoot=Split-Path $PSScriptRoot -Parent
$fixture=Join-Path $WorkRoot ('android-template-'+[Guid]::NewGuid().ToString('N'));$null=[IO.Directory]::CreateDirectory($fixture)
$checks=[Collections.Generic.List[object]]::new();$commands=[Collections.Generic.List[object]]::new();$exitCode=1;$failure=$null
$oldPath=$env:PATH;$oldLog=$env:DEVTOOLS_FAKE_ADB_LOG;$oldMode=$env:DEVTOOLS_FAKE_ADB_MODE
function Assert([bool]$Condition,[string]$Label){if(-not $Condition){throw "FAILED: $Label"};$checks.Add([pscustomobject]@{name=$Label;passed=$true})}
function Run([string]$Exe,[string[]]$Arguments,[string]$Working=$fixture){
 $resolved=(Get-Command $Exe -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
 $r=[LocalDevTools.AndroidProcess]::Run($resolved,$Arguments,$Working,120)
 $id=$commands.Count;$out=Join-Path $fixture "$id.stdout.log";$err=Join-Path $fixture "$id.stderr.log"
 [IO.File]::WriteAllText($out,$r.Stdout);[IO.File]::WriteAllText($err,$r.Stderr)
 $commands.Add([pscustomobject]@{executable=$resolved;exitCode=$r.ExitCode;stdout=$out;stderr=$err})
 if($r.ExitCode -ne 0){throw "Command failed $($r.ExitCode): $resolved; $($r.Stderr)"};return $r
}
function New-Zip([string]$Path,[hashtable]$Entries){
 $zip=[IO.Compression.ZipFile]::Open($Path,[IO.Compression.ZipArchiveMode]::Create)
 try{foreach($name in $Entries.Keys){$entry=$zip.CreateEntry($name);$stream=$entry.Open();try{$bytes=[Text.Encoding]::UTF8.GetBytes($Entries[$name]);$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}}}finally{$zip.Dispose()}
}
try{
 if(-not('LocalDevTools.AndroidProcess' -as [type])){Add-Type -Path (Join-Path $toolRoot 'lib\AndroidProcess.cs')}
 foreach($script in @('Get-AndroidDiagnostics.ps1','New-DevProject.ps1','templates\AndroidCommon\Build.ps1')){$tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile((Join-Path $toolRoot $script),[ref]$tokens,[ref]$errors);Assert ($errors.Count -eq 0) "AST $script"}
 $generator=Join-Path $toolRoot 'New-DevProject.ps1';$diagnostics=Join-Path $toolRoot 'Get-AndroidDiagnostics.ps1'
 $projects=@{}
 foreach($kind in @('WindowsConsole','NativeDll','WowAddon','AndroidApp','AndroidGame')){
  $path=Join-Path $fixture ($kind+' With Spaces');$arguments=@{Template=$kind;Destination=$path;Name=('Sample'+$kind);Json=$true};if($kind -eq 'WowAddon'){$arguments.InterfaceVersion=30300}
  $r=& $generator @arguments | ConvertFrom-Json;Assert ($r.created -and $r.files.Count -gt 0) "Generate $kind";$projects[$kind]=$path
  $again=& $generator @arguments | ConvertFrom-Json;Assert (-not $again.created -and $LASTEXITCODE -eq 2) "Refuse overwrite $kind"
 }
 $r=& $generator -Template WindowsConsole -Destination (Join-Path $fixture 'Injection') -Name 'Bad;Name' -Json | ConvertFrom-Json;Assert (-not $r.created -and -not(Test-Path -LiteralPath (Join-Path $fixture 'Injection'))) 'Reject injected project name'
 $r=& $generator -Template WowAddon -Destination (Join-Path $fixture 'NoInterface') -Name Clean -Json | ConvertFrom-Json;Assert (-not $r.created) 'Require explicit WoW interface'
 $outside=Join-Path $fixture 'ExternalTemplate';$null=[IO.Directory]::CreateDirectory($outside);[IO.File]::WriteAllText((Join-Path $outside 'marker.txt'),'external')
 foreach($linkKind in @('Root','Nested')){
  $isolated=Join-Path $fixture ('SourceLink'+$linkKind);$templates=Join-Path $isolated 'templates';$null=[IO.Directory]::CreateDirectory($templates)
  Copy-Item -LiteralPath $generator -Destination (Join-Path $isolated 'New-DevProject.ps1')
  $templatePath=Join-Path $templates 'NativeDll'
  if($linkKind -eq 'Nested'){$null=[IO.Directory]::CreateDirectory($templatePath);$linkPath=Join-Path $templatePath 'nested'}else{$linkPath=$templatePath}
  $null=New-Item -ItemType Junction -Path $linkPath -Target $outside
  $destination=Join-Path $fixture ('Rejected'+$linkKind)
  $r=& (Join-Path $isolated 'New-DevProject.ps1') -Template NativeDll -Destination $destination -Name Clean -Json | ConvertFrom-Json
  Assert (-not $r.created -and -not(Test-Path -LiteralPath $destination)) "Reject $linkKind template junction before destination creation"
 }
 $destLink=Join-Path $fixture 'DestinationLink';$null=New-Item -ItemType Junction -Path $destLink -Target $outside
 $r=& $generator -Template NativeDll -Destination (Join-Path $destLink 'Child') -Name Clean -Json | ConvertFrom-Json;Assert (-not $r.created -and -not(Test-Path -LiteralPath (Join-Path $outside 'Child'))) 'Reject destination ancestor junction'
 $addon=& (Join-Path $toolRoot 'Test-WowAddon.ps1') -AddonPath $projects.WowAddon -InterfaceVersion 30300 -Json | ConvertFrom-Json;Assert $addon.valid 'Generated addon validates'
 $dotnet=Run 'dotnet.exe' @('build',(Join-Path $projects.WindowsConsole 'SampleWindowsConsole.csproj'),'--configuration','Release','--nologo') $projects.WindowsConsole
 $managedOutput=Get-ChildItem -LiteralPath (Join-Path $projects.WindowsConsole 'bin\Release') -Filter 'SampleWindowsConsole.dll' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
 if($null -eq $managedOutput){Write-Host ('dotnet build output:'+[Environment]::NewLine+$dotnet.Stdout+$dotnet.Stderr)}
Assert ($null -ne $managedOutput) '.NET source actually compiles offline'
 $native=$projects.NativeDll
 $nativeRun=Run 'cmake.exe' @('-S','.','-B','build','-G','Ninja') $native
 $nativeBuild=Run 'cmake.exe' @('--build','build') $native
 $nativeDll=Join-Path $native 'build\SampleNativeDll.dll'
 $nativeInfo=& (Join-Path $toolRoot 'Get-DllInfo.ps1') -Path $nativeDll -Json | ConvertFrom-Json
 Assert ($nativeInfo.valid -and @($nativeInfo.image.Exports | Where-Object Name -ceq 'SampleNativeDll_Add').Count -eq 1) 'Generated native DLL compiles and exports C ABI'
 Assert ($nativeInfo.image.Architecture -eq 'x64' -and $nativeInfo.image.Imports.Count -eq 0) 'Default CMake native DLL is x64 with no runtime imports'
 $probe='using System.Runtime.InteropServices; public static class NativeSampleProbe { [DllImport(@"'+$nativeDll+'", EntryPoint="SampleNativeDll_Add", CallingConvention=CallingConvention.Cdecl)] public static extern int Add(int left,int right); }'
 Add-Type -TypeDefinition $probe
 Assert ([NativeSampleProbe]::Add(2,3) -eq 5) 'Trusted generated native sample ordinary function call'
 Assert ([NativeSampleProbe]::Add([int]::MaxValue,1) -eq [int]::MaxValue -and [NativeSampleProbe]::Add([int]::MinValue,-1) -eq [int]::MinValue) 'Trusted generated native sample saturates arithmetic'
 $sdk=$env:ANDROID_HOME
 if([string]::IsNullOrWhiteSpace($sdk)){$sdk=$env:ANDROID_SDK_ROOT}
 if([string]::IsNullOrWhiteSpace($sdk)){throw 'Set ANDROID_HOME or ANDROID_SDK_ROOT to run Android template tests.'}
 foreach($kind in @('AndroidApp','AndroidGame')){
  $project=$projects[$kind];$r=Run 'pwsh.exe' @('-NoProfile','-File',(Join-Path $project 'Build.ps1'),'-SdkPath',$sdk) $project
  $apk=Get-ChildItem -LiteralPath (Join-Path $project 'build') -Filter '*-unsigned.apk' -File -Recurse | Select-Object -First 1
  Assert ($null -ne $apk) "$kind unsigned APK built"
  $info=& $diagnostics -ApkPath $apk.FullName -Json | ConvertFrom-Json
  Assert ($info.valid -and $info.apk.dexFiles -gt 0 -and $info.apk.manifest -eq 'BinaryOrUnknown') "$kind APK has DEX and binary manifest"
  Assert (Test-Path -LiteralPath (Join-Path $project 'mockups\Preview.svg')) "$kind SVG mockup present"
 }
 $linkedProject=Join-Path $fixture 'AndroidLinkedBuild';$generated=& $generator -Template AndroidApp -Destination $linkedProject -Name LinkedApp -Json | ConvertFrom-Json
 $outsideBuild=Join-Path $fixture 'ExternalBuild';$null=[IO.Directory]::CreateDirectory($outsideBuild);$null=New-Item -ItemType Junction -Path (Join-Path $linkedProject 'build') -Target $outsideBuild
 $pwsh=(Get-Command pwsh.exe -CommandType Application | Select-Object -First 1).Source
 $linkedResult=[LocalDevTools.AndroidProcess]::Run($pwsh,@('-NoProfile','-File',(Join-Path $linkedProject 'Build.ps1'),'-SdkPath',$sdk),$linkedProject,30)
 Assert ($linkedResult.ExitCode -ne 0 -and @(Get-ChildItem -LiteralPath $outsideBuild -Force).Count -eq 0) 'Android build junction rejected before outside artifacts'
 $fakeRoot=Join-Path $fixture 'FakeAdb';$null=[IO.Directory]::CreateDirectory($fakeRoot)
 [IO.File]::WriteAllText((Join-Path $fakeRoot 'FakeAdb.csproj'),'<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net10.0</TargetFramework><ImplicitUsings>enable</ImplicitUsings></PropertyGroup></Project>')
 [IO.File]::WriteAllText((Join-Path $fakeRoot 'NuGet.Config'),'<configuration><packageSources><clear /></packageSources></configuration>')
 [IO.File]::WriteAllText((Join-Path $fakeRoot 'Program.cs'),@'
using System.Text.Json;
var log=Environment.GetEnvironmentVariable("DEVTOOLS_FAKE_ADB_LOG");
if(log!=null) File.AppendAllText(log,JsonSerializer.Serialize(args)+Environment.NewLine);
var mode=Environment.GetEnvironmentVariable("DEVTOOLS_FAKE_ADB_MODE");
if(mode=="sleep") Thread.Sleep(5000);
if(mode=="fail") return 7;
if(args.Count(a=>a.StartsWith("--pid="))>1) { Console.Error.WriteLine("Only one --pid argument can be provided."); return 9; }
if(args.Contains("get-state")) Console.WriteLine("device");
else if(args.Contains("pidof")) Console.WriteLine(mode=="multi"?"77 88":"77");
else if(args.Contains("logcat")) Console.WriteLine(mode=="large"?new string('x',3*1024*1024):"Fixture Log Line");
return 0;
'@)
 $r=Run 'dotnet.exe' @('build',(Join-Path $fakeRoot 'FakeAdb.csproj'),'-c','Release','--nologo') $fakeRoot
 $fake=Join-Path $fakeRoot 'bin\Release\net10.0\FakeAdb.exe';$env:DEVTOOLS_FAKE_ADB_LOG=Join-Path $fixture 'adb-argv.jsonl';$env:DEVTOOLS_FAKE_ADB_MODE=''
 Copy-Item -LiteralPath $fake -Destination (Join-Path (Split-Path $fake) 'adb.exe')
 $env:PATH=(Split-Path $fake)+';'+$oldPath
 $apkFixture=Join-Path $fixture 'Fixture.apk';New-Zip $apkFixture @{'AndroidManifest.xml'='<manifest/>'; 'classes.dex'='dex';'lib/arm64-v8a/example.so'='elf';'assets/example.txt'='asset'}
 $before=(Get-FileHash -LiteralPath $apkFixture).Hash
 $info=& $diagnostics -ApkPath $apkFixture -Json | ConvertFrom-Json
 Assert ($info.valid -and $info.apk.nativeAbis -contains 'arm64-v8a' -and $info.apk.manifest -eq 'TextXml') 'Offline APK metadata'
 Assert (-not(Test-Path -LiteralPath $env:DEVTOOLS_FAKE_ADB_LOG)) 'Offline APK invokes no ADB'
 Assert ((Get-FileHash -LiteralPath $apkFixture).Hash -eq $before) 'APK inspection unchanged'
 $caseApk=Join-Path $fixture 'CaseSensitive.apk';New-Zip $caseApk @{'AndroidManifest.xml'='<manifest/>'; 'assets/Foo.txt'='upper'}
 $caseZip=[IO.Compression.ZipFile]::Open($caseApk,[IO.Compression.ZipArchiveMode]::Update);try{$entry=$caseZip.CreateEntry('assets/foo.txt');$stream=$entry.Open();$stream.Dispose()}finally{$caseZip.Dispose()}
 $r=& $diagnostics -ApkPath $caseApk -Json | ConvertFrom-Json;Assert $r.valid 'Distinct case-sensitive APK assets accepted'
 $bad=Join-Path $fixture 'Malformed.apk';[IO.File]::WriteAllText($bad,'not a zip');$r=& $diagnostics -ApkPath $bad -Json | ConvertFrom-Json;Assert (-not $r.valid -and $LASTEXITCODE -eq 2) 'Malformed APK rejected'
 $unsafe=Join-Path $fixture 'Unsafe.apk';New-Zip $unsafe @{'AndroidManifest.xml'='<manifest/>'; '../escape'='x'};$r=& $diagnostics -ApkPath $unsafe -Json | ConvertFrom-Json;Assert (-not $r.valid) 'ZIP traversal rejected without extraction'
 $device=& $diagnostics -DeviceSerial 'serial:1234' -PackageName 'local.example.app' -LogLines 42 -AdbPath $fake -Json | ConvertFrom-Json
 Assert ($device.valid -and $device.device.logs.Count -eq 1) 'Explicit selected device diagnostics using fake ADB'
 $calls=@(Get-Content -LiteralPath $env:DEVTOOLS_FAKE_ADB_LOG | ForEach-Object {,@(ConvertFrom-Json $_)})
 Assert (($calls[0] -join '|') -eq '-s|serial:1234|get-state') 'Exact serial argv boundaries'
 Assert (($calls[-1] -join '|') -eq '-s|serial:1234|logcat|-d|-t|42|-v|threadtime|--pid=77') 'Finite fixed logcat argv'
 $env:DEVTOOLS_FAKE_ADB_MODE='multi';$r=& $diagnostics -DeviceSerial 'serial:1234' -PackageName 'local.example.app' -AdbPath $fake -Json | ConvertFrom-Json
 Assert ($r.valid -and $r.device.logs.Count -eq 2) 'Multiple PIDs use separate logcat invocations'
 $env:DEVTOOLS_FAKE_ADB_MODE='large';$r=& $diagnostics -DeviceSerial 'serial:1234' -AdbPath $fake -Json | ConvertFrom-Json;Assert ($r.valid -and $r.device.outputTruncated -and $r.device.logs[0].logcat.Length -eq 2097152) 'ADB output bounded to 2 MiB while draining child'
 $env:DEVTOOLS_FAKE_ADB_MODE='fail';$r=& $diagnostics -DeviceSerial 'serial:1234' -AdbPath $fake -Json | ConvertFrom-Json;Assert (-not $r.valid -and $LASTEXITCODE -eq 7) 'ADB native failure propagated'
 $env:DEVTOOLS_FAKE_ADB_MODE='sleep';$r=& $diagnostics -DeviceSerial 'serial:1234' -AdbPath $fake -TimeoutSeconds 1 -Json | ConvertFrom-Json;Assert (-not $r.valid -and $LASTEXITCODE -eq 124) 'ADB timeout terminates selected child'
 $r=& $diagnostics -DeviceSerial 'bad;serial' -AdbPath $fake -Json | ConvertFrom-Json;Assert (-not $r.valid -and $LASTEXITCODE -eq 2) 'ADB serial injection rejected'
 $r=& $diagnostics -DeviceSerial 'serial:1234' -PackageName 'bad;package' -AdbPath $fake -Json | ConvertFrom-Json;Assert (-not $r.valid) 'ADB package injection rejected'
 $exitCode=0
}catch{$failure=$_.Exception.Message;Write-Error -Message $failure -ErrorAction Continue}
finally{
 $env:PATH=$oldPath;$env:DEVTOOLS_FAKE_ADB_LOG=$oldLog;$env:DEVTOOLS_FAKE_ADB_MODE=$oldMode
 [ordered]@{schemaVersion=1;observedUtc=[DateTime]::UtcNow.ToString('o');command='pwsh -NoProfile -File tests/Test-Extensions.ps1';exitCode=$exitCode;checks=$checks.ToArray();commands=$commands.ToArray();fixturePath=$fixture;error=$failure;limitations=@('No real device or Android runtime test.','APKs are unsigned; no signing keys or installs.','Ruflo worker was policy-blocked; implementation/testing used local fallback.')} | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $evidencePath
}
Write-Output "$($checks.Count) checks passed; exit $exitCode; fixture $fixture"
exit $exitCode
