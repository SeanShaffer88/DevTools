# Contributing

This catalog is generated. **Do not edit `categories/*.md`, `resources.json`, `resources.csv`, or `llms.txt` by hand.**

1. Add or change entries in `tools/catalog.py` / `tools/catalog2.py` — tuple format: `(name, url, kind, note)`.
2. Note style: one or two plain sentences — what it is, and when to reach for it. No marketing copy, no competitor comparisons, no claims you have not checked at the source.
3. Prefer primary sources: official docs, the project's own repo, the official registry. Directories and awesome lists belong mainly in the discovery category.
4. Run:

```sh
python3 tools/generate.py
python3 scripts/validate.py
```

Both must pass (validator enforces https URLs, required fields, category files, and no accidental duplicate URLs).
5. If a resource has moved or died, update the entry and mention the check date in your PR description.
