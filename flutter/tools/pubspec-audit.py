#!/usr/bin/env python3
"""pubspec-audit.py - audit a pubspec.yaml against this pack's snapshot.

Usage: python3 pubspec-audit.py [path/to/pubspec.yaml]   (default: ./pubspec.yaml)

Parses the dependencies / dev_dependencies / dependency_overrides
sections of pubspec.yaml (simple YAML subset: indented `name: version`
lines and block-style entries) and compares each version against
tools/package-snapshot.json, the verified November 2026 snapshot that
ships with this pack. Fully offline - it never contacts pub.dev.

Per dependency it reports one of:
  PASS  - matches or is newer than the snapshot
  WARN  - older than the snapshot (an update exists in the snapshot)
  STALE - hive / isar: the original packages are unmaintained
  INFO  - not in the snapshot (unknown - check pub.dev yourself)
Hosted/git/path dependencies are listed as INFO with their source.

Exit codes: 0 = nothing older or stale, 1 = at least one WARN/STALE,
2 = file missing or unparseable. Python 3, standard library only.
"""

import json
import re
import sys
from pathlib import Path

SNAPSHOT = Path(__file__).with_name("package-snapshot.json")
SECTIONS = ("dependencies", "dev_dependencies", "dependency_overrides")


def parse_version(text):
    """Extract the first concrete version from a constraint string."""
    m = re.search(r"(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?", text or "")
    if not m:
        return None
    return tuple(int(x) if x else 0 for x in m.groups())


def parse_pubspec(text):
    """Return {section: {name: raw constraint / block text}}."""
    out = {s: {} for s in SECTIONS}
    section = None
    current = None
    for line in text.splitlines():
        if line.lstrip().startswith("#"):
            continue  # YAML comment - never a dependency or block content
        if re.match(r"^\S", line):
            key = line.split(":")[0].strip()
            section = key if key in SECTIONS else None
            current = None
            continue
        if section is None:
            continue
        m = re.match(r"^  ([A-Za-z0-9_\-]+):\s*(.*)$", line)
        if m:
            current = m.group(1)
            out[section][current] = m.group(2).split("#")[0].strip()
        elif current is not None and line.strip():
            prev = out[section][current]
            out[section][current] = (prev + " " + line.strip()).strip()
    return out


def main(argv):
    path = Path(argv[1] if len(argv) > 1 else "pubspec.yaml")
    if not path.is_file():
        print(f"FAIL: {path} not found")
        return 2
    try:
        snap = json.loads(SNAPSHOT.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"FAIL: cannot read snapshot {SNAPSHOT}: {exc}")
        return 2
    known = snap.get("packages", {})
    stale = snap.get("stale", {})
    print(f"Snapshot: {snap.get('snapshotDate', 'unknown date')} "
          f"(Flutter {snap.get('flutter')}, Dart {snap.get('dart')}) - "
          "offline comparison, re-check pub.dev for live versions.\n")

    sections = parse_pubspec(path.read_text(encoding="utf-8", errors="replace"))
    # (parser ignores comment lines and strips inline comments)
    problems = 0
    total = 0
    for section in SECTIONS:
        deps = sections[section]
        if not deps:
            continue
        print(f"[{section}]")
        for name, raw in sorted(deps.items()):
            if name == "flutter":
                continue
            total += 1
            if name in stale:
                print(f"  STALE: {name} ({raw or 'no version'}) - {stale[name]}")
                problems += 1
                continue
            if "git:" in raw or "path:" in raw or "url:" in raw:
                print(f"  INFO: {name} - non-pub source ({raw[:60]})")
                continue
            version = parse_version(raw)
            if name not in known:
                print(f"  INFO: {name} ({raw or 'no version'}) - "
                      "not in snapshot, check pub.dev")
                continue
            snap_v = parse_version(known[name])
            if version is None:
                print(f"  INFO: {name} ({raw or 'no version'}) - "
                      f"snapshot has {known[name]}, constraint has no "
                      "concrete version to compare")
            elif version >= snap_v:
                print(f"  PASS: {name} {raw} (snapshot {known[name]})")
            else:
                print(f"  WARN: {name} {raw} is older than snapshot "
                      f"{known[name]} - run `flutter pub upgrade {name}` "
                      "and re-test")
                problems += 1
        print()
    print(f"{total} dependencies compared, {problems} older/stale")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
