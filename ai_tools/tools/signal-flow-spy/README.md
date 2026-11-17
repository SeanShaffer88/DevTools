# SignalFlowSpy

Index static GDScript/C# signal declarations, emissions, and `.tscn`/script connections.

```powershell
py -3 -m ai_tools signal-flow-spy C:\Game
```

Argument: project directory (required); `--text` selects readable output. JSON v1 contains `signals`, `emissions`, `connections`, and common findings. Findings flag undeclared static references and signals with no detected use. Exit `0` when no errors, `2` for errors, `125` for setup. This is regex-based; it does not resolve inherited signals, dynamic callables, or signatures.
