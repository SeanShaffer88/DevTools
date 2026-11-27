#!/usr/bin/env python3
"""check-flutter-project.py - validate a Flutter project folder.

Usage: python3 check-flutter-project.py [project-dir]   (default: .)

Checks (PASS / WARN / FAIL lines, then a summary):
  * pubspec.yaml exists, and its `name:` and `version:` parse
  * lib/main.dart exists
  * analysis_options.yaml present (WARN if missing)
  * platform folders present (windows/ android/ ios/ macos/ linux/ web/)
  * environment sdk constraint present in pubspec (WARN if missing -
    a project with no constraint builds differently on every machine)
  * dependencies on the original `hive` or `isar` packages (WARN -
    both originals are unmaintained; see reference/dependencies.md)
  * `integration_test` taken from pub instead of the Flutter SDK
    (WARN - it must be `sdk: flutter` in dev_dependencies)

Exit codes: 0 = no FAIL, 1 = at least one FAIL, 2 = bad arguments.
Warnings do not change the exit code. Python 3, standard library only.
"""

import re
import sys
from pathlib import Path

PLATFORMS = ["windows", "android", "ios", "macos", "linux", "web"]
STALE = ("hive", "isar")

results = []  # (level, message)


def report(level, message):
    results.append((level, message))
    print(f"{level}: {message}")


def section_entries(text, section):
    """Yield (name, raw block) for entries directly under a top-level
    YAML section, using indentation only (simple subset parser)."""
    in_section = False
    current = None
    block = []
    for line in text.splitlines():
        if line.lstrip().startswith("#"):
            continue  # YAML comment - never an entry or block content
        if re.match(r"^\S", line):
            if current is not None:
                yield current, "\n".join(block)
            in_section = line.split(":")[0].strip() == section
            current, block = None, []
            continue
        if not in_section:
            continue
        m = re.match(r"^  ([A-Za-z0-9_\-]+):\s*(.*)$", line)
        if m:
            if current is not None:
                yield current, "\n".join(block)
            current, block = m.group(1), [m.group(2)]
        elif current is not None:
            block.append(line.strip())
    if current is not None:
        yield current, "\n".join(block)


def main(argv):
    root = Path(argv[1] if len(argv) > 1 else ".")
    if not root.is_dir():
        print(f"FAIL: {root} is not a folder")
        return 2

    pubspec = root / "pubspec.yaml"
    text = ""
    if not pubspec.is_file():
        report("FAIL", "pubspec.yaml not found - not a Flutter project folder")
    else:
        report("PASS", "pubspec.yaml found")
        text = pubspec.read_text(encoding="utf-8", errors="replace")
        name = re.search(r"^name:\s*(\S+)", text, re.M)
        if name:
            report("PASS", f"pubspec name: {name.group(1)}")
        else:
            report("FAIL", "pubspec.yaml has no parseable `name:` field")
        version = re.search(r"^version:\s*(\S+)", text, re.M)
        if version:
            report("PASS", f"pubspec version: {version.group(1)}")
        else:
            report("WARN", "pubspec.yaml has no `version:` field "
                           "(app stores need one: version: 1.0.0+1)")

        env = re.search(r"^environment:\s*\n((?:[ \t]+.*\n?)+)", text, re.M)
        sdk = re.search(r"sdk:\s*['\"]?([^\s'\"]+)", env.group(1)) if env else None
        if sdk:
            report("PASS", f"sdk constraint: {sdk.group(1)}")
        else:
            report("WARN", "no environment sdk constraint in pubspec.yaml - "
                           "pin one (e.g. sdk: ^3.14.0) so every machine "
                           "builds with the same Dart")

        deps = {n for n, _ in section_entries(text, "dependencies")}
        for stale in STALE:
            if stale in deps:
                report("WARN", f"dependency `{stale}` is the original, "
                               "unmaintained package - migrate to drift or "
                               "shared_preferences (see reference/dependencies.md)")
        dev = dict(section_entries(text, "dev_dependencies"))
        if "integration_test" in dev and "sdk:" not in dev["integration_test"]:
            report("WARN", "integration_test is pinned from pub - it must "
                           "come from the Flutter SDK: "
                           "integration_test: { sdk: flutter }")
        elif "integration_test" in dev:
            report("PASS", "integration_test comes from the Flutter SDK")

    if (root / "lib" / "main.dart").is_file():
        report("PASS", "lib/main.dart found")
    else:
        report("FAIL", "lib/main.dart not found")

    if (root / "analysis_options.yaml").is_file():
        report("PASS", "analysis_options.yaml found")
    else:
        report("WARN", "analysis_options.yaml missing - copy the pack "
                       "template (templates/analysis_options.yaml) so the "
                       "analyzer applies flutter_lints")

    present = [p for p in PLATFORMS if (root / p).is_dir()]
    if present:
        report("PASS", f"platform folders: {', '.join(present)}")
    else:
        report("WARN", "no platform folders found - run "
                       "`flutter create --platforms=... .` to add targets")

    fails = sum(1 for lvl, _ in results if lvl == "FAIL")
    warns = sum(1 for lvl, _ in results if lvl == "WARN")
    print(f"\n{len(results)} checks: {fails} FAIL, {warns} WARN")
    return 1 if fails else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
