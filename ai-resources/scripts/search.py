#!/usr/bin/env python3
"""Search resources.json by words in name/category/note/url. No dependencies.
Usage: python3 scripts/search.py "mcp server" [--json]"""
import json, sys
from pathlib import Path
def main():
    args = [a for a in sys.argv[1:] if a != "--json"]
    as_json = "--json" in sys.argv
    if not args:
        print(__doc__); return 1
    rows = json.loads((Path(__file__).parent.parent / "resources.json").read_text(encoding="utf-8"))
    words = " ".join(args).lower().split()
    hits = [r for r in rows if all(w in (r["name"]+" "+r["category"]+" "+r["note"]+" "+r["url"]).lower() for w in words)]
    if as_json:
        print(json.dumps(hits, indent=2))
    else:
        for r in hits: print(f'{r["name"]}\n  {r["url"]}\n  [{r["category"]}] {r["note"]}\n')
        print(f"{len(hits)} match(es)")
    return 0
if __name__ == "__main__":
    raise SystemExit(main())
