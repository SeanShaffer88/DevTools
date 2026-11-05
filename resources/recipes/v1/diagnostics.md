# Diagnostic Recipes

Original recipes, version 1. Run inside PowerShell 7 with $tools set to the DevTools directory. Commands below are bounded helpers. Read their help first and supply the actual project/version/target; no invented target should be executed.

## Runtime Or Native Link Failure

1. Run Test-RuntimeRequirements.ps1 -ManifestPath <requirements.json> -Json for declared runtime needs. Exit 0 means declared checks passed; 2 is definite mismatch; 3 means missing/unknown evidence; 125 means malformed/setup failure.
2. Run Test-SdkCompleteness.ps1 -Profile NativeWindows -Architecture x64 -Json. Structural host checks were executed in validation-runtime-sdk-dependencies.json. Compare missing files against developer environment INCLUDE/LIB configuration.
3. Run Resolve-NativeDependencies.ps1 -Path <owned-app.exe> -SearchDirectory <package-directory> -Json. Inspect unresolved API-set/SxS/delay/dynamic-load limits; never download arbitrary DLLs by filename.

## Dump Or Contract Failure

Use Export-CrashDiagnostics.ps1 only for an explicit owned process. Retain matching PDB/build artifacts privately. Real dump fixture execution is recorded in validation-windows-diagnostics.json when available. Use Test-DllContract.ps1 only with an explicit trusted contract and inspect child exit/timeout. Do not load an arbitrary dependency to diagnose it.

## WoW Syntax And Events

Run Test-WowAddon.ps1 with the actual Interface number, then Test-WowLua.ps1 with the selected profile and interpreter. resources/lua/event-harness.lua and sample-addon are original mocked fixtures. Actual Lua execution requires an installed compatible interpreter; in-game API/taint checks remain separate.

## Android Package And Frame Snapshots

Run Test-AndroidArtifact.ps1 -ApkPath <owned.apk> -Json. Native SDK verification is exercised against the unsigned template APK; unsigned signature failure is expected. Never interpret this as signed-package acceptance.

For an authorized device, Invoke-AndroidTest.ps1 -DeviceSerial <explicit-serial> -PackageName <package> -Tasks State,Memory,FrameStats -Destination <new-directory> -Json collects finite snapshots without reset or installation. Explicit -Tasks Startup -Component <package/activity> starts the app. No real-device tests were run during toolkit fixtures unless recorded separately.

## Installer And Build Comparison

Generate and review a New-InstallerTestLab.ps1 lab; actual guest install/upgrade/uninstall gates are NotPerformed until Windows Sandbox execution produces results. Do not execute guest commands on the host.

Capture Compare-DevBuild.ps1 -Root <project> -InputPath <explicit-files> -ArtifactPath <explicit-files> -ConfigurationPath <data.json> -OutputPath <new-snapshot.json>. Compare two snapshots using -BaselinePath and -CurrentPath. Exit 2 indicates observed differences, not that a build is defective.
