# TocManifestLinter

Check WoW addon TOC metadata, interface number, in-directory Lua/XML file references, and basic load ordering.

```powershell
py -3 -m ai_tools toc-manifest-linter C:\AddOns\Example --interface 110200
```

Arguments: addon directory (required), optional `--toc` (required when multiple TOCs exist), optional `--interface`, `--text`. JSON v1 contains `metadata`, `loadOrder`, and common findings. Exit `0` pass, `2` findings with errors, `125` invalid input. It does not execute addon code or validate against a live client.
