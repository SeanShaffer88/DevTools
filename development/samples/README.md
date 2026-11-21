# Offline Platform Samples

These original projects exercise the saved DevTools toolchains. They are build fixtures, not production applications. All artifact-producing commands must run through isolation/Invoke-OfflineProcess.ps1 with zero network capabilities. A normal host invocation of tools/build.mjs is not an offline proof.

| Target | Source | Actual artifact/check | Additional prerequisites |
| --- | --- | --- | --- |
| Windows software | windows/app.c | Native x64 Win32 executable with original icon | Saved Zig Windows compiler; Windows OS |
| Android app | android-app/ | Java Activity APK with actual DEX, alignment and debug signature | Saved JDK; explicit private licensed Android SDK |
| Android game | godot-game/ | Godot Android APK | Saved editor/templates/JDK; private Android SDK |
| PC game | godot-game/ | Windows game executable and PCK | Saved Godot editor and matching Windows template |
| Website | website/ | Static website ZIP, Node parse and DOM fixture | Saved Node; no npm packages |
| Userscript | userscript/ | .user.js with narrow metadata, parse and idempotence fixture | Saved Node; manager runtime not tested |
| Userstyle | userstyle/ | .user.css with narrow scope, balanced structure and local resources | Saved Node; not a complete CSS parser or rendering audit |
| Reusable dependency | dependency/ | Compiled Java JAR consumed by a separate compiled/run project | Saved JDK, original ZIP/JAR packager |
| PortableApps.com | portableapps/ | Real official PAL launcher and PAF installer compilation | Saved official Generator/Installer/NSIS tools and matching sources |
| WoW addon | wow-addon/ | Addon ZIP and actual Lua 5.1.5 syntax check | Existing approved Lua tool; fixture Interface 16001 |

The mockup in mockups/sample-layout.svg precedes the UI sources. Each project uses original code and the scoped MIT license. The canonical PortableApps.com domain remains authoritative for format/INI rules; tooling and its bundled components retain their own separate licenses.

## Build From Saved Resources

Run PowerShell 7 from a trusted stable checkout. Choose a **new** work root outside DevTools, whose parent exists, and explicitly supply your licensed SDK path:

```powershell
pwsh -NoProfile -File development/samples/Build-OfflineSamples.ps1 -WorkRoot C:/Build/DevTools-Samples -AndroidSdkPath C:/Android/Sdk
```

Defaults explicitly select SDK platform android-34 and build-tools 36.0.0. Use -SdkPlatform and -SdkBuildTools only for an intentionally reviewed compatible selection. The script does not install or fetch them. It bootstraps the saved Python embeddable ZIP, verifies/reconstructs saved tool archives, extracts them as data, copies the private SDK and original sources, then invokes the real isolated Node build. No npm, Maven or package restore is used. -Targets accepts a subset of the table; godot-games exports both Android and PC game targets. Outputs and exact evidence remain in the new work root.

Preparation is separate from the network-denied build: resource extraction and source copying happen before isolation. The actual compiler, linker, exporter, signer, packager and packed-JAR consumer commands are all descendants of the zero-capability AppContainer process. Host PowerShell/.NET provide the isolation bootstrap; Windows is a declared prerequisite.

## Isolation And Evidence

Read isolation/README.md for the actual Windows AppContainer network-denial proof, ordinary-child inheritance, per-root serialization and cleanup. Tools and source are copied/extracted into a new task-owned root before isolated execution. Only that root receives temporary scoped ACL grants. No network capabilities, broad host ACL grants, device operations or global firewall changes are used.

Some compiler/library implementations query the drive root for temporary-file and filename limits. The optional owned-root DOS alias exposes only the existing task directory as a temporary user-session drive. It does not grant access to C:\ or weaken AppContainer network policy, and it must be removed after the child job finishes. The builder maps config paths to that alias during execution and records physical output paths after it is removed.

Build receipts list the exact saved tool identities, private prerequisite identities, exit codes, logs, artifact SHA-256 values and isolation cleanup result. Full command values are not copied into metadata. The reviewed source and explicit configuration are the reproducible command interface. A public throwaway debug signing password is used only for disposable fixture keys; no production credentials or signing keys belong in the repository.

## Scope Of A Pass

Compiled EXE/APK/JAR/PAF results are distinct from packaged/validated website, userscript, userstyle and addon artifacts. A PAF compile establishes Built only. No generated PAF is installed. Browser/extension manager injection, device launch, game rendering/gameplay, addon client behavior, installer upgrades, runtime portability and production signing remain unverified unless a separate receipt explicitly records those tests.

The Android SDK is copied from an explicitly supplied licensed local installation into private task scratch. It is not redistributed in DevTools and is not replaced by an original validator. Android passes therefore mean saved editor/JDK resources plus the declared private SDK can build offline, not that the Git repository alone contains every Android prerequisite.

The PortableApps GUI generators fail with native Win32 error 623 under this isolation context. The sample therefore compiles the unmodified official PAL/Installer source using the current Wizard-derived fixed fixture configuration. The installer compiler is the saved, explicitly derived relocatable NSIS 3.13 x86 build with static zlib 1.4; its source, build inputs, notices and host preparation receipt are in `bootstraps/nsis/`. GUI execution is not claimed passed.

Generated binaries are local verification artifacts, not release assets. In particular, the PAF includes Installer source but does not yet assemble a complete corresponding PAL-source distribution. Redistribution licensing review remains pending; include the complete matching PAL source and required notices before publishing a generated PAF. Saved upstream source resources remain available in the acquisition inventory.

WoW syntax checks reconstruct the saved `lua515-win-x64` acquisition, including the approved locally built Lua 5.1.5 executables and exact matching source. They do not require ignored tool binaries or an Android SDK.
