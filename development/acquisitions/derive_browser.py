"""Create a modified offline reference ZIP from already extracted browser files.

Never runs an installer or browser. The caller must separately obtain/inspect the
pinned original installer and use a trusted extractor into a new scratch directory.
Only receipt-listed Browser/ files are read. The entire uBO extension is omitted.
"""
import argparse
import hashlib
import json
from pathlib import Path
import tempfile
import zipfile

from verify import Invalid, local

EXCLUDED = 'distribution/extensions/uBlock0@raymondhill.net.xpi'


def derive(root, output):
    receipt = json.loads((Path(__file__).parent / 'BROWSER-DERIVATION.json').read_text(encoding='utf8'))
    root, output = Path(root).absolute(), Path(output).absolute()
    for p in (root, *root.parents, output, *output.parents):
        if p.is_symlink() or getattr(p, 'is_junction', lambda: False)():
            raise Invalid('linked input/output path')
    if output.exists() or not output.parent.is_dir():
        raise Invalid('output must be a new file in an existing directory')
    temp = None
    try:
        with tempfile.NamedTemporaryFile(dir=output.parent, prefix='.browser-derived-', delete=False) as f:
            temp = Path(f.name)
        with zipfile.ZipFile(temp, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
            for member in receipt['inputMembers']:
                if member['path'] == EXCLUDED:
                    continue
                path = local(root, member['path'])
                if path.stat().st_size != member['sizeBytes']:
                    raise Invalid('source member size mismatch')
                h = hashlib.sha256()
                count = 0
                info = zipfile.ZipInfo('Browser/' + member['path'], date_time=(2026, 11, 16, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                info._compresslevel = 6
                with path.open('rb') as source, archive.open(info, 'w', force_zip64=True) as target:
                    while b := source.read(1024 * 1024):
                        count += len(b)
                        if count > member['sizeBytes']:
                            raise Invalid('source member grew')
                        h.update(b)
                        target.write(b)
                if (count, h.hexdigest()) != (member['sizeBytes'], member['sha256']):
                    raise Invalid('source member identity mismatch')
        if output.exists():
            raise Invalid('output exists')
        temp.rename(output)
        return {'modified': True, 'retainedMembers': len(receipt['inputMembers']) - 1,
                'excludedEntireExtension': EXCLUDED, 'browserExecuted': False}
    finally:
        if temp and temp.exists(): temp.unlink()


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--extracted-browser-root', required=True, type=Path)
    p.add_argument('--output', required=True, type=Path)
    args = p.parse_args()
    try:
        print(json.dumps(derive(args.extracted_browser_root, args.output), indent=2))
    except (OSError, ValueError, zipfile.BadZipFile) as e:
        print(json.dumps({'valid': False, 'error': str(e)}))
        raise SystemExit(2)
