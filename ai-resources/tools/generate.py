#!/usr/bin/env python3
"""Generate categories/*.md, resources.json, resources.csv, llms.txt and counts
from tools/catalog.py + tools/catalog2.py. Run: python3 tools/generate.py"""
import csv, json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from catalog import CATEGORIES
from catalog2 import CATEGORIES2

ROOT = Path(__file__).resolve().parent.parent
ALL = CATEGORIES + CATEGORIES2

def main():
    rows, total = [], 0
    index_lines = []
    for slug, title, intro, entries in ALL:
        total += len(entries)
        body = [f"# {title}", "", intro, "", f"**{len(entries)} resources.**", ""]
        for name, url, kind, note in entries:
            body.append(f"- **[{name}]({url})** — _{kind}._ {note}")
            rows.append({"name": name, "url": url, "kind": kind,
                         "category": title, "category_slug": slug, "note": note})
        body.append("")
        body.append("_Part of [AI Knowledge Vault](../README.md). Verify every resource at its primary source before relying on it._")
        (ROOT / "categories" / f"{slug}.md").write_text("\n".join(body) + "\n", encoding="utf-8", newline="\n")
        index_lines.append(f"- [{title}](categories/{slug}.md) ({len(entries)})")
    (ROOT / "resources.json").write_text(json.dumps(rows, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    with open(ROOT / "resources.csv", "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["name","url","kind","category","category_slug","note"])
        w.writeheader(); w.writerows(rows)
    llms = ["# AI Knowledge Vault", "",
            "> A curated, AI-readable index of toolchains, useful repositories, MCP servers, agent frameworks, local inference, RAG, evaluation, and learning resources. Summaries are pointers — the knowledge lives at the linked primary sources.",
            "", f"{total} resources in {len(ALL)} categories.", "", "## Start here", "",
            "- [README](README.md): what this is, the point-your-AI prompt, and honest limits",
            "- [AGENTS](AGENTS.md): instructions for an AI consuming this repo", "",
            "## Categories", ""] + index_lines + ["",
            "## Machine-readable", "", "- [resources.json](resources.json)", "- [resources.csv](resources.csv)"]
    (ROOT / "llms.txt").write_text("\n".join(llms) + "\n", encoding="utf-8", newline="\n")
    print(f"{total} entries, {len(ALL)} categories, {len({r['url'] for r in rows})} distinct URLs")

if __name__ == "__main__":
    main()
