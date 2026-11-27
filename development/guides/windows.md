# Windows software

Original offline lifecycle guidance; commands depend on the selected project and installed toolchain. This pack does not contain a Windows SDK or certify a shipped application.

## Decide and prepare

Record supported Windows versions, x64/ARM64 targets, portable versus installed state, elevation, file associations, multi-instance behavior and integrations. Choose Win32/C++ or Rust for direct OS control, WPF for established managed desktop UI, or a webview when reuse justifies its runtime cost. Record the reason, not just the framework name. Verify actual compilers, SDK and runtime before generating build configuration.

Use canonical [Windows engineering guidance](../../knowledge/README.md) and the [WinDevKit catalog](../../windevkit/docs/CATALOG.md). Read component contracts and licenses before adoption; reference presence is not tested compatibility.

## Implement

Separate domain rules, platform access, persistence and UI. Start with `src/domain`, `src/platform`, `src/ui`, `tests/fixtures` and `packaging` only when those boundaries help. Model idle/running/cancelling/failed transitions explicitly. Validate resource ownership before side effects; dispose handles and subscriptions. Establish child-process containment before execution when cancellation must terminate descendants. Never block the UI thread waiting for a subprocess or a large directory traversal.

Document every host write and cleanup path. Portable state must remain in the declared boundary; settings and saves need versioned formats and transactional migration. Preserve prior user data on failure. Keep bounded diagnostic identifiers and error codes, without credentials or source contents.

## Build and verify

For a declared .NET solution, normal interfaces are `dotnet build` and `dotnet test`; for a Rust workspace, `cargo test --locked` and `cargo build --locked`; CMake builds require an already verified configuration/preset. These are examples, not inferred commands to execute. Read project instructions and use the existing toolkit build runner with an explicit executable/argument array. Offline execution requires matching packages and SDKs already acquired.

Test malformed paths, reparse points, Unicode, long paths, access denial, cancellation, disk exhaustion and repeated operations. Exercise keyboard-only operation, visible focus, screen-reader names, forced colors and DPI changes on the real native application. Static UI assertions do not certify accessibility. Measure cold start, idle CPU, memory and representative large inputs before claiming performance gains.

## Release and offline readiness

Require a clean build, hashes, supported-OS smoke, versioned configuration, license notices, rollback and upgrade/uninstall or portable-footprint evidence. Signing identity and update channels need separate verification. Prepare compiler, SDK, dependency cache, required runtime, symbols and build tools before disconnecting. Rebuild with network unavailable in an isolated environment; record missing components rather than silently substituting versions.

Start with [the quality contract](../templates/windows/quality-contract.md). Record exact commands, exit codes and the difference between static, host-runtime and distribution checks. This is original operational material, not copied vendor documentation.
