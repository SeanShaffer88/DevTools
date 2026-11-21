# DevTools Project Inspector — local pilot

A Windows x64 Tauri 2 frontend for the existing authoritative `Get-ProjectInfo.ps1`. Open the app, select a local directory, then Inspect. Opening the window runs no discovery. Search rendered markers, instruction filenames and Git metadata; expand raw stdout/stderr and execution details. Cancel discards the result and signals the owned process. SDK inventory and all other helpers are deferred.

From this directory, in PowerShell 7:

```powershell
./verify.ps1 -Task test
./verify.ps1 -Task frontend
./verify.ps1 -Task build
./target/debug/devtools-inspector.exe
# Explicit owned-window check; each run writes its own ignored evidence/native-smoke-* directory:
./native-smoke.ps1
```

The default smoke runs two separate native launches and writes a summary linking both runs. Inspection uses a local Git fixture and checks folder confirmation, restored keyboard focus, rendered Git evidence and Escape dismissal. Cancellation uses a private delayed fixture and verifies the helper and descendants exit before app teardown. Run the default workflow with PowerShell 7.4 or later to configure the cancellation fixture per launch. The default workflow also uses installed Git and the Windows C# compiler. The Startup scenario supports PowerShell 7.0. Pass a single scenario with `-Scenario Startup`, `-Scenario Inspection` or `-Scenario Cancellation` when diagnosing failures.

The smoke locates an exposed owned caption point within a bounded work-area scan and records foreground and occlusion diagnostics. Inspect and Cancel use one verified UI Automation InvokePattern dispatch. Tab navigation and picker Escape remain actual keyboard input.

Run the keyboard smoke test on an unlocked interactive desktop. It may briefly move the pointer to the owned window caption to acquire foreground focus and restores the pointer when it can do so safely. If every tested caption point is covered, the smoke may briefly raise its own window above other windows, then restores its original normal z-order before sending Tab. A restoration failure stops the check. If safe activation is unavailable, the keyboard check reports Unknown.

The explicit build scripts use locally verified Rust 1.100.0 MSVC, VS2022 14.44.35207, Windows SDK 10.0.26100.0, Node 26 and cached locked dependencies; no restore/network flag is enabled. `verify.ps1` copies the existing build runner unchanged into ignored evidence so its logs stay within this pilot. No installers, signing or publishing. Runtime WebView2 profile is explicitly confined to `evidence/webview-profile` using the native builder's absolute-path API.

`host-config.json` is trusted compile-time configuration containing the absolute PowerShell path, checkout-relative helper and wrapper paths, and SHA-256 identities. Helper and wrapper paths resolve against the compile-time pilot source directory and must match their compiled hashes before execution. Review any host/helper update before changing these pins and rebuilding. Selected project paths cannot choose an executable, script or command. Helper calls use the fixed documented argument array. Both debug and release GUI binaries use the Windows subsystem. Child PowerShell is created with CREATE_NO_WINDOW; the pinned, fixed inspect-project.ps1 adapter sets UTF-8 inside that child and invokes only the authoritative helper with fixed depth/JSON flags. No console is allocated or hidden after creation, and no inherited console or system settings are modified. Read-only inspection still invokes the helper's own Git metadata calls. The helper's interpretation remains authoritative.

The adapter uses a 15-second deadline and 1 MiB per stream. Process creation assigns the helper to its Windows Job before execution. This requires Windows 10 or Windows Server 2016 or later and fails at startup if assignment is unavailable. Closing the Job terminates owned descendants. Cancellation/timeout closes the Job before bounded pipe draining and joins both polling reader workers; capped partial diagnostics remain available. A cap or termination that splits a UTF-8 character retains valid text and the original termination status. This prototype is not a security sandbox: filesystem changes between validation and use, repository Git configuration and host executable DLL loading remain review considerations. Root and ancestor reparse points are rejected; the helper skips nested reparse entries. Concurrent application instances are not qualified; each instance has one active inspection and a shared pilot WebView profile.

Sources: `SPEC.md`, pre-implementation `MOCKUP.svg`, `VERIFICATION.md`, `SOURCES.md`. No root toolkit source files were changed. No reusable crate was extracted; internal adapter and UI model have explicit interfaces without introducing separately maintained packages.

Bounded prototype verification: 11 Rust tests, 2 frontend tests and the corrective native build passed (exit 0); independent audit accepts the code. Coordinator testing of the rebuilt native WebView2 exercised Inspect with a seeded test path, filtering, light theme, programmatic search focus and Cancel. The native folder picker passed on the prior revision. See `VERIFICATION.md` for evidence and remaining limits; full Windows keyboard and accessibility checks remain unverified. This is not a beta, release or production-readiness claim.
