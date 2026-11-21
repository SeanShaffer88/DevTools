"""Bounded, offline access to the curated development library (Python 3.10+)."""
import argparse
import hashlib
import json
import re
import stat
import sys
import os
import tempfile
from pathlib import Path, PurePosixPath
from urllib.parse import urlsplit

DOMAINS = ('windows', 'android-apps', 'android-games', 'websites', 'pc-games',
           'userscripts', 'userstyles', 'dependencies')
MAX_DOCUMENT = 1024 * 1024
MAX_TOTAL = 16 * MAX_DOCUMENT
MAX_ENTRIES = 512
CATALOG = 'development/catalog.seed.json'
MANIFEST = 'development/manifest.json'


class LibraryError(ValueError):
    pass


def local_path(root, value):
    if not isinstance(value, str) or not value or '\\' in value or ':' in value:
        raise LibraryError('path must be a relative slash-separated local path')
    parts = PurePosixPath(value).parts
    if value.startswith('/') or any(p.casefold() in ('.', '..', '.git') for p in parts):
        raise LibraryError('unsafe path: ' + value)
    if any(p.lower() in ('evidence', 'node_modules', '__pycache__') for p in parts):
        raise LibraryError('noncanonical resource path: ' + value)
    current = root
    for part in parts:
        current = current / part
        if current.exists() or current.is_symlink():
            attrs = current.lstat()
            if stat.S_ISLNK(attrs.st_mode) or getattr(attrs, 'st_file_attributes', 0) & 0x400:
                raise LibraryError('linked resource refused: ' + value)
    if not current.resolve().is_relative_to(root):
        raise LibraryError('resource escapes root')
    return current


def read_bytes(path, remaining=MAX_TOTAL):
    with path.open('rb') as stream:
        size = stream.seek(0, 2)
        if size > MAX_DOCUMENT or size > remaining:
            raise LibraryError('document byte limit exceeded: ' + path.name)
        stream.seek(0)
        data = stream.read(min(MAX_DOCUMENT, remaining) + 1)
    if len(data) > MAX_DOCUMENT or len(data) > remaining:
        raise LibraryError('document grew beyond byte limit')
    return data


def load(root):
    raw = read_bytes(local_path(root, CATALOG))
    catalog = json.loads(raw)
    if not isinstance(catalog, dict) or type(catalog.get('schemaVersion')) is not int or catalog['schemaVersion'] != 1:
        raise LibraryError('unsupported catalog schema')
    entries = catalog.get('entries')
    vendor_path = local_path(root, 'development/catalog.vendor.json')
    if vendor_path.is_file():
        vendor_raw = read_bytes(vendor_path)
        vendor = json.loads(vendor_raw)
        if not isinstance(vendor, dict) or type(vendor.get('schemaVersion')) is not int or vendor['schemaVersion'] != 1 or not isinstance(vendor.get('entries'), list):
            raise LibraryError('invalid vendor catalog')
        if not isinstance(entries, list):
            raise LibraryError('entries must be an array')
        entries = entries + vendor['entries']
        raw += b'\n' + vendor_raw
    if not isinstance(entries, list) or not 0 < len(entries) <= MAX_ENTRIES:
        raise LibraryError('entries must be a nonempty bounded array')
    seen = set()
    paths = set()
    records = []
    findings = []
    remaining = MAX_TOTAL - len(raw)
    for entry in entries:
        if not isinstance(entry, dict):
            raise LibraryError('entry must be an object')
        for field in ('id', 'title', 'summary', 'verification', 'origin', 'license'):
            if not isinstance(entry.get(field), str) or not entry[field].strip():
                raise LibraryError('missing nonblank metadata: ' + field)
        identity = entry['id']
        if not re.fullmatch(r'[a-z0-9][a-z0-9-]{0,95}', identity) or identity in seen:
            raise LibraryError('invalid or duplicate entry id')
        seen.add(identity)
        if entry.get('kind') not in ('guide', 'template', 'example', 'reference', 'pointer'):
            raise LibraryError('invalid kind: ' + identity)
        if entry.get('status') not in ('original', 'vendored', 'reference-only', 'not-acquired'):
            raise LibraryError('invalid status: ' + identity)
        domains = entry.get('domains')
        if not isinstance(domains, list) or not domains or len(set(domains)) != len(domains) or any(d not in DOMAINS for d in domains):
            raise LibraryError('invalid domains: ' + identity)
        for field in ('tags', 'officialSources', 'requires'):
            values = entry.get(field, [])
            if not isinstance(values, list) or any(not isinstance(v, str) or not v.strip() for v in values):
                raise LibraryError('invalid list metadata: ' + field)
        for source in entry.get('officialSources', []):
            url = urlsplit(source)
            if url.scheme != 'https' or not url.hostname or url.username or url.password:
                raise LibraryError('source URL must be HTTPS without credentials')
        if 'sha256' in entry and (not isinstance(entry['sha256'], str) or not re.fullmatch('[a-fA-F0-9]{64}', entry['sha256'])):
            raise LibraryError('invalid sha256: ' + identity)
        if 'sizeBytes' in entry and (type(entry['sizeBytes']) is not int or entry['sizeBytes'] < 0):
            raise LibraryError('invalid sizeBytes: ' + identity)
        if entry['status'] == 'vendored' and not all(k in entry for k in ('sha256', 'sizeBytes')):
            raise LibraryError('vendored entry requires pinned hash and size')
        record = dict(entry)
        record['available'] = False
        record['_text'] = ''
        value = entry.get('path')
        if value:
            path = local_path(root, value)
            path_key = PurePosixPath(value).as_posix().casefold()
            if path_key in paths:
                raise LibraryError('duplicate resource path: ' + value)
            paths.add(path_key)
            if path.is_file():
                if entry['status'] == 'not-acquired':
                    findings.append(identity + ': present resource contradicts not-acquired status')
                data = read_bytes(path, remaining)
                remaining -= len(data)
                digest = hashlib.sha256(data).hexdigest()
                try:
                    text = data.decode('utf-8-sig', errors='strict' if entry['status'] == 'reference-only' else 'replace')
                except UnicodeDecodeError as error:
                    raise LibraryError('reference-only resource must be valid UTF-8: ' + identity) from error
                record.update(available=True, sizeBytes=len(data), sha256=digest, _text=text)
                if ('sha256' in entry and digest != entry['sha256'].lower()) or ('sizeBytes' in entry and len(data) != entry['sizeBytes']):
                    findings.append(identity + ': integrity mismatch')
            elif entry['status'] != 'not-acquired':
                findings.append(identity + ': required local resource missing')
        elif entry['status'] != 'not-acquired' and entry['kind'] != 'pointer':
            raise LibraryError('local entry requires path: ' + identity)
        records.append(record)
        if entry['status'] == 'vendored':
            license_path = local_path(root, entry.get('licenseFile'))
            if not license_path.is_file() or not local_path(root, 'development/vendor/SOURCES.json').is_file():
                findings.append(identity + ': vendor license/provenance file missing')
    if any(r['status'] == 'vendored' for r in records):
        provenance_raw = read_bytes(local_path(root, 'development/vendor/SOURCES.json'), remaining)
        remaining -= len(provenance_raw)
        raw += b'\n' + provenance_raw
        provenance = json.loads(provenance_raw)
        if not isinstance(provenance, dict) or not isinstance(provenance.get('sources'), list):
            raise LibraryError('invalid vendor provenance')
        for source in provenance['sources']:
            if not isinstance(source, dict) or not isinstance(source.get('revision'), str) or not source['revision'].strip() or not isinstance(source.get('files'), list):
                raise LibraryError('vendor source needs revision and file records')
            for item in source['files']:
                if not isinstance(item, dict) or not isinstance(item.get('sha256'), str) or not re.fullmatch('[a-fA-F0-9]{64}', item['sha256']) or type(item.get('sizeBytes')) is not int or item['sizeBytes'] < 0:
                    raise LibraryError('invalid vendor file identity')
                path = local_path(root, item.get('path'))
                data = read_bytes(path, remaining)
                remaining -= len(data)
                if len(data) != item['sizeBytes'] or hashlib.sha256(data).hexdigest() != item['sha256'].lower():
                    findings.append('vendor provenance integrity mismatch: ' + item['path'])
    return raw, records, findings


def manifest(raw, records):
    files = []
    for record in records:
        if not record['available']:
            continue
        item = {k: record[k] for k in ('id', 'path', 'sizeBytes', 'sha256')}
        if record['status'] == 'reference-only':
            # Canonical guides outside this pack may use checkout-specific EOLs.
            normalized = record['_text'].replace('\r\n', '\n').replace('\r', '\n').encode('utf-8')
            item.update(sizeBytes=len(normalized), sha256=hashlib.sha256(normalized).hexdigest(),
                        identityEncoding='utf8-lf')
        else:
            item['identityEncoding'] = 'raw-bytes'
        files.append(item)
    return {'schemaVersion': 1, 'catalogSha256': hashlib.sha256(raw).hexdigest(),
            'files': files}


def execute(args):
    root = args.root.resolve(strict=True)
    if not root.is_dir():
        raise LibraryError('root must be an existing directory')
    raw, records, findings = load(root)
    if args.command == 'audit':
        coverage = {}
        for domain in DOMAINS:
            selected = [r for r in records if domain in r['domains'] and r['available']]
            coverage[domain] = {'entries': len(selected), 'guide': any(r['kind'] == 'guide' for r in selected),
                                'example': any(r['kind'] in ('example', 'template') for r in selected)}
            if not coverage[domain]['guide'] or not coverage[domain]['example']:
                findings.append(domain + ': missing guide or example/template coverage')
        expected = manifest(raw, records)
        destination = local_path(root, MANIFEST)
        if args.write_manifest:
            if findings:
                findings.append('manifest not written because audit has findings')
            else:
                # Replace the directory entry, never truncate an existing hardlink.
                descriptor, temporary = tempfile.mkstemp(prefix='.manifest-', suffix='.tmp', dir=destination.parent)
                try:
                    with os.fdopen(descriptor, 'w', encoding='utf-8', newline='\n') as stream:
                        stream.write(json.dumps(expected, indent=2) + '\n')
                    local_path(root, MANIFEST)
                    os.replace(temporary, destination)
                finally:
                    if os.path.exists(temporary):
                        os.unlink(temporary)
        elif not destination.is_file():
            findings.append('manifest missing; run audit --write-manifest after review')
        elif json.loads(read_bytes(destination)) != expected:
            findings.append('manifest differs from current catalog/resources')
        return {'valid': not findings, 'coverage': coverage, 'findings': findings,
                'missingOptional': [r['id'] for r in records if not r['available'] and r['status'] == 'not-acquired']}, 2 if findings else 0
    if findings:
        return {'valid': False, 'findings': findings}, 2
    selected = [r for r in records if not args.domain or args.domain in r['domains']]
    if args.command == 'plan':
        return {'domain': args.domain, 'resources': [{k: r[k] for k in ('id', 'title', 'kind', 'status', 'available', 'verification')} | {'path': r.get('path'), 'requires': r.get('requires', [])} for r in selected],
                'missingOptional': [r['id'] for r in selected if not r['available']]}, 0
    terms = args.query.casefold().split()
    if not terms or len(args.query) > 512:
        raise LibraryError('query must contain 1–512 characters')
    matches = []
    for record in selected:
        text = record['_text']
        haystack = (record['title'] + ' ' + record['summary'] + ' ' + ' '.join(record.get('tags', [])) + ' ' + text).casefold()
        if record['available'] and all(term in haystack for term in terms):
            position = max(0, text.casefold().find(terms[0]))
            matches.append({'id': record['id'], 'title': record['title'], 'path': record['path'],
                            'line': text[:position].count('\n') + 1,
                            'domains': record['domains'], 'status': record['status'],
                            'snippet': text[max(0, position-60):position+220].replace('\n', ' ')})
    return {'query': args.query, 'totalMatches': len(matches), 'matches': matches[:args.limit]}, 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    for command in ('audit', 'search', 'plan'):
        item = sub.add_parser(command)
        item.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[2])
        item.add_argument('--format', choices=('json', 'text'), default='json')
        if command == 'audit':
            item.add_argument('--write-manifest', action='store_true')
        else:
            item.add_argument('--domain', choices=DOMAINS, required=command == 'plan')
        if command == 'search':
            item.add_argument('query')
            item.add_argument('--limit', type=int, choices=range(1, 51), default=10)
    args = parser.parse_args(argv)
    try:
        result, code = execute(args)
    except (LibraryError, OSError, ValueError, TypeError) as error:
        result, code = {'valid': False, 'error': str(error)}, 125
    if args.format == 'json':
        print(json.dumps(result, indent=2, ensure_ascii=True))
    else:
        print(json.dumps(result, indent=2, ensure_ascii=False))
    return code


if __name__ == '__main__':
    sys.exit(main())
