"""Offline artifact integrity and inert archive inspection. Never installs or extracts."""
from __future__ import annotations

import argparse
import bisect
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import struct
import tarfile
import tempfile
import zipfile
from urllib.parse import urlsplit

RECIPE_IDS = frozenset(('windows-sdk', 'dotnet-nuget', 'webview2', 'android-sdk',
    'gradle', 'node-npm', 'rust-cargo', 'python-wheels', 'cpp-packages', 'godot',
    'flutter', 'browsers', 'userscript-manager', 'userstyle-manager', 'unity',
    'unreal', 'platform-services', 'media-assets', 'portableapps'))
# The pinned Firefox source has 510,603 members (3,519,444,241 expanded bytes).
# Keep a finite reviewed ceiling with modest room for archive directory entries.
MAX_MEMBERS = 550000
MAX_EXPANDED = 32 * 1024**3
MAX_MEMBER = 4 * 1024**3
CHUNK = 1024 * 1024


class Invalid(ValueError):
    pass


def relative(value):
    if not isinstance(value, str) or not value or '\\' in value or ':' in value or '\0' in value:
        raise Invalid('invalid relative path')
    p = PurePosixPath(value)
    if p.is_absolute() or any(x in ('', '.', '..') for x in value.split('/')):
        raise Invalid('path escape or ambiguous path')
    if any(x.rstrip(' .') != x for x in p.parts):
        raise Invalid('Windows path alias')
    if any(re.fullmatch(r'(?i)(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\..*)?', x) for x in p.parts):
        raise Invalid('reserved Windows path')
    return p


def local(root, value, exists=True):
    p = relative(value)
    root = Path(root).absolute()
    for q in (root, *root.parents):
        if q.exists() and (q.is_symlink() or getattr(q, 'is_junction', lambda: False)()):
            raise Invalid('linked root')
    current = root
    for part in p.parts:
        current /= part
        if current.is_symlink() or getattr(current, 'is_junction', lambda: False)():
            raise Invalid('linked path')
    if exists and not current.is_file():
        raise Invalid('missing regular file: ' + value)
    return current


def digest(path, expected_size):
    if path.stat().st_size != expected_size:
        raise Invalid('file size mismatch: ' + str(path))
    h = hashlib.sha256()
    size = 0
    with path.open('rb') as f:
        while b := f.read(min(CHUNK, expected_size - size + 1)):
            h.update(b)
            size += len(b)
            if size > expected_size:
                raise Invalid('file grew beyond declared size')
    return size, h.hexdigest()


class Parts(io.RawIOBase):
    """Seekable view of immutable contiguous parts; never materializes an archive."""
    def __init__(self, paths):
        self.paths = paths
        self.offsets = [0]
        for p in paths:
            self.offsets.append(self.offsets[-1] + p.stat().st_size)
        self.position = 0

    def readable(self): return True
    def seekable(self): return True
    def tell(self): return self.position

    def seek(self, offset, whence=0):
        n = offset + (self.position if whence == 1 else self.offsets[-1] if whence == 2 else 0)
        if whence not in (0, 1, 2) or n < 0:
            raise Invalid('invalid seek')
        self.position = n
        return n

    def read(self, size=-1):
        remaining = max(0, self.offsets[-1] - self.position)
        size = remaining if size < 0 else min(size, remaining)
        result = bytearray()
        while size:
            index = bisect.bisect_right(self.offsets, self.position) - 1
            take = min(size, self.offsets[index + 1] - self.position)
            with self.paths[index].open('rb') as f:
                f.seek(self.position - self.offsets[index])
                b = f.read(take)
            if len(b) != take:
                raise Invalid('part changed during read')
            result.extend(b)
            self.position += take
            size -= take
        return bytes(result)


def archive_check(stream, kind):
    if kind == 'pe':
        return pe_check(stream)
    count = expanded = links = 0
    names = set()
    def member(name, size):
        nonlocal count, expanded
        name = name.rstrip('/')
        relative(name)
        # Case-sensitive source trees can contain case-distinct names: no extraction
        # is offered. Exact duplicate names remain ambiguous and are rejected.
        if name in names:
            raise Invalid('duplicate archive member')
        names.add(name)
        count += 1
        expanded += size
        if count > MAX_MEMBERS or size > MAX_MEMBER or expanded > MAX_EXPANDED:
            raise Invalid(f'archive resource limit: members={count}, expandedBytes={expanded}, memberBytes={size}')
    stream.seek(0)
    if kind == 'zip':
        with zipfile.ZipFile(stream) as z:
            for info in z.infolist():
                member(info.filename, info.file_size)
                if info.flag_bits & 1:
                    raise Invalid('encrypted archive unsupported')
                mode = info.external_attr >> 16
                if stat.S_ISLNK(mode):
                    links += 1
                    if info.file_size > 4096:
                        raise Invalid('archive link target too large')
                    # Inert source snapshots may contain links; validate their target
                    # without resolving/extracting it. No materialization is offered.
                    target = z.read(info).decode('utf8')
                    _link_target(info.filename, target)
                elif not info.is_dir():
                    with z.open(info) as f:
                        while f.read(CHUNK):
                            pass  # consumes all bytes and verifies CRC
    elif kind in ('tar.xz', 'tar.gz', 'tar.bz2', 'tar'):
        with tarfile.open(fileobj=stream, mode='r:*') as t:
            for info in t:
                member(info.name, info.size)
                if info.issym() or info.islnk():
                    links += 1
                    _link_target(info.name, info.linkname, info.islnk())
                elif info.isfile():
                    with t.extractfile(info) as f:
                        while f.read(CHUNK):
                            pass
                elif not info.isdir():
                    raise Invalid('special archive member unsupported')
    else:
        raise Invalid('unsupported artifact format')
    return {'members': count, 'expandedBytes': expanded, 'inertLinks': links,
            'extracted': False, 'executed': False}


def pe_check(stream):
    """Passive PE envelope inspection; embedded installer contents remain opaque."""
    size = stream.seek(0, 2)
    stream.seek(0)
    dos = stream.read(64)
    if len(dos) != 64 or dos[:2] != b'MZ':
        raise Invalid('missing DOS header')
    offset = struct.unpack_from('<I', dos, 60)[0]
    if not 64 <= offset <= min(1024 * 1024, size - 24):
        raise Invalid('invalid PE header offset')
    stream.seek(offset)
    header = stream.read(24)
    if header[:4] != b'PE\0\0':
        raise Invalid('missing PE signature')
    machine, sections = struct.unpack_from('<HH', header, 4)
    optional = struct.unpack_from('<H', header, 20)[0]
    if machine not in (0x14c, 0x8664, 0xaa64) or not 1 <= sections <= 96 or optional < 2:
        raise Invalid('unsupported PE architecture/header')
    table = offset + 24 + optional
    if table + sections * 40 > size:
        raise Invalid('truncated PE section table')
    magic = struct.unpack('<H', stream.read(2))[0]
    if magic not in (0x10b, 0x20b):
        raise Invalid('invalid optional header magic')
    stream.seek(table)
    for _ in range(sections):
        section = stream.read(40)
        raw_size, raw_offset = struct.unpack_from('<II', section, 16)
        if raw_offset + raw_size > size:
            raise Invalid('PE section exceeds file')
    return {'format': 'PE', 'machine': hex(machine), 'sections': sections,
            'embeddedInstallerContents': 'NotInspected', 'extracted': False,
            'executed': False, 'signatureTrust': 'NotVerifiedByThisTool'}


def _link_target(name, target, hard=False):
    if not target or len(target) > 4096 or '\\' in target or ':' in target or target.startswith('/'):
        raise Invalid('unsafe archive link')
    parts = [] if hard else list(PurePosixPath(name).parent.parts)
    for part in target.split('/'):
        if part == '..':
            if not parts:
                raise Invalid('archive link escape')
            parts.pop()
        elif part not in ('', '.'):
            parts.append(part)
    if not parts:
        raise Invalid('empty archive link target')
    relative('/'.join(parts))


def load(root):
    p = local(root, 'inventory.json')
    if p.stat().st_size > 4 * CHUNK:
        raise Invalid('inventory too large')
    inventory = json.loads(p.read_text(encoding='utf8'))
    if not isinstance(inventory, dict) or type(inventory.get('schemaVersion')) is not int or inventory['schemaVersion'] != 1:
        raise Invalid('unsupported inventory schema')
    recipes = inventory.get('recipes', [])
    if not isinstance(recipes, list) or any(not isinstance(r, dict) for r in recipes):
        raise Invalid('recipe object array required')
    ids = [r['id'] for r in recipes]
    if len(ids) != len(RECIPE_IDS) or set(ids) != RECIPE_IDS:
        raise Invalid(f'exact {len(RECIPE_IDS)} recipe coverage required')
    artifacts = inventory.get('artifacts', [])
    if not isinstance(artifacts, list) or len(artifacts) > 256:
        raise Invalid('artifact count limit')
    if any(not isinstance(a, dict) for a in artifacts):
        raise Invalid('artifact object array required')
    support = inventory.get('supportFiles', [])
    if not isinstance(support, list) or len(support) > 1024 or any(not isinstance(f, dict) for f in support):
        raise Invalid('bounded support file object array required')
    a_ids = [a['id'] for a in artifacts]
    if len(a_ids) != len(set(a_ids)):
        raise Invalid('duplicate artifact ID')
    for r in recipes:
        if r.get('status') not in ('partial', 'restricted-with-original', 'project-specific'):
            raise Invalid('unsupported recipe status')
        if any(x not in a_ids for x in r.get('artifactIds', [])):
            raise Invalid('unknown recipe artifact')
        local(root, r['report'])
    paths = set()
    for a in artifacts:
        for key in ('pieces', 'licenseFiles'):
            if not isinstance(a.get(key), list) or len(a[key]) > 256 or any(not isinstance(f, dict) for f in a[key]):
                raise Invalid('bounded artifact file object array required')
    for item in [f for a in artifacts for f in a['pieces'] + a.get('licenseFiles', [])] + support:
        key = str(relative(item['path'])).casefold()
        if key in paths:
            raise Invalid('case-duplicate inventory path')
        paths.add(key)
        if not isinstance(item.get('sizeBytes'), int) or not 0 <= item['sizeBytes'] <= 96 * CHUNK:
            raise Invalid('invalid inventory size')
        if not re.fullmatch('[0-9a-f]{64}', item.get('sha256', '')):
            raise Invalid('invalid SHA256')
    for a in artifacts:
        if not a.get('pieces') or a['recipe'] not in RECIPE_IDS or not a.get('licenseFiles'):
            raise Invalid('missing parts, recipe or retained license')
        if not re.fullmatch('[0-9a-f]{64}', a.get('sha256', '')):
            raise Invalid('invalid whole archive SHA256')
        if len(relative(a['filename']).parts) != 1:
            raise Invalid('archive filename must be a single component')
        if type(a.get('sizeBytes')) is not int or not 0 < a['sizeBytes'] <= 16 * 1024**3:
            raise Invalid('archive size limit')
        for url in (a['url'], a.get('source', a['url']) or a['url'], a.get('finalUrl', a['url'])):
            if not isinstance(url, str):
                raise Invalid('source URL must be a string')
            u = urlsplit(url)
            if u.scheme != 'https' or not u.hostname or u.username or u.password:
                raise Invalid('invalid source URL')
    return inventory


def verify(root, archives=True):
    inventory = load(root)
    results = []
    for f in inventory.get('supportFiles', []):
        if digest(local(root, f['path']), f['sizeBytes']) != (f['sizeBytes'], f['sha256']):
            raise Invalid('support file identity mismatch: ' + f['path'])
    for a in inventory['artifacts']:
        h = hashlib.sha256()
        total = 0
        paths = []
        for f in a['pieces'] + a.get('licenseFiles', []):
            p = local(root, f['path'])
            if digest(p, f['sizeBytes']) != (f['sizeBytes'], f['sha256']):
                raise Invalid('file identity mismatch: ' + f['path'])
        for f in a['pieces']:
            p = local(root, f['path'])
            paths.append(p)
            with p.open('rb') as stream:
                while b := stream.read(CHUNK):
                    h.update(b)
                    total += len(b)
        if (total, h.hexdigest()) != (a['sizeBytes'], a['sha256']):
            raise Invalid('whole archive identity mismatch: ' + a['id'])
        try:
            report = archive_check(Parts(paths), a['format']) if archives else {'skipped': True}
        except (Invalid, OSError, ValueError, zipfile.BadZipFile, tarfile.TarError) as error:
            raise Invalid(a['id'] + ': ' + str(error)) from error
        results.append({'id': a['id'], 'sizeBytes': total, 'archive': report})
    return {'valid': True, 'recipeCount': len(RECIPE_IDS), 'artifactCount': len(results),
            'payloadBytes': sum(x['sizeBytes'] for x in results), 'artifacts': results,
            'network': 'NotPerformed', 'runtime': 'NotPerformed'}


def reconstruct(root, artifact_id, output):
    inventory = load(root)
    selected = [a for a in inventory['artifacts'] if a['id'] == artifact_id]
    if len(selected) != 1:
        raise Invalid('unknown artifact ID')
    artifact = selected[0]
    output = Path(output).absolute()
    # Only a new explicitly chosen directory; never touch existing files/links.
    for p in (output, *output.parents):
        if p.is_symlink() or getattr(p, 'is_junction', lambda: False)():
            raise Invalid('linked output path')
    if output.exists():
        raise Invalid('output directory must not already exist')
    if not output.parent.is_dir():
        raise Invalid('output parent must exist')
    output.mkdir()
    temp = None
    destination = output / artifact['filename']
    try:
        with tempfile.NamedTemporaryFile(dir=output, prefix='.reconstruct-', delete=False) as f:
            temp = Path(f.name)
            h = hashlib.sha256()
            total = 0
            for piece in artifact['pieces']:
                p = local(root, piece['path'])
                ph = hashlib.sha256()
                size = 0
                with p.open('rb') as stream:
                    while b := stream.read(CHUNK):
                        size += len(b)
                        if size > piece['sizeBytes']:
                            raise Invalid('part exceeded declared size')
                        ph.update(b)
                        h.update(b)
                        total += len(b)
                        f.write(b)
                if (size, ph.hexdigest()) != (piece['sizeBytes'], piece['sha256']):
                    raise Invalid('part mismatch')
            if (total, h.hexdigest()) != (artifact['sizeBytes'], artifact['sha256']):
                raise Invalid('whole archive mismatch')
            f.flush()
            os.fsync(f.fileno())
        with temp.open('rb') as f:
            archive_check(f, artifact['format'])
        # rename does not overwrite existing target on Windows; explicit check
        # keeps the same promise elsewhere in the trusted stable directory.
        if destination.exists():
            raise Invalid('destination already exists')
        temp.rename(destination)
        return {'valid': True, 'artifact': artifact_id, 'output': str(destination),
                'sha256': artifact['sha256'], 'installed': False}
    except BaseException:
        if temp is not None and temp.exists():
            temp.unlink()
        if output.exists() and not any(output.iterdir()):
            output.rmdir()
        raise


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--root', type=Path, default=Path(__file__).resolve().parent)
    sub = p.add_subparsers(dest='command', required=True)
    v = sub.add_parser('verify')
    v.add_argument('--hashes-only', action='store_true', help='Skip archive content checks explicitly')
    r = sub.add_parser('reconstruct')
    r.add_argument('artifact_id')
    r.add_argument('--output', required=True, type=Path, help='New output directory; parent must exist')
    args = p.parse_args()
    try:
        result = verify(args.root, not args.hashes_only) if args.command == 'verify' else reconstruct(args.root, args.artifact_id, args.output)
        print(json.dumps(result, indent=2))
        return 0
    except (Invalid, OSError, ValueError, KeyError, TypeError, zipfile.BadZipFile, tarfile.TarError, EOFError) as e:
        print(json.dumps({'valid': False, 'error': str(e)}))
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
