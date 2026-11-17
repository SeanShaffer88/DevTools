# InputMapAuditor

Compare `project.godot` input action names to static script references and flag direct key constants.

```powershell
py -3 -m ai_tools input-map-auditor C:\Game
```

Argument: project directory (required); `--text` selects readable output. JSON v1 contains `actions`, `usedActions`, and findings (`MissingInputAction`, `UnusedInputAction`, `HardcodedKey`). Exit `0` pass, `2` error, `125` setup. Dynamic action names and generated project settings are outside the static scan.
