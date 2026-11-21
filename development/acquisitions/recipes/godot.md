# Godot editor, .NET support and export templates

Status: **partial**. This is payload coverage, not an installed/complete offline toolchain.

Acquired payload IDs: `godot-win-x64`, `godot-export-templates`.

Remaining requirements and limits: Matching Godot standard Windows editor and export templates retained with source license/COPYRIGHT notices. Android/other platform SDKs, .NET variant, project assets/plugins/imports and actual export/runtime checks remain required.

Verify from the repository root: `python development/acquisitions/verify.py verify`. The verifier reads local bytes only and checks archive contents without extraction/execution. `inventory.json` records exact source, version/revision, hashes, retained license paths and publisher-checksum evidence.

Upstream preparation/terms references:
- https://docs.godotengine.org/en/4.5/tutorials/export/exporting_projects.html
- https://godotengine.org/license/
