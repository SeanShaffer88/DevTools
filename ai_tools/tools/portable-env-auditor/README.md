# PortableEnvAuditor

Search source files for URL/telemetry markers and suspicious write calls paired with broad paths.

```powershell
py -3 -m ai_tools portable-env-auditor C:\Projects\App
```

Arguments: root directory (required), `--max-files` (default 20,000), `--text`. JSON v1 contains common findings and `filesScanned`. Exit `0` no errors, `2` errors, `125` setup. Findings are text matches only; a clean result cannot certify offline or zero-telemetry behavior.
