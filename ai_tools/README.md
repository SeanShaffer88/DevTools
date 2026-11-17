# AI-native Developer Utilities

Fifteen local CLI helpers for Godot, WoW addons, and Rust/general project maintenance. They use Python 3.10+ and the standard library only; no package install, telemetry, or network service is built into the suite. The repository's existing PowerShell tools remain unchanged.

From the repository root on Windows 11 x64:

```powershell
py -3 -m ai_tools --help
py -3 -m ai_tools scene-diff .\old.tscn .\new.tscn --project C:\Projects\Game
```

Each command defaults to compact JSON (`schemaVersion: 1`) and supports `--text` where applicable. The individual command guides describe arguments, output fields, examples, and limitations.

| Command | Guide | Purpose |
| --- | --- | --- |
| `scene-diff` | [SceneDiff](tools/scene-diff/README.md) | Compare Godot text scenes/resources and literal resource paths |
| `asset-health-guard` | [AssetHealthGuard](tools/asset-health-guard/README.md) | Find missing references, large assets, unreferenced audio, implicit collision settings |
| `signal-flow-spy` | [SignalFlowSpy](tools/signal-flow-spy/README.md) | Index static GDScript/C# signal declarations and uses |
| `godot-test-harness` | [GTHarness](tools/godot-test-harness/README.md) | Run an explicitly acknowledged headless Godot test script |
| `input-map-auditor` | [InputMapAuditor](tools/input-map-auditor/README.md) | Compare static script input actions with `project.godot` |
| `state-time-machine-validator` | [StateTimeMachineValidator](tools/state-time-machine-validator/README.md) | Validate JSON state graphs and save schema versions |
| `toc-manifest-linter` | [TocManifestLinter](tools/toc-manifest-linter/README.md) | Check WoW TOC metadata, target interface, and listed files |
| `addon-memory-taint-auditor` | [AddonMemoryTaintAuditor](tools/addon-memory-taint-auditor/README.md) | Flag Lua patterns needing secure-execution review |
| `saved-variables-inspector` | [SavedVariablesInspector](tools/saved-variables-inspector/README.md) | Parse a safe SavedVariables table-literal subset without Lua execution |
| `addon-api-compat-checker` | [AddonApiCompatChecker](tools/addon-api-compat-checker/README.md) | Search against a small, advisory API compatibility catalog |
| `cargo-semantic-lint` | [CargoSemanticLint](tools/cargo-semantic-lint/README.md) | Run offline Cargo check/clippy and prioritize rustc diagnostics |
| `module-dep-graph` | [ModuleDepGraph](tools/module-dep-graph/README.md) | Approximate Rust module/import graph and cycle scan |
| `export-matrix` | [ExportMatrix](tools/export-matrix/README.md) | Validate declared export profiles without building/signing |
| `portable-env-auditor` | [PortableEnvAuditor](tools/portable-env-auditor/README.md) | Find source markers for network, telemetry, and broad writes |
| `release-manifest-gen` | [ReleaseManifestGen](tools/release-manifest-gen/README.md) | Generate SHA-256 manifest text and x64 release-name suggestions |

## Output and safety

Most commands return exit `0` for a clean check, `2` for reported findings or a failed child, and `125` for invalid/setup/refused input. The command-specific guide is authoritative where it documents a more specific exit behavior. Results label the scanned scope; static checks are not proof of runtime behavior.

Scanners are read-only. GTHarness runs project code, Cargo writes build output, and ReleaseManifestGen writes only when given `--output`. GTHarness requires `--allow-project-code`; CargoSemanticLint requires `--allow-build-scripts`. Those options acknowledge that Godot code, Cargo build scripts, and proc macros execute with the caller's permissions. They are not sandboxes. Cargo checks force Cargo offline mode. Review file paths and child output before sharing JSON, since local project details may be sensitive.

Windows ARM64, Android ARM64, and Linux ARM64 targets are intentionally not included. ExportMatrix accepts only `windows-x64`, `android-x86_64`, and `linux-x64`; it validates declarations but does not build artifacts or manage keys.

## Tests

Run the offline smoke suite from the repository root:

```powershell
py -3 -m unittest -v tests.test_ai_tools
```

The tests use temporary local fixtures and do not launch Godot, Cargo, Lua, or a WoW client.
