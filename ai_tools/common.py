"""Shared bounded I/O and JSON helpers for the AI developer utilities."""
from __future__ import annotations

import json
import os
from pathlib import Path
import sys
from typing import Any, Iterable

MAX_FILE_BYTES = 8 * 1024 * 1024
MAX_FILES = 20_000
SKIP_DIRS = {".git", ".venv", "venv", "node_modules", "target", "bin", "obj", ".godot"}


def emit(value: Any, as_json: bool = True) -> None:
    if as_json:
        print(json.dumps(value, ensure_ascii=False, separators=(",", ":")))
    else:
        print(value if isinstance(value, str) else json.dumps(value, ensure_ascii=False, indent=2))


def read_text(path: Path, limit: int = MAX_FILE_BYTES) -> str:
    if path.stat().st_size > limit:
        raise ValueError(f"file exceeds {limit} byte limit: {path}")
    return path.read_text(encoding="utf-8-sig", errors="replace")


def walk_files(root: Path, suffixes: Iterable[str] | None = None,
               max_files: int = MAX_FILES) -> list[Path]:
    root = root.resolve(strict=True)
    if not root.is_dir():
        raise ValueError("root must be a directory")
    allowed = {x.lower() for x in suffixes} if suffixes else None
    result: list[Path] = []
    for current, dirs, names in os.walk(root, followlinks=False):
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS and
                         not (Path(current) / d).is_symlink())
        for name in sorted(names):
            p = Path(current) / name
            if p.is_symlink() or (allowed and p.suffix.lower() not in allowed):
                continue
            result.append(p)
            if len(result) > max_files:
                raise ValueError(f"tree exceeds {max_files} file limit")
    return result


def finding(code: str, path: str, severity: str, message: str,
            **extra: Any) -> dict[str, Any]:
    return {"code": code, "path": path, "severity": severity,
            "message": message, **extra}


def result(tool: str, findings: list[dict[str, Any]], **extra: Any) -> dict[str, Any]:
    errors = sum(f.get("severity") == "error" for f in findings)
    return {"schemaVersion": 1, "tool": tool, "valid": errors == 0,
            "findingCount": len(findings), "findings": findings, **extra}


def root_parser(description: str):
    import argparse
    p = argparse.ArgumentParser(description=description)
    p.add_argument("--text", action="store_true", help="print readable text instead of compact JSON")
    return p


def finish(tool: str, findings: list[dict[str, Any]], text: bool = False,
           **extra: Any) -> int:
    payload = result(tool, findings, **extra)
    emit(payload, not text)
    return 2 if not payload["valid"] else 0


def project_path(root: Path, value: str) -> Path:
    """Resolve a project-relative path and refuse escapes."""
    base = root.resolve()
    candidate = (base / value.replace("res://", "")).resolve()
    if candidate != base and base not in candidate.parents:
        raise ValueError(f"path escapes project root: {value}")
    return candidate


def stderr_error(message: str) -> int:
    print(json.dumps({"schemaVersion": 1, "valid": False, "error": message}),
          file=sys.stderr)
    return 125
