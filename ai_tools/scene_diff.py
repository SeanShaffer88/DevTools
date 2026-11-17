"""Semantic, bounded comparator for Godot text scenes/resources."""
from __future__ import annotations
import argparse, re
from pathlib import Path
from .common import emit, read_text, project_path, stderr_error

SECTION = re.compile(r'^\[(node|ext_resource|sub_resource)\b(.*?)\]\s*$')
ATTR = re.compile(r'([A-Za-z_][\w]*)\s*=\s*("(?:\\.|[^"])*"|[^\s]+)')

def parse(path: Path) -> dict:
    text = read_text(path)
    nodes, resources, current = {}, [], None
    for line_no, line in enumerate(text.splitlines(), 1):
        m = SECTION.match(line.strip())
        if m:
            kind, raw = m.groups()
            fields = {k: v.strip('"') for k, v in ATTR.findall(raw)}
            current = None
            if kind == "node":
                name, parent = fields.get("name"), fields.get("parent", ".")
                key = name if parent == "." else f"{parent}/{name}"
                current = key
                nodes[key] = {"type": fields.get("type"), "properties": {}, "line": line_no}
            elif kind == "ext_resource":
                resources.append({"path": fields.get("path", ""), "line": line_no})
            continue
        if current and "=" in line and not line.lstrip().startswith("#"):
            k, v = line.split("=", 1)
            nodes[current]["properties"][k.strip()] = v.strip()
    return {"nodes": nodes, "resources": resources}

def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("before", type=Path); p.add_argument("after", type=Path)
    p.add_argument("--project", type=Path, help="check res:// references against this project")
    a = p.parse_args(argv)
    try:
        left, right = parse(a.before), parse(a.after)
        lk, rk = set(left["nodes"]), set(right["nodes"])
        changed = []
        for key in sorted(lk & rk):
            x, y = left["nodes"][key], right["nodes"][key]
            props = sorted(set(x["properties"]) | set(y["properties"]))
            for prop in props:
                if x["properties"].get(prop) != y["properties"].get(prop):
                    changed.append({"node": key, "property": prop,
                                    "before": x["properties"].get(prop),
                                    "after": y["properties"].get(prop)})
        broken = []
        if a.project:
            for r in right["resources"]:
                if r["path"].startswith("res://") and not project_path(a.project, r["path"]).exists():
                    broken.append(r)
        emit({"schemaVersion": 1, "tool": "SceneDiff",
              "addedNodes": sorted(rk-lk), "removedNodes": sorted(lk-rk),
              "changedProperties": changed, "brokenResourcePaths": broken,
              "limitations": ["Text parser handles common Godot section/property syntax; it is not Godot's parser."]})
        return 2 if broken else 0
    except (OSError, ValueError) as e: return stderr_error(str(e))

if __name__ == "__main__": raise SystemExit(main())
