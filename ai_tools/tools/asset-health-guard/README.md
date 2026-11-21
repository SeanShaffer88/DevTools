# AssetHealthGuard

Scan a Godot project for missing literal `res://` paths, large compressed image files, unreferenced audio, and implicit physics collision settings.

```powershell
py -3 -m ai_tools asset-health-guard C:\Game --max-texture-bytes 16777216
```

Arguments: project directory (required), `--max-texture-bytes` (default 16 MiB), `--max-uncompressed-texture-bytes` (default 256 MiB RGBA estimate), `--max-files` (default 20,000), `--text`. JSON v1 uses common `valid`, `findingCount`, and `findings` fields; findings include `code`, `path`, `severity`, and `message`. Exit `0` pass, `2` errors, `125` setup. Thresholds are local policies, not universal recommendations; decoded texture size is an estimate. A `res://` path containing a format placeholder (`%s`, `%d`, `%03d`, `%.2f`, `{}`, `{0}`, `{name}`) is built at runtime: it is reported as info-level `DynamicResourcePath` instead of `MissingResource`, is not checked for existence, and does not count as a reference, so audio loaded only through such a path still shows as `UnreferencedAudio`. Paths built by concatenation (`"res://a/" + name`) are checked only for their literal prefix.
