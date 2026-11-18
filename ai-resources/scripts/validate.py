#!/usr/bin/env python3
"""Validate resources.json: required fields, https URLs, no exact duplicate URLs
except intentional cross-listings recorded in ALLOW_DUP, category files exist."""
import json, sys
from pathlib import Path
ROOT = Path(__file__).parent.parent
ALLOW_DUP = {"https://github.com/punkpeye/awesome-mcp-servers"}  # listed under MCP + discovery on purpose
def main():
    rows = json.loads((ROOT / "resources.json").read_text(encoding="utf-8"))
    errors, seen = [], {}
    for i, r in enumerate(rows):
        for k in ("name", "url", "kind", "category", "category_slug", "note"):
            if not r.get(k): errors.append(f"row {i}: missing {k}")
        if not r["url"].startswith("https://"): errors.append(f'row {i}: non-https URL {r["url"]}')
        if r["url"] in seen and r["url"] not in ALLOW_DUP:
            errors.append(f'duplicate URL {r["url"]} (rows {seen[r["url"]]} and {i})')
        seen[r["url"]] = i
        if not (ROOT / "categories" / f'{r["category_slug"]}.md').exists():
            errors.append(f'row {i}: missing category file for {r["category_slug"]}')
    print(f"{len(rows)} entries checked, {len(errors)} error(s)")
    for e in errors: print("ERROR:", e)
    return 1 if errors else 0
if __name__ == "__main__":
    raise SystemExit(main())
