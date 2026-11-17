# SceneDiff

Compare two `.tscn` or `.tres` text files by node path and property.

```powershell
py -3 -m ai_tools scene-diff before.tscn after.tscn --project C:\Game
```

Arguments: `before`, `after` (required); `--project` checks `res://` references in the second file. Output is JSON schema v1 with `addedNodes`, `removedNodes`, `changedProperties` (`node`, `property`, `before`, `after`), and `brokenResourcePaths`. Exit `0` means no broken resources, `2` means broken paths, `125` means invalid input. The parser handles common text sections, not every Godot serialization feature.
