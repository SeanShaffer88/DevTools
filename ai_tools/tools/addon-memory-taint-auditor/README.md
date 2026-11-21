# AddonMemoryTaintAuditor

Scan Lua addon code for patterns that merit WoW secure-execution/taint review.

```powershell
py -3 -m ai_tools addon-memory-taint-auditor C:\AddOns\Example
```

Argument: addon directory (required); `--text` selects readable output. JSON v1 uses common findings with heuristic rule codes and line numbers. Exit `0` when no errors, `2` on errors, `125` on setup. Every match is advisory; no taint propagation, client runtime, or combat lockdown behavior is modeled.
