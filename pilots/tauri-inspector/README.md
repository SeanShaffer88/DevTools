# DevTools Project Inspector — local pilot

A Windows x64 Tauri 2 frontend for the existing authoritative `Get-ProjectInfo.ps1`. Open the app, select a local directory, then Inspect. Opening the window runs no discovery. Search rendered markers, instruction filenames and Git metadata; expand raw stdout/stderr and execution details. Cancel discards the result and signals the owned process. SDK inventory and all other helpers are deferred.

From this directory, in PowerShell 7:

```powershell
./verify.ps1 -Task test
./verify.ps1 -Task frontend
./verify.ps1 -Task build
./target/debug/devtools-inspector.exe
# Explicit owned-window check; capture stays in ignored evidence:
./native-smoke.ps1
```

The explicit build scripts use locally verified Rust 1.99.1 MSVC, VS2022 14.44.35207, Windows SDK 10.0.26100.0, Node 26 and cached locked dependencies; no restore/network flag is enabled. `verify.ps1` copies the existing build runner unchanged into ignored evidence so its logs stay within this pilot. No installers, signing or publishing. Runtime WebView2 profile is explicitly confined to `evidence/webview-profile` using the native builder's absolute-path API.

`host-config.json` is trusted compile-time configuration containing absolute pwsh/helper/adapter-wrapper paths and SHA-256 identities. Review any host/helper update before changing these pins and rebuilding. Selected project paths cannot choose an executable, script or command. Helper calls use the fixed documented argument array. Both debug and release GUI binaries use the Windows subsystem. Child PowerShell is created with CREATE_NO_WINDOW; the pinned, fixed inspect-project.ps1 adapter sets UTF-8 inside that child and invokes only the authoritative helper with fixed depth/JSON flags. No console is allocated or hidden after creation, and no inherited console or system settings are modified. Read-only inspection still invokes the helper's own Git metadata calls. The helper's interpretation remains authoritative.

The adapter uses a 15-second deadline and 1 MiB per stream. Its Windows Job kills owned descendants on closure. Cancellation/timeout closes the Job before bounded pipe draining and joins both polling reader workers; capped partial diagnostics remain available. A cap or termination that splits a UTF-8 character retains valid text and the original termination status. This prototype is not a security sandbox: filesystem changes between validation and use, process assignment races before Job attachment, repository Git configuration and host executable DLL loading remain review considerations. Root and ancestor reparse points are rejected; the helper skips nested reparse entries. Concurrent application instances are not qualified; each instance has one active inspection and a shared pilot WebView profile.

Sources: `SPEC.md`, pre-implementation `MOCKUP.svg`, `VERIFICATION.md`, `SOURCES.md`. No root toolkit source files were changed. No reusable crate was extracted; internal adapter and UI model have explicit interfaces without introducing separately maintained packages.

Bounded prototype verification: 11 Rust tests, 2 frontend tests and the corrective native build passed (exit 0); independent audit accepts the code. Coordinator testing of the rebuilt native WebView2 exercised Inspect with a seeded test path, filtering, light theme, programmatic search focus and Cancel. The native folder picker passed on the prior revision. See `VERIFICATION.md` for evidence and remaining limits; full Windows keyboard and accessibility checks remain unverified. This is not a beta, release or production-readiness claim.
