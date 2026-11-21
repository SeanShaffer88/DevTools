"""Repackage pinned Flutter SDK without bundled MinGit. No installation/execution.

Requires the separately obtained original publisher archive. Output must be new.
The output preserves all remaining member bytes; deflate byte identity can vary
between Python/zlib versions. inventory.json pins the actual reviewed output.
"""
import argparse
import copy
import hashlib
from pathlib import Path
import shutil
import tempfile
import zipfile

from verify import Invalid, archive_check

INPUT_SHA256 = '33c1e3d4dd08f1136ddb9c7976cfd2b0ab20296f1565b78ba176a4cbb4e140eb'
EXCLUDE = 'flutter/bin/mingit/'


def derive(source, destination):
    source, destination = Path(source).absolute(), Path(destination).absolute()
    for p in (source, *source.parents, destination, *destination.parents):
        if p.is_symlink() or getattr(p, 'is_junction', lambda: False)():
            raise Invalid('linked input/output path')
    if destination.exists() or not destination.parent.is_dir():
        raise Invalid('destination must be a new file in an existing directory')
    h = hashlib.sha256()
    with source.open('rb') as f:
        while b := f.read(1024 * 1024): h.update(b)
    if h.hexdigest() != INPUT_SHA256:
        raise Invalid('input does not match pinned publisher archive')
    excluded = retained = 0
    with source.open('rb') as f: archive_check(f, 'zip')
    temp = None
    try:
        with tempfile.NamedTemporaryFile(dir=destination.parent, prefix='.flutter-derived-', delete=False) as f:
            temp = Path(f.name)
        with zipfile.ZipFile(source) as original, zipfile.ZipFile(temp, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=1, allowZip64=True) as result:
            for info in original.infolist():
                if info.filename == EXCLUDE.rstrip('/') or info.filename.startswith(EXCLUDE):
                    excluded += 1
                    continue
                cloned = copy.copy(info)
                cloned.compress_type = zipfile.ZIP_DEFLATED
                # Public property since3.13; the fallback is needed on3.10–3.12.
                cloned._compresslevel = 1
                with original.open(info) as fi, result.open(cloned, 'w', force_zip64=True) as fo:
                    shutil.copyfileobj(fi, fo, 1024 * 1024)
                retained += 1
        if not excluded:
            raise Invalid('expected MinGit subtree absent')
        if destination.exists():
            raise Invalid('destination already exists')
        temp.rename(destination)
        return {'excludedMembers': excluded, 'retainedMembers': retained,
                'excludedPrefix': EXCLUDE, 'inputSha256': INPUT_SHA256,
                'modified': True, 'requiresExternalGit': True}
    finally:
        if temp and temp.exists(): temp.unlink()


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--input', required=True, type=Path)
    p.add_argument('--output', required=True, type=Path)
    args = p.parse_args()
    import json
    try:
        print(json.dumps(derive(args.input, args.output), indent=2))
    except (OSError, ValueError, zipfile.BadZipFile) as e:
        print(json.dumps({'valid': False, 'error': str(e)}))
        raise SystemExit(2)
