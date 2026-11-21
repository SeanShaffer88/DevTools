# AddonApiCompatChecker

Search Lua addon files for a small built-in advisory list of API names whose modern signatures may differ.

```powershell
py -3 -m ai_tools addon-api-compat-checker C:\AddOns\Example --interface 110200
```

Arguments: addon directory and `--interface` (required); optional `--text`. JSON v1 contains `targetInterface`, `advisoryCatalogVersion`, `matchedSymbols`, and common findings. Exit `0` pass, `2` errors, `125` setup. The embedded list is not authoritative; verify findings against exact client API documentation.
