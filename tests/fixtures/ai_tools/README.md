# AI utility fixtures

One inert fixture folder per command. Tests use these files to exercise parser, reporting, and safety-gate behavior without downloading dependencies or opening game clients.

| Folder | Exercises |
| --- | --- |
| `scene-diff` | Added node and transform change |
| `asset-health-guard` | Missing `res://` reference |
| `signal-flow-spy` | Declared/emitted signal and unknown scene connection |
| `godot-test-harness` | Project/script paths; test uses Python's invalid-option response, not the Godot script |
| `input-map-auditor` | Missing action and raw key constant |
| `state-time-machine-validator` | Versioned state graph with dangling edge |
| `toc-manifest-linter` | TOC metadata and nested XML-to-Lua load order |
| `addon-memory-taint-auditor` | Advisory secure-execution patterns |
| `saved-variables-inspector` | Nested table literal with a comment-like string |
| `addon-api-compat-checker` | One symbol from the advisory catalog |
| `cargo-semantic-lint` | Rustc JSON diagnostic; subprocess is mocked in tests |
| `module-dep-graph` | Two-module import cycle |
| `export-matrix` | Windows x64, Android x86_64, and Linux x64 profiles |
| `portable-env-auditor` | URL marker and broad write path |
| `release-manifest-gen` | Installer/portable naming suggestions and hashes |

These are synthetic parser fixtures. They do not certify Godot, Cargo, or WoW runtime behavior.
