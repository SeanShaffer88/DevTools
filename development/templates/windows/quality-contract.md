# Windows application quality contract

Copy to a new project and replace every TODO. This is an original acceptance template, not an execution manifest.

- Product/task: TODO
- Supported OS/build/architecture: TODO
- Stack/compiler/SDK/runtime identities: TODO
- Exact build/test executable and argument arrays: TODO
- UI/domain/platform/persistence boundaries: TODO
- Portable or installed state directory and permitted host writes: TODO
- Idle/running/cancelling/failed transitions and operation deadline: TODO
- Child containment, handle lifetime and shutdown ownership: TODO
- Error recovery, bounded diagnostics and privacy: TODO
- Keyboard/focus/screen-reader/DPI/forced-color evidence: TODO
- Startup/idle CPU/peak memory/large-input budgets and measurement method: TODO
- Configuration migrations, rollback and interrupted-write fixtures: TODO
- Installer upgrade/uninstall or portable footprint cases: TODO
- Offline tool/cache inventory and disconnected build evidence: TODO
- Artifact hashes, notices, signing/update-channel evidence: TODO

Record each gate as Pass/Fail/Unknown/NotRun with command, exit code, artifact and date. A static pass does not establish runtime behavior. Preserve user data on failed migration or uninstall.
