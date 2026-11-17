# AssetHealthGuard

Scan a Godot project for missing literal `res://` paths, large compressed image files, unreferenced audio, and implicit physics collision settings.

```powershell
py -3 -m ai_tools asset-health-guard C:\Game --max-texture-bytes 16777216
```

Arguments: project directory (required), `--max-texture-bytes` (default 16 MiB), `--max-uncompressed-texture-bytes` (default 256 MiB RGBA estimate), `--max-files` (default 20,000), `--text`. JSON v1 uses common `valid`, `findingCount`, and `findings` fields; findings include `code`, `path`, `severity`, and `message`. Exit `0` pass, `2` errors, `125` setup. Thresholds are local policies, not universal recommendations; dynamic references are missed and decoded texture size is an estimate.
