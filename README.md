# Local Developer Toolkit

Start here when working with this toolkit. Global Codex instructions in `C:/Users/Sean Shaffer/.codex/AGENTS.md` tell new local chats to discover this toolkit and use the appropriate helpers automatically during authorized project work. Those instructions include routing guidance for delegated workers. Other machines, profiles and chat products need their own equivalent guidance and access to this folder. Core helpers use **PowerShell 7** (`pwsh`) and built-in .NET. The user specifically approved the bundled local Lua 5.1.5 tools described below; no other dependency installation is automatic. Windows PowerShell 5.1 is not supported for host helpers; the installer lab's guest runner separately targets 5.1.

| Helper | Purpose | Writes |
| --- | --- | --- |
| `Get-DevEnvironment.ps1` | Inventory command paths, safe version probes, Visual Studio installations, and Android SDK directories | None |
| `Get-ProjectInfo.ps1` | Inspect bounded project markers, instruction filenames, wrappers, and Git branch | None |
| `Invoke-DevBuild.ps1` | Run an explicit executable once; record output, exit codes, and requested artifact hashes | `runs/<unique-run>/` plus whatever the explicit command writes |
| `Get-DllInfo.ps1` | Read PE architecture, imports/exports and export changes without loading targets | None |
| `Test-WowAddon.ps1` | Check TOC metadata, interface selection and safe Lua/XML load references | None |
| `Get-AndroidDiagnostics.ps1` | Offline APK metadata or finite diagnostics for an explicit device serial | No helper files; device mode may start local ADB server |
| `Test-Package.ps1` | Inventory, hashes, manifest and explicitly expected PE architecture | None |
| `New-DevProject.ps1` | Generate one of five local source templates without executing tools | Explicit new destination only |
| `Get-DevReference.ps1` | Search six original local operational notes and source pointers | None |
| `Test-RuntimeRequirements.ps1` | Compare declared architecture/version runtime needs against host or explicitly supplied evidence | None |
| `Test-SdkCompleteness.ps1` | Structural Windows native/.NET/Android/Java SDK components, distinct from environment configuration | None |
| `Resolve-NativeDependencies.ps1` | Bounded static import/export/forwarder candidate graph; unsupported loader contexts remain unknown | None |
| `Get-DependencyAudit.ps1` | Supported offline lock graphs, supplied license/advisory evidence and optional explicit online .NET audit | Explicit output only; explicit online mode queries configured sources without restore |
| `Export-CrashDiagnostics.ps1` | Bundle one explicit owned process's diagnostics, optional selected logs/minidump | New destination only |
| `Test-DllContract.ps1` | Static contract checks; explicit trusted-owned primitive calls in a separate child | Unique child-result evidence; executes selected DLL only with acknowledgement |
| `New-InstallerTestLab.ps1` | Generate a reviewable Windows Sandbox install/upgrade/uninstall lab and guest assertions | New lab/results mapping; does not launch VM or installers on host |
| `New-BuildSandbox.ps1` | WSL2 (Windows Home compatible) disposable build/test sandbox: `-BuildImage` bakes a hardened C++/Python/C# golden image; `-JobFolder`/`-InboxRoot` run validated job folders offline as an unprivileged user with DevTools mounted read-only, then unregister the distro. Job format: `templates/build-sandbox-job/JOB-FORMAT.md` | New image/results/outbox directories; per-run distro under `%LOCALAPPDATA%\BuildSandbox\instances` removed after each run; `-BuildImage` uses apt network inside the temporary distro only |
| `Manage-WowClientProfile.ps1` | Create/import/verify client/Interface/Lua profiles with hashed sources and SavedVariables as data | Explicit new profile destination only |
| `Test-WowLua.ps1` | Real matching-interpreter syntax checks and optional trusted Lua event/API mock harness | Child process only; no source writes or dependency installation |
| `Test-AndroidArtifact.ps1` | Installed aapt2 manifest/permission decoding, zipalign and apksigner verification | None; never signs/installs |
| `Invoke-AndroidTest.ps1` | Explicit selected-device state/launch/startup/screenshot/memory/frame-stat snapshots | New results directory; only requested Launch/Startup changes app state |
| `Compare-DevBuild.ps1` | Capture/compare explicit toolchain/configuration/input/artifact evidence and hashes | Explicit new capture output; never rebuilds |
| `toolkit.json` | Machine-readable entrypoint and interface index | None |

## Usage

Run these examples inside PowerShell 7:

```powershell
$tools = 'C:\Users\Sean Shaffer\Documents\DevTools'
& "$tools\Get-DevEnvironment.ps1" -Json
& "$tools\Get-ProjectInfo.ps1" -ProjectPath 'C:\Projects\My App' -Json
Get-Help "$tools\Invoke-DevBuild.ps1" -Full
```

The build runner sets `$LASTEXITCODE` when called as a script. Array arguments are easiest to preserve through a small caller script; propagate its status explicitly:

```powershell
# Run from a caller .ps1 launched with: pwsh -NoProfile -File .\build-local.ps1
& 'C:\Users\Sean Shaffer\Documents\DevTools\Invoke-DevBuild.ps1' `
  -ProjectPath 'C:\Projects\My App' -Executable 'cmake.exe' `
  -ArgumentList @('--build', 'build', '--config', 'Debug') `
  -ArtifactPath @('build\Debug\My App.exe')
exit $LASTEXITCODE
```

For PowerShell scripts, explicitly select `pwsh.exe` and supply `-NoProfile`, `-File`, and the script path as separate arguments. For Gradle batch wrappers, explicitly select a suitable interpreter and its arguments; the runner does not construct shell command strings. Inspection never executes wrappers or package scripts.

Exit codes: a failed command's native exit code; `0` for verified success; `2` when a successful command has missing/unreadable requested artifacts; `125` for setup, start, or evidence failure. Inspect `result.json` to distinguish a child exit of 2/125 from runner failures. Each run contains `stdout.log`, `stderr.log`, and `result.json`; results have `schemaVersion: 1`, UTC timestamps, resolved executable, process and runner exit codes, artifact sizes and SHA256 hashes. No artifacts requested means process success only. Hashes establish file identity, not correctness or freshness.

Arguments are not recorded, but **child output and file paths may contain sensitive information**. Logs remain local; review before sharing. The command inherits the caller's environment and access. This runner is not a sandbox. Do not pass untrusted commands.

The doctor runs fixed version queries from tools resolved on PATH. Missing tools are nonfatal. The doctor only locates ADB. The project inspector reads filenames and Git branch metadata, limits traversal to 10,000 entries and depth 0–4 (default 2), excludes common generated folders, and skips reparse points. Git status is deliberately not queried because configured clean filters can execute commands. Neither helper changes project files. No helper installs packages/applications, signs artifacts, creates releases/tags, changes global settings, or supplies credentials. Explicit build commands may perform their own actions.

## DLL And WoW Checks

```powershell
& "$tools\Get-DllInfo.ps1" -Path 'C:\Build\Example.dll' -Json
& "$tools\Get-DllInfo.ps1" -Path 'C:\Build\New.dll' -CompareTo 'C:\Build\Old.dll' -Json
& "$tools\Test-WowAddon.ps1" -AddonPath 'C:\Addons\Example' -InterfaceVersion 30300 -Json
```

DLL inspection reads bounded PE structures without loading the file: named/ordinal exports, forwarders, imports and machine architecture. Comparison identifies added/removed export identities and architecture changes; it does not certify complete ABI compatibility. Delay imports, managed API surface, dependency resolution and signature trust are not checked.

The addon validator requires `-TocPath` when several TOCs exist. It checks TOC metadata, numeric interfaces, missing/duplicate load entries, XML includes/scripts, cycles and contained paths. DTDs/external entities and reparse-point escapes are refused. Lua syntax, WoW API behavior, installed dependencies and in-game behavior remain `NotPerformed`.

## Android And Package Checks

```powershell
& "$tools\Get-AndroidDiagnostics.ps1" -ApkPath 'C:\Build\Example.apk' -Json
# Explicit device operation; may start the local ADB server:
& "$tools\Get-AndroidDiagnostics.ps1" -DeviceSerial 'YOUR_SERIAL' -PackageName 'local.example.app' -LogLines 200 -Json
& "$tools\Test-Package.ps1" -PackagePath 'C:\Build\Package' -ManifestPath 'C:\Build\package-manifest.json' -ExpectedArchitecture x64 -Strict -Json
```

Offline APK inspection reads ZIP metadata and SHA256 without extraction or ADB. Names remain case-sensitive. Binary manifests are identified, not decoded; signatures, installability and runtime behavior are not certified. Device mode requires a serial, finite commands and timeouts. It performs no install, uninstall, activity launch or log clearing. Package-filtered logcat uses one finite call per PID (at most eight), with at most `LogLines` per PID. Stdout/stderr are capped at 2 MiB each and may contain sensitive device logs. No real device was used for toolkit validation; fake ADB tests check arguments, multiple PIDs, output bounds, errors and timeouts.

Package manifest example (omit `sha256` if no expected hash):

```json
{"schemaVersion":1,"files":[{"path":"Example.dll","required":true},{"path":"data/example.json","required":false}]}
```

Optional `sha256` must be exactly 64 hexadecimal characters; required defaults to true. Paths must stay inside the package; duplicates, traversal, alternate streams and reparse points are refused. Unexpected files fail only with `-Strict`, which requires a manifest. The manifest itself is excluded from unexpected payload files. Static checks do not test installer upgrades, running-instance closure, shortcuts/startup settings, runtime dependencies or preserved data/settings.

`Test-Package.ps1 -MaxHashBytes` optionally caps the cumulative bytes hashed. A file that cannot fit the remaining budget is reported with `HashBudgetExceeded` and a null hash. The helper skips PE inspection for that file and returns exit `2` with incomplete hash coverage. A budget of zero still hashes empty files.

## Project Templates And Offline References

```powershell
& "$tools\New-DevProject.ps1" -Template NativeDll -Destination 'C:\Projects\NewLibrary' -Name NewLibrary -Json
& "$tools\New-DevProject.ps1" -Template WowAddon -Destination 'C:\Projects\NewAddon' -Name NewAddon -InterfaceVersion 30300 -Json
& "$tools\New-DevProject.ps1" -Template AndroidGame -Destination 'C:\Projects\NewGame' -Name NewGame -Json
& "$tools\Get-DevReference.ps1" -Query 'manifest' -Category Packaging -Json
```

Templates: `WindowsConsole`, `NativeDll`, `WowAddon`, `AndroidApp`, `AndroidGame`. Existing destinations are refused; names are safe identifiers. WindowsConsole defaults to verified local `net10.0`; a matching SDK/reference pack is required. Its NuGet configuration clears package sources. NativeDll has a C ABI sample and CMake build. On MSVC its sample-local default is an arithmetic-only CRT-free DLL; the generated README explains the narrow flags and when to reassess them. The addon template uses author Malikor and requires an explicit interface number.

Android templates use native Java platform APIs, include SVG mockups, and have a local `Build.ps1`. Explicitly running that build compiles Java, runs the installed D8 JAR, links an APK with aapt2, adds DEX and checks alignment. Verified local combination: JDK 21, SDK `android-36`, Build Tools `36.0.0`. Unique build folders retain logs and actual exit codes. Both Android template artifacts were built locally as **unsigned APKs**. No keys, signing, installation or device/runtime validation occurred. Generation itself runs no toolchain commands.

References are locally authored operational notes with provenance/version scope, not a complete offline SDK mirror. Search reads local files only; upstream URLs are pointers and are never fetched by the helper. Future chats should read this README and `toolkit.json` first.

Offline APK inspection checks up to 50,000 central-directory entries and 32 MiB of central-directory metadata before opening ZIP entries.

## Windows host requirements and exceptions

The baseline is PowerShell 7.0. The following entry points enforce higher minimums for the .NET APIs they use. The catalog lists these exceptions under `requires.powerShellByHelper`.

| Minimum | Entry points |
| --- | --- |
| PowerShell 7.1 (.NET 5) | `Get-PolicyDiagnostics.ps1`, `Invoke-ParserFuzz.ps1`, `Find-PrivateData.ps1`, `Compare-UiSnapshot.ps1`, `Compare-ManagedApi.ps1`, `Test-GameAssets.ps1`, `Invoke-GameplayReplay.ps1`, `Invoke-AndroidLifecycle.ps1`, `New-WowDiagnosticsAddon.ps1`, `resources/Test-MediaAttribution.ps1` |
| PowerShell 7.3 (.NET 7) | `Manage-CrashSymbolVault.ps1`, `tools/lua-5.1.5/Build-Lua.ps1` |

For the bundled .NET versions and currently supported releases, see the [PowerShell support lifecycle](https://learn.microsoft.com/powershell/scripting/install/powershell-support-lifecycle).

Use `Invoke-DevBuild.ps1 -TimeoutSeconds <1–86400>` to bound process exit and output capture after the child starts. A timeout returns `124` with `TimedOut` status, partial logs and any observed root exit code. Artifact verification is skipped. Cleanup closes the runner's pipes and attempts to stop the owned process tree when its root is still running. A descendant can survive if its root has already exited. Omitting the parameter keeps the unbounded wait.

## Runtime, Dependency And Execution Tools

Use `Get-Help <selected-helper-path> -Detailed` before first use. New runtime-wave tools use exit **0** for applicable passes, **2** for a definite mismatch/failure (or observed differences for build comparison), **3** for unavailable/unknown required evidence, and **125** for malformed/setup failure. Legacy helper exit conventions above are retained. A passing fixture test of expected Unknown is not host/runtime certification.

Runtime requirement examples live in `schemas/runtime-requirements.example.json` and `schemas/runtime-inventory.example.json`. Supplied inventories are labelled supplied evidence; absent records imply missing only with complete coverage. Numeric versions, prereleases, framework names and architecture are explicit. SDK checks establish structural presence, not compile/link success. Fresh host discovery found Windows SDK 10.0.26100.0 CRT/UM headers and libraries present; missing developer INCLUDE/LIB configuration can still cause compilation failure. The dependency resolver never loads inspected binaries or pretends to emulate the full Windows loader: unsupported API-set/SxS/delay/dynamic contexts remain unknown.

Dependency audit emits `DevTools.ComponentInventory/1`, not certified SPDX/CycloneDX. Offline license/advisory absence is Unknown; online .NET audit is an explicit opt-in and uses `--no-restore`. Recorded cache/license claims do not establish security or legal redistribution rights. See helper schemas/examples and resource recipes.

Crash bundles require an owned PID, and optional start-time matching protects target identity. Binary dumps may include private application memory; text redaction cannot promise to sanitize dumps. DLL contract calls require `-ExecuteTrusted` and a declared primitive signature contract. DLL initialization code executes in the selected child; a subprocess is not a security sandbox. The ordinary PE inspector never loads its target. Installer-lab generation does not certify install/upgrade/uninstall: review and explicitly run the generated lab in a supported disposable Windows Sandbox. No host installer execution or feature enabling occurs.

## Approved Local Lua And Platform Tests

The user explicitly approved official **Lua 5.1.5** source and a local build. Interpreter/compiler: `tools/lua-5.1.5/bin/lua.exe` and `luac.exe`; exact upstream MIT/COPYRIGHT retained. Source archive SHA256 is `2640fc56a795f29d28ef15e13c34a47e223960b0240e8cb0a82d9b0738695333`, matching lua.org's published checksum. `tools/lua-5.1.5/provenance.json` records source URL, compiler/SDK, actual corrected build exit and artifact hashes. The approved archive includes its original offline Lua 5.1 manual under `tools/lua-5.1.5/verified-build/source/lua-5.1.5/doc/manual.html`.

Rebuild only when needed using `tools/lua-5.1.5/Build-Lua.ps1 -Destination <new-directory>`; it verifies the existing pinned archive, validates tar paths/types, uses installed MSVC/SDK, and never downloads or changes PATH. The initial build failed because vcvars omitted UCRT paths; the recorded successful build supplies verified SDK include/library flags. Sources remain unchanged. A newer Lua language version is not substituted for a legacy client's selected profile.

`Manage-WowClientProfile.ps1` imports explicit client/API/SavedVariables data without executing it. The included ExampleWrath profile and event harness are illustrative, not authentic game API snapshots. `Test-WowLua.ps1` uses compile-only `loadfile` syntax checks and an explicitly selected trusted harness. Use `-TocPath` for multiple TOCs and the actual client's Interface. Real Lua good/bad syntax, no-execution marker and mock event/timeout tests ran; real game, taint and secure execution remain unperformed.

`Test-AndroidArtifact.ps1` separately reports binary manifest/permission decoding, ZIP alignment and signature verification. The actual unsigned template APK passes manifest/alignment and correctly fails signature. ZIP 16 KiB alignment is not full ELF load-segment compatibility or release-policy certification. `Invoke-AndroidTest.ps1` requires explicit serial/package/tasks. Startup requires semantic `Status: ok`; printed errors/timeouts and absent evidence are nonpass even with process exit 0. Memory and FrameStats retain raw data without resetting counters. Fake-ADB fixtures prove argv, binary capture and failure orchestration only; no real device execution is claimed.

## Shared Helper Module

New helpers should `Import-Module lib/DevToolsCommon.psm1` instead of copying path, JSON, process or result boilerplate. It provides:

- local path and contained-path resolution that refuses UNC/device paths, ADS, reserved names and reparse points
- bounded tree, byte, strict UTF-8 and JSON readers
- atomic writes
- canonical JSON
- streamed SHA-256
- shell-free process execution with timeouts, output caps, closed stdin and Job Object cleanup of descendants
- result envelopes with secret redaction

See `lib/DevToolsCommon.md` for per-function inputs, security notes, residual risks and an audit of the older duplicated helpers, which remain unchanged. Validate with `tests/Test-DevToolsCommon.ps1`.

## Versioned Resources

Search `Get-DevReference.ps1 -Resources -Query <text> -Json` for original versioned documentation and recipes. Omit `-Resources` to retain the original six-note library. `resources/index.json` also records approved Lua tool/source provenance. Resource categories include runtime/SDK/dependencies/crash/contracts/installer/WoW/Android/build/fixtures/cache/recipes.

- `resources/fixtures/v1/fixtures.json`: original inert good/broken PE/APK/addon/config fixtures, hashes and expected results. Recreate into a new folder with `resources/New-RegressionFixture.ps1`. Header-only DLLs are reader fixtures and must not be loaded; metadata-only APKs are not installable.
- `resources/cache/catalog.json`: offline original fixture and specifically approved Lua archive records with hashes/source/license/provenance. Verify using `resources/Test-CacheCatalog.ps1 -CatalogPath <catalog> -Json`; missing/corrupt entries fail and unknown provenance/license is Unknown. No automatic cache fetching exists.
- `resources/docs/v1` and `resources/recipes/v1`: original source-linked notes and bounded procedures with tested versus unperformed gates. No complete Windows/Android SDK documentation mirror is claimed.

## Validation And Extension

Run `pwsh -NoProfile -File 'C:\Users\Sean Shaffer\Documents\DevTools\tests\Test-DevTools.ps1'`. The test script creates a unique fixture under the current chat workspace's `work` folder by default; override `-WorkRoot` for another local scratch directory. Fixtures and run evidence are retained; the suite performs no recursive deletion.

Repeatable suites: `tests/Test-DevTools.ps1`, `tests/Test-BinaryAddon.ps1`, `tests/Test-PackageReferences.ps1`, `tests/Test-Extensions.ps1`, `tests/Test-RuntimeSdkDependencies.ps1`, `tests/Test-WindowsDiagnostics.ps1`, `tests/Test-PlatformResources.ps1`. Evidence files are indexed in `toolkit.json`. They retain actual commands, exit codes, checks, limits and fixture paths. No recursive cleanup occurs. Tests explicitly build/run trusted fixture code only; inspection helpers never load arbitrary inspected DLLs or execute addon files.

The catalog-indexed validation suites accept `-EvidenceDirectory` for an existing local folder. Each suite keeps its usual evidence filename. Use `-Verbose` to display the resolved evidence path. Without this option the evidence goes to the toolkit root. `-WorkRoot` controls fixture placement in the suites that support it.

`validation-summary.json` is a snapshot of those suite outcomes plus built fixture paths, sizes and hashes. Regenerate the summary when collecting a new combined snapshot.

Earlier policy-blocked routing evidence is retained. The launcher now forwards the configured Windows sandbox backend while preserving requested worker access policy. Fresh read-only Ruflo probes and independent quality reviews succeeded. The platform/game implementation worker timed out after an actual 108-check passing run; targeted local corrections and the fresh 120-check suite are recorded separately. Long terminal operations use a trusted hidden background launcher with owned-process deadlines; launcher exit alone does not establish completion. No authentication or global access policy was weakened.

Add future helpers to `toolkit.json` with parameters, write scope, requirements and schema version. Use existing native tools; obtain confirmation before adding third-party dependencies. Keep unrelated projects unchanged.

## Quality Helpers (0.4.0)

- Windows UI: `Test-WindowsUi.ps1` requires an owned process and explicit `-AllowActions` for actions. `Compare-UiSnapshot.ps1` requires matching DPI/theme/locale contexts. Live WPF was tested; global Tab is Unsupported and the legacy WinForms bridge remains unqualified. These checks do not certify accessibility.
- Memory/data: `Invoke-NativeMemoryTest.ps1` runs explicit trusted build manifests using verified installed ASan. `Test-DataMigration.ps1` copies fixtures before trusted migrations. `Invoke-ParserFuzz.ps1` executes acknowledged trusted targets under bounded runs; child processes are not security sandboxes.
- Managed/privacy: `Compare-ManagedApi.ps1` requires `-TrustMetadata` before bounded metadata decoding and never loads inspected assemblies; arbitrary untrusted DLL parsing is outside its contract. `Find-PrivateData.ps1` reports redacted candidates only within the selected bounded path; do not expand into home/authentication directories.
- Performance: `Invoke-WindowsPerformance.ps1` uses an owned unique WPR instance or supplied metrics. Never stop another recording, elevate automatically, or treat absent ETL analysis as measured performance.
- Games: `Test-GameAssets.ps1` checks bounded structural media/path budgets. `Invoke-GameplayReplay.ps1` requires an explicit trusted adapter and scenario; evidence is specific to that adapter.
- Android lifecycle: `Invoke-AndroidLifecycle.ps1` requires explicit serial/package/tasks. Adapters require explicit trust; rotation requires an app adapter. Never change global device settings. Fake-ADB tests do not establish real-device behavior.
- WoW diagnostics: `New-WowDiagnosticsAddon.ps1` generates into a new destination using an explicit client profile. Generation does not install/run the addon; real-client taint and performance require separate checks.
- Quality resources: `Get-DevReference.ps1 -Resources` searches original UI baselines, device/asset budgets, API/save/IPC schemas and media attribution notes in `resources/quality/v1`. `resources/Test-MediaAttribution.ps1` checks supplied hashes and declared attribution; license strings do not prove legal rights.

Repeatable suites: tests/Test-QualityFoundations.ps1, tests/Test-QualityNative.ps1, tests/Test-QualityGames.ps1. Actual evidence is indexed in toolkit.json. The UIA sidecar uses installed Windows PowerShell 5.1; public helpers require PowerShell 7. UI mockups and PNG baselines are original synthetic fixtures. Real-device, in-game, elevated WPR and installer lifecycle checks remain separate gates. Read helper help before first use.

## AI-native Developer Utilities

The Python 3.10+ standard-library suite adds 15 offline CLI checks for Godot, WoW addons, Rust projects, export profiles, and release manifests. It has no added package dependencies or telemetry. Start with [ai_tools/README.md](ai_tools/README.md) for commands, schemas, limits, and safety notes.

## Knowledge base

The [`knowledge/`](knowledge/) folder of this repo is a self-contained Windows desktop development knowledge base — the rule layers (Elite Prompt, Engineering Contract V4.0, guardrails), tiered project classes and sanctioned stacks, the QUALITY.md gate, SeanPak packaging, the TesselGUI design system, and release verification — written for AI coding agents and human developers. It is built to be downloaded and used locally: start with [`knowledge/manifest.json`](knowledge/manifest.json) and [`knowledge/AGENTS.md`](knowledge/AGENTS.md), or upload [`knowledge/ai-bundle.md`](knowledge/ai-bundle.md) as a single file.
