"""Prepare saved tools and explicit private prerequisites in an initialized owned root."""
import argparse
import hashlib
import importlib.util
import json
import os
import re
from pathlib import Path
import shutil
import stat
import subprocess
import zipfile


def identity(path):
    with path.open('rb') as stream:
        h = hashlib.sha256()
        while block := stream.read(1024 * 1024):
            h.update(block)
    return {'sizeBytes': path.stat().st_size, 'sha256': h.hexdigest()}


def prepare(repo, root, android_sdk, platform, build_tools, targets):
    repo, root = repo.resolve(strict=True), root.resolve(strict=True)
    if not re.fullmatch(r"android-[0-9]+(?:\.[0-9]+)?", platform) or not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", build_tools):
        raise ValueError("Use explicit numeric Android platform and build-tools identifiers")
    # Initialize-OfflineRoot.ps1 supplies and verifies this task ownership marker.
    marker = root / '.devtools-offline-owned.json'
    if not marker.is_file():
        raise ValueError('Use Initialize-OfflineRoot.ps1 before preparing the owned root')
    if root.is_relative_to(repo) or repo.is_relative_to(root):
        raise ValueError('Private build root must be separate from the source repository')
    if any(p.is_symlink() or getattr(p, 'is_junction', lambda: False)() for p in (root, *root.parents)):
        raise ValueError('Linked build root refused')
    targets = set(targets)
    allowed = {'website','userscript','userstyle','dependency','windows','android-app','godot-games','wow-addon','portableapps'}
    if not targets or not targets <= allowed:
        raise ValueError('Unknown or empty sample target selection')
    need_java = bool(targets & {'dependency','android-app','godot-games'})
    need_sdk = bool(targets & {'android-app','godot-games'})
    need_windows = bool(targets & {'windows','portableapps'})
    need_games = 'godot-games' in targets
    need_paf = 'portableapps' in targets
    tools_dir = root / 'tools'
    tools_dir.mkdir(exist_ok=True)
    acquisition = repo / 'development/acquisitions'
    spec = importlib.util.spec_from_file_location('saved_acquisitions', acquisition / 'verify.py')
    verifier = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(verifier)
    inventory = json.loads((acquisition / 'inventory.json').read_text(encoding='utf8'))
    records = []
    extracted = {}

    def checked(ident):
        artifact = next(a for a in inventory['artifacts'] if a['id'] == ident)
        paths = []
        whole = hashlib.sha256()
        total = 0
        for item in artifact['pieces']:
            file = verifier.local(acquisition, item['path'])
            if identity(file) != {k: item[k] for k in ('sizeBytes', 'sha256')}:
                raise ValueError('Saved part identity mismatch: ' + ident)
            paths.append(file)
            with file.open('rb') as stream:
                while block := stream.read(1024 * 1024):
                    total += len(block)
                    whole.update(block)
        if (total, whole.hexdigest()) != (artifact['sizeBytes'], artifact['sha256']):
            raise ValueError('Saved archive identity mismatch: ' + ident)
        for item in artifact['licenseFiles']:
            if identity(verifier.local(acquisition, item['path'])) != {k: item[k] for k in ('sizeBytes', 'sha256')}:
                raise ValueError('Saved license identity mismatch: ' + ident)
        return artifact, paths

    def extract_zip(ident, select=None):
        artifact, paths = checked(ident)
        destination = tools_dir / ident
        destination.mkdir()  # New destination only; never overwrite an old tool set.
        count, expanded = 0, 0
        seen = set()
        with zipfile.ZipFile(verifier.Parts(paths)) as archive:
            for info in archive.infolist():
                if info.is_dir() or select and not select(info.filename):
                    continue
                relative = verifier.relative(info.filename)
                if stat.S_ISLNK(info.external_attr >> 16):
                    raise ValueError('Linked tool archive member refused')
                key = str(relative).casefold()
                if key in seen:
                    raise ValueError('Duplicate tool archive path')
                seen.add(key)
                count += 1
                expanded += info.file_size
                if count > 50000 or info.file_size > 1024**3 or expanded > 3 * 1024**3:
                    raise ValueError('Tool extraction budget exceeded')
                file = destination.joinpath(*relative.parts)
                file.parent.mkdir(parents=True, exist_ok=True)
                with archive.open(info) as source, file.open('xb') as output:
                    shutil.copyfileobj(source, output, 1024 * 1024)
        extracted[ident] = destination
        records.append({'id': ident, 'archiveSha256': artifact['sha256'], 'files': count,
                        'expandedBytes': expanded, 'selection': 'all' if select is None else 'Windows x64 and Android templates only'})
        print('Prepared ' + ident, flush=True)

    selected = ['node-win-x64']
    if need_java: selected.append('temurin21-win-x64')
    if need_windows: selected.append('zig-win-x64')
    if need_games: selected.append('godot-win-x64')
    if need_paf: selected.extend(('7zip-tools-win-x64', 'nsis-compatible-win-x86'))
    for ident in selected:
        extract_zip(ident)
    if need_games:
        template_names = {'windows_release_x86_64.exe', 'windows_debug_x86_64.exe', 'android_release.apk', 'android_debug.apk', 'version.txt'}
        extract_zip('godot-export-templates', lambda name: name.rsplit('/', 1)[-1] in template_names)
    if need_paf:
        extractor = extracted['7zip-tools-win-x64'] / '7z.exe'
        extractor_identity = identity(extractor)
        for ident in ('portableapps-launcher', 'portableapps-installer', 'nsis-portable'):
            artifact, paths = checked(ident)
            if len(paths) != 1:
                raise ValueError('Expected a single saved official PAF archive')
            destination = tools_dir / ident
            if destination.exists():
                raise ValueError('Tool destination already exists')
            result = subprocess.run([str(extractor), 'x', '-y', '-o' + str(destination), str(paths[0])],
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=90)
            (root / (ident + '-extraction.stdout.txt')).write_bytes(result.stdout)
            (root / (ident + '-extraction.stderr.txt')).write_bytes(result.stderr)
            if result.returncode:
                raise ValueError('Official tool extraction failed: ' + ident)
            for file in destination.rglob('*'):
                if file.is_symlink() or getattr(file, 'is_junction', lambda: False)():
                    raise ValueError('Linked extracted tool refused')
            extracted[ident] = destination
            records.append({'id': ident, 'archiveSha256': artifact['sha256'], 'selection': 'Inert extraction; installer never launched',
                            'extractorSha256': extractor_identity['sha256'], 'extractionExitCode': result.returncode})
    if 'wow-addon' in targets:
        extract_zip('lua515-win-x64')
        lua = extracted['lua515-win-x64']
    if need_sdk:
        if android_sdk is None: raise ValueError('Android targets require an explicit private licensed SDK path')
        sdk = tools_dir / 'android-sdk-private'
        sdk.mkdir()
        android_sdk = android_sdk.resolve(strict=True)
        for relative in ('build-tools/' + build_tools, 'platforms/' + platform, 'platform-tools'):
            source = android_sdk / relative
            if not source.is_dir():
                raise ValueError('Explicit private SDK prerequisite missing: ' + str(source))
            if any(p.is_symlink() or getattr(p, 'is_junction', lambda: False)() for p in (source, *source.rglob('*'))):
                raise ValueError('Linked SDK prerequisite refused')
            shutil.copytree(source, sdk / relative)
        sdk_receipt = [{'path': p.relative_to(sdk).as_posix(), **identity(p)} for p in sorted(sdk.rglob('*')) if p.is_file()]
        (root / 'private-sdk-receipt.json').write_text(json.dumps({'source': 'Explicit private licensed Android SDK; not redistributed',
            'platform': platform, 'buildTools': build_tools, 'files': sdk_receipt}, indent=2) + '\n')
    for name in ('sources', 'outputs', 'home', 'home/AppData/Local/Temp', 'home/AppData/Roaming', 'temp', 'cache', 'requests', 'results'):
        (root / name).mkdir(parents=True, exist_ok=True)
    shutil.copytree(repo / 'development/samples', root / 'sources/samples', ignore=shutil.ignore_patterns('__pycache__', 'isolation'))
    def one(ident, pattern):
        choices = list(extracted[ident].rglob(pattern))
        if len(choices) != 1:
            raise ValueError('Expected one executable/member for ' + ident + '/' + pattern)
        return choices[0]
    tools = {'node': str(one('node-win-x64', 'node.exe'))}
    if need_java:
        java = one('temurin21-win-x64', 'java.exe')
        tools.update({'java': str(java), 'javac': str(java.with_name('javac.exe')), 'jar': str(java.with_name('jar.exe')), 'keytool': str(java.with_name('keytool.exe'))})
    if need_windows:
        tools['zig'] = str(one('zig-win-x64', 'zig.exe'))
    if need_sdk:
        bt = sdk / 'build-tools' / build_tools
        tools.update({'aapt2': str(bt / 'aapt2.exe'), 'zipalign': str(bt / 'zipalign.exe'), 'androidJar': str(sdk / 'platforms' / platform / 'android.jar'),
            'd8Jar': str(bt / 'lib/d8.jar'), 'apksignerJar': str(bt / 'lib/apksigner.jar'), 'androidSdk': str(sdk)})
    if need_paf:
        tools.update({'palRoot': str(extracted['portableapps-launcher']), 'installerRoot': str(extracted['portableapps-installer']), 'nsisCompiler': str(one('nsis-compatible-win-x86', 'Bin/makensis.exe'))})
    if 'wow-addon' in targets:
        tools['luac'] = str(lua / 'luac.exe')
    if need_games:
        tools['godot'] = str(one('godot-win-x64', '*win64.exe'))
        for key, name in [('godotWindowsRelease', 'windows_release_x86_64.exe'), ('godotWindowsDebug', 'windows_debug_x86_64.exe'),
                          ('godotAndroidDebug', 'android_debug.apk'), ('godotAndroidRelease', 'android_release.apk')]:
            tools[key] = str(one('godot-export-templates', name))
        notices = tools_dir / 'godot-notices'
        notices.mkdir()
        for key, name in [('godotLicense','LICENSE.txt'), ('godotCopyright','COPYRIGHT.txt')]:
            original = acquisition / 'notices' / ('godot-win-x64-' + name)
            shutil.copy2(original, notices / name)
            tools[key] = str(notices / name)
    (root / 'tool-paths.json').write_text(json.dumps(tools, indent=2) + '\n')
    (root / 'prepared-tools.json').write_text(json.dumps(records, indent=2) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repository', type=Path, required=True)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--android-sdk', type=Path)
    parser.add_argument('--sdk-platform', default='android-34')
    parser.add_argument('--sdk-build-tools', default='36.0.0')
    parser.add_argument('--targets', default='website,userscript,userstyle,dependency,windows,android-app,godot-games,wow-addon,portableapps')
    args = parser.parse_args()
    prepare(args.repository, args.root, args.android_sdk, args.sdk_platform, args.sdk_build_tools, args.targets.split(','))
