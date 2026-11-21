#requires -Version 7.0
param([ValidateSet('test','build','frontend')][string]$Task='test')
$ErrorActionPreference='Stop'
$vc='C:/Program Files (x86)/Microsoft Visual Studio/2022/BuildTools/VC/Tools/MSVC/14.44.35207'
$sdk='C:/Program Files (x86)/Windows Kits/10'
foreach($file in @("$vc/bin/Hostx64/x64/cl.exe","$vc/bin/Hostx64/x64/link.exe","$sdk/Include/10.0.26100.0/um/windows.h")) { if(-not(Test-Path -LiteralPath $file)){ throw "Missing verified toolchain file: $file" } }
$env:PATH="$vc/bin/Hostx64/x64;$sdk/bin/10.0.26100.0/x64;$env:PATH"
$env:LIB="$vc/lib/x64;$sdk/Lib/10.0.26100.0/um/x64;$sdk/Lib/10.0.26100.0/ucrt/x64"
$env:INCLUDE="$vc/include;$sdk/Include/10.0.26100.0/um;$sdk/Include/10.0.26100.0/shared;$sdk/Include/10.0.26100.0/ucrt;$sdk/Include/10.0.26100.0/winrt"
$null=New-Item -ItemType Directory "$PSScriptRoot/evidence" -Force
# Preserve the authoritative runner byte-for-byte; its PSScriptRoot determines log scope.
Copy-Item "$PSScriptRoot/../../Invoke-DevBuild.ps1" "$PSScriptRoot/evidence/Invoke-DevBuild.ps1" -Force
$exe='C:/Program Files/Rust stable MSVC 1.100/bin/cargo.exe'
$argsList=if($Task -eq 'build'){@('build','--offline','--locked')}else{@('test','--offline','--no-default-features')}
$artifacts=if($Task -eq 'build'){@('target/debug/devtools-inspector.exe')}else{@()}
if($Task -eq 'frontend'){$exe='C:/Program Files/nodejs/node.exe';$argsList=@('--test','tests/frontend.test.mjs')}
& "$PSScriptRoot/evidence/Invoke-DevBuild.ps1" -ProjectPath $PSScriptRoot -Executable $exe -ArgumentList $argsList -ArtifactPath $artifacts
exit $LASTEXITCODE
