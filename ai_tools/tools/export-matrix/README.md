# ExportMatrix

Validate a user-supplied export profile matrix without invoking builds or signers.

```powershell
py -3 -m ai_tools export-matrix C:\Projects\Game --profiles profiles.json
```

Profile input shape: `{"profiles":[{"engine":"godot","target":"windows-x64","os":"Windows 11 x64"},{"engine":"rust","target":"linux-x64"}]}`. Supported targets are Windows x64, Android x86_64, and Linux x64; ARM64 is intentionally excluded. Arguments: project directory and `--profiles` JSON file (required). JSON v1 reports `profilesChecked`, findings, and explicit `buildsRun:false`/`signingPerformed:false`. Exit `0` pass, `2` invalid profile, `125` setup.
