# CargoSemanticLint (CSL)

Run `cargo check` and `cargo clippy`, parsing rustc JSON diagnostics into compact records.

```powershell
py -3 -m ai_tools cargo-semantic-lint C:\Projects\App --allow-build-scripts
```

Arguments: project directory (required), `--timeout` (default 600 seconds per command), and required `--allow-build-scripts`. JSON v1 has `checks[]` with command, exit code, timeout status, and diagnostic `level`, `message`, `code`, `file`, `line`, and `column`. Exit `0` pass, `2` check failure, `125` setup/refusal. Cargo may run build scripts/proc macros and may access configured registries; this is not sandboxed.
