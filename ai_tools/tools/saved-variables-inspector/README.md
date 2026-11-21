# SavedVariablesInspector

Safely parse a bounded subset of SavedVariables Lua table literals without evaluating Lua.

```powershell
py -3 -m ai_tools saved-variables-inspector Account.lua --json-data
```

Arguments: file (required), `--max-bytes` (default 4 MiB), optional `--schema` JSON (`{"requiredKeys":["profile","version"]}`), `--json-data`, optional `--sanitize-json` to write normalized JSON to a new file, and `--text`. Input supports top-level `Name = {}` table literals with primitive values and nested tables. JSON v1 contains `variables`, `stats`, findings, and optionally `data`. Exit `0` parsed, `125` unsupported/malformed input. Output is never Lua; existing output paths are refused. Expressions and executable Lua are refused.
