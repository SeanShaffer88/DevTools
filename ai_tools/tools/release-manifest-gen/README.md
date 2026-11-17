# ReleaseManifestGen

Hash release files with SHA-256 and suggest conventional x64 installer/portable names.

```powershell
py -3 -m ai_tools release-manifest-gen .\dist --output .\dist\SHA256SUMS.txt
```

Arguments: release directory (required), optional `--output` for a new manifest file, `--text`. JSON v1 includes `fileCount`, `manifest` lines, `writtenTo`, and `renameSuggestions`. Exit `0` success, `125` setup or overwrite refusal. Inputs are never renamed; output path must not already exist.
