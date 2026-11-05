# Project Inspector pilot

First slice: Windows x64, Tauri 2, framework-free embedded HTML/CSS/JS. No automatic inspection, network integration, builds of inspected projects, or helper selection.

Modules: `adapter` validates paths, pins the existing helper and pwsh identity, executes the fixed argument array and validates schema 1. `main` provides select_folder/inspect/cancel IPC. UI renders data as text, binds request IDs and filters evidence locally. Modules stay internal: no independently distributed reusable package is justified yet.

One active request. Cancel signals only its owned worker; timeout 15 seconds; each output stream bounded to 1 MiB. Successful output requires exit 0, UTF-8 JSON, schemaVersion 1, expected path/maxDepth/entryLimit and all documented field types. Helper failures retain bounded raw evidence. Paths must be absolute local existing directories, without reparse points in any ancestor; reject UNC/device namespaces. Validate again immediately before execution; concurrent filesystem mutation is outside this prototype's security isolation contract.

Mockup: MOCKUP.svg. White/gray workspace, navy sidebar, blue action, Segoe UI. System/light/dark selection, visible keyboard focus, reduced motion, live status and searchable text. No remote assets.

Acceptance: Rust tests for schema/paths/timeout/cancel/output bounds and actual same-fixture CLI parity; JS behavior tests; Windows build; native window smoke; independent audit. Missing runtime checks remain explicit incomplete gates. SDK inventory and all other helpers deferred.
