# Workflow Tools

Standalone, standard-library Python utilities for local development workflows. Target: Windows 11 x64. Imported from [GateRunner](https://github.com/SeanShaffer88/GateRunner) and [FieldVerify](https://github.com/SeanShaffer88/FieldVerify); both source repositories remain unchanged.

- [GateRunner](gaterunner/README.md) — reviewed `gate.toml` steps, ordered execution, timeouts, warnings, progress, and ETA. Requires Python 3.11+ (`tomllib`). Run `py -3.11 .\workflow_tools\gaterunner\gaterunner.py run .\workflow_tools\gaterunner\gate.toml --dry-run` first.
- [FieldVerify](fieldverify/README.md) — reviewed JSON checklists for file, environment, command, and manual checks; writes local JSON/Markdown evidence and optional logs/zip. Requires Python 3.10+.

Both can execute commands from configuration. Prefer argv arrays, inspect configuration before running, and review output bundles before sharing. FieldVerify omits the hostname by default and never writes the tested environment-variable value into report details. No telemetry or automatic upload.
