# InputMapAuditor

Compare `project.godot` input action names to static script references and flag direct key constants.

```powershell
py -3 -m ai_tools input-map-auditor C:\Game
```

Argument: project directory (required); `--text` selects readable output. JSON v1 contains `actions`, `usedActions`, and findings (`MissingInputAction`, `UnusedInputAction`, `HardcodedKey`). Exit `0` pass, `2` error, `125` setup. Only `key={...}` entries inside the `project.godot` `[input]` section are treated as actions; other sections with the same shape (for example `[shader_globals]`) are ignored. Limitations: dynamic action names and generated project settings are outside the static scan, and only `is_action(`, `is_action_just_pressed(`, `is_action_just_released(` and `get_action_strength(` calls count as uses.
