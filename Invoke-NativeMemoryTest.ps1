#requires -Version 7.0
<#
.SYNOPSIS
Builds and executes an explicitly trusted ASan manifest in a new working folder.
.PARAMETER BuildManifestPath
Schema 1: compilerPath, compileArguments[], executablePath (work-relative),
runArguments[], instrumentation='AddressSanitizer', timeoutSeconds, maxOutputBytes.
Arguments may contain literal {ProjectRoot} and {WorkRoot} substitutions.
Optional runtimeFiles[] explicitly copy installed sanitizer runtimes to the new work folder.
.NOTES
No project/source configuration is rewritten. The trusted compiler/program is not sandboxed.
ASan import evidence is required; static instrumentation without a recognizable runtime import is Unknown.
#>
[CmdletBinding()]param([Parameter(Mandatory)][string]$ProjectPath,[Parameter(Mandatory)][string]$BuildManifestPath,[Parameter(Mandatory)][string]$Destination,[switch]$ExecuteTrusted,[switch]$Json)
$ErrorActionPreference='Stop';. (Join-Path $PSScriptRoot 'lib\QualityCommon.ps1');$r=New-QResult 'Invoke-NativeMemoryTest' 'ExplicitTrustedNativeBuildAndExecution';$code=125
try{
 $project=Assert-QPath $ProjectPath;if(-not (Get-Item -LiteralPath $project).PSIsContainer){throw 'ProjectPath must be a directory.'};$plan=Read-QJson $BuildManifestPath;Assert-QSchema $plan
 if($plan.instrumentation -cne 'AddressSanitizer'){throw 'Only explicit AddressSanitizer manifests are supported.'};if(-not $ExecuteTrusted){$r.status='Blocked';$r.error='ExecuteTrusted acknowledgement is required.';$code=3}else{
 if($plan.compileArguments -isnot [array] -or $plan.runArguments -isnot [array]){throw 'compileArguments and runArguments must be arrays.'};foreach($a in @($plan.compileArguments)+@($plan.runArguments)){if($a -isnot [string] -or $a.Contains([char]0)){throw 'Arguments must be strings without NUL.'}}
 $timeout=if($plan.Contains('timeoutSeconds')){[int](Assert-QInteger $plan.timeoutSeconds 1 300 'timeoutSeconds')}else{30};$limit=if($plan.Contains('maxOutputBytes')){[int](Assert-QInteger $plan.maxOutputBytes 1024 16777216 'maxOutputBytes')}else{2097152}
 $dest=Assert-QPath $Destination -New;if($dest.StartsWith($project.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase) -or $project.StartsWith($dest.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Project and destination roots must not overlap.'};$exe=Resolve-QChild $dest $plan.executablePath;if([IO.Path]::GetExtension($exe) -ine '.exe'){throw 'Executable artifact must end in .exe.'};$null=New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($exe))
 $runtimeRecords=@();if($plan.Contains('runtimeFiles')){if($plan.runtimeFiles -isnot [array] -or $plan.runtimeFiles.Count -gt 16){throw 'runtimeFiles must be an array of at most 16 files.'};foreach($runtime in $plan.runtimeFiles){$source=Assert-QPath $runtime;$f=Get-Item -LiteralPath $source;if($f.PSIsContainer -or $f.Length -gt 67108864){throw 'Invalid runtime file.'};$target=Resolve-QChild ([IO.Path]::GetDirectoryName($exe)) $f.Name;Copy-Item -LiteralPath $source -Destination $target -ErrorAction Stop;$runtimeRecords+=@{path=$target;source=$source;sha256=(Get-FileHash -LiteralPath $target).Hash}}}
 $args=@($plan.compileArguments|ForEach-Object{$_.Replace('{ProjectRoot}',$project).Replace('{WorkRoot}',$dest)});$build=Invoke-QProcess $plan.compilerPath $args $dest $timeout $limit
 [IO.File]::WriteAllBytes((Join-Path $dest 'build.stdout.log'),$build.Output);[IO.File]::WriteAllText((Join-Path $dest 'build.stderr.log'),$build.Error);$r.executionEvidence+=@{stage='Build';exitCode=$build.ExitCode;timedOut=$build.TimedOut;truncated=$build.Truncated};$r.artifacts+=$runtimeRecords
 if($build.TimedOut -or $build.Truncated){$r.status='Unknown';$code=3}elseif($build.ExitCode -ne 0){$r.status='Fail';$code=2}elseif(-not(Test-Path -LiteralPath $exe)){$r.status='Fail';$r.error='Expected executable was not produced.';$code=2}else{
 $pe=& (Join-Path $PSScriptRoot 'Get-DllInfo.ps1') -Path $exe -Json|ConvertFrom-Json -AsHashtable
 $runtimeByArchitecture=@{x64='clang_rt.asan_dynamic-x86_64.dll';x86='clang_rt.asan_dynamic-i386.dll';Arm64='clang_rt.asan_dynamic-aarch64.dll'}
 $runtimeName=if($pe.valid -and $pe.image.Architecture){$runtimeByArchitecture[$pe.image.Architecture]}else{$null}
 $asan=@($pe.image.Imports|Where-Object {$runtimeName -and [string]::Equals($_.Library,$runtimeName,[StringComparison]::OrdinalIgnoreCase)})
 $symbols=@($asan|ForEach-Object {$_.Symbols}|Where-Object {$_.Name -cmatch '^__asan_(init|version_mismatch_check_v[0-9]+|report_(load|store)[0-9]+|report_(load|store)_n|register_globals|unregister_globals|poison_stack_memory|unpoison_stack_memory)$'})
 $hasFlag=@($plan.compileArguments|Where-Object {[string]::Equals($_,'/fsanitize=address',[StringComparison]::OrdinalIgnoreCase) -or [string]::Equals($_,'-fsanitize=address',[StringComparison]::Ordinal)}).Count -gt 0
 $instrumented=$pe.valid -and $asan.Count -gt 0 -and $symbols.Count -gt 0 -and $hasFlag
 $r.findings+=@{id='asan.importEvidence';status=if($instrumented){'Pass'}else{'Unknown'};runtimeImports=@($asan|ForEach-Object{$_.Library});instrumentationSymbols=@($symbols|ForEach-Object{$_.Name});buildFlagPresent=$hasFlag}
 if(-not $instrumented){$r.status='Unknown';$r.error='Supported architecture-matched ASan runtime, instrumentation imports and explicit address-sanitizer build flag are required; execution was not claimed instrumented.';$code=3}else{
 $runArgs=@($plan.runArguments|ForEach-Object{$_.Replace('{ProjectRoot}',$project).Replace('{WorkRoot}',$dest)});$run=Invoke-QProcess $exe $runArgs $dest $timeout $limit;[IO.File]::WriteAllBytes((Join-Path $dest 'run.stdout.log'),$run.Output);[IO.File]::WriteAllText((Join-Path $dest 'run.stderr.log'),$run.Error)
 $diag=([Text.Encoding]::UTF8.GetString($run.Output)+"`n"+$run.Error) -match '(?i)(ERROR: AddressSanitizer|AddressSanitizer:.*(buffer-overflow|use-after|double-free|alloc-dealloc))';$r.executionEvidence+=@{stage='Run';exitCode=$run.ExitCode;timedOut=$run.TimedOut;truncated=$run.Truncated;sanitizerDiagnostic=$diag}
 if($run.TimedOut -or $run.Truncated){$r.status='Unknown';$code=3}elseif($diag -or $run.ExitCode -ne 0){$r.status='Fail';$code=2}else{$r.status='Pass';$r.valid=$true;$code=0};$r.artifacts+=@{path=$exe;sha256=(Get-FileHash -LiteralPath $exe).Hash;producingExitCode=$build.ExitCode}
 }};$r.destination=$dest;[IO.File]::WriteAllText((Join-Path $dest 'result.json'),(ConvertTo-Json -InputObject $r -Depth 50))
 };$r.limitations=@('A successful exercised path does not prove absence of memory defects.','Runtime imports and build flags are limited metadata evidence; they cannot certify instrumentation of all code.','Compiler/program execution is trusted and not a security sandbox. Logs can contain sensitive child output.')
}catch{$r.status='Blocked';$r.error=$_.Exception.Message;$code=125};$global:LASTEXITCODE=$code;Complete-QResult $r -Json:$Json

