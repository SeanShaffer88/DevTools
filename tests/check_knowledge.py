"""Check the knowledge library: manifests list real files, and relative
Markdown links point at files that exist. Python 3 standard library only.

Usage: python tests/check_knowledge.py [repo-root]
Exit code 0 = clean, 1 = problems found (each one is printed).
"""
import json
import re
import sys
from pathlib import Path

DOMAINS = ["godot", "knowledge", "kotlin", "flutter", "portableapps", "wow-addons"]
SKIP_PARTS = {".git", "vendor", "node_modules", "__pycache__"}
SKIP_FILES = {"ai-bundle.md"}  # generated; links point at the original files
LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")


def check_manifest(root, domain, problems):
    path = root / domain / "manifest.json"
    if not path.is_file():
        return
    data = json.loads(path.read_text(encoding="utf-8"))
    listed = [f["path"] for f in data.get("files", [])] + data.get("readingOrder", [])
    for rel in sorted(set(listed)):
        if not (root / domain / rel).is_file():
            problems.append(f"{domain}/manifest.json lists missing file: {rel}")


def check_links(root, md, problems):
    text = md.read_text(encoding="utf-8", errors="replace")
    text = re.sub(r"```.*?```", "", text, flags=re.S)  # ignore code blocks
    for target in LINK.findall(text):
        if re.match(r"^[a-z][a-z0-9+.-]*:", target, re.I) or target.startswith("#"):
            continue  # URL, mailto:, or in-page anchor
        target = target.split("#", 1)[0]
        if not target:
            continue
        if not (md.parent / target).exists():
            problems.append(f"{md.relative_to(root).as_posix()}: broken link -> {target}")


def main(argv):
    root = Path(argv[1] if len(argv) > 1 else Path(__file__).resolve().parents[1])
    problems = []
    md_files = [root / "INDEX.md"]
    for domain in DOMAINS:
        if not (root / domain).is_dir():
            continue
        check_manifest(root, domain, problems)
        md_files += [
            p for p in (root / domain).rglob("*.md")
            if not SKIP_PARTS.intersection(p.relative_to(root).parts) and p.name not in SKIP_FILES
        ]
    for md in md_files:
        if md.is_file():
            check_links(root, md, problems)
    for line in problems:
        print(line)
    print(f"checked {len(md_files)} Markdown files; {len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
