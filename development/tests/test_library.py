import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

SPEC = importlib.util.spec_from_file_location('library', Path(__file__).parents[1] / 'tools/library.py')
library = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(library)


class LibraryTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        (self.root / 'development').mkdir()
        self.entries = []
        for kind in ('guide', 'example'):
            path = 'development/' + kind + '.md'
            (self.root / path).write_text('Original body contains ZephyrBodyToken.', encoding='utf-8')
            self.entries.append(dict(id=kind, title=kind, domains=list(library.DOMAINS), kind=kind,
                                     path=path, summary='Original', tags=[], verification='Static fixture only',
                                     status='original', origin='Original', license='MIT', officialSources=[]))
        self.save()

    def save(self):
        (self.root / library.CATALOG).write_text(json.dumps({'schemaVersion': 1, 'entries': self.entries}), encoding='utf-8')

    def args(self, command, **kwargs):
        return SimpleNamespace(root=self.root, command=command, domain=None, **kwargs)

    def test_manifest_audit_and_body_search(self):
        result, code = library.execute(self.args('audit', write_manifest=True))
        self.assertEqual(0, code, result)
        self.assertEqual(0, library.execute(self.args('audit', write_manifest=False))[1])
        result, code = library.execute(self.args('search', query='ZephyrBodyToken', limit=1))
        self.assertEqual(0, code)
        self.assertEqual(2, result['totalMatches'])
        self.assertEqual(1, len(result['matches']))

    def test_manifest_detects_changed_body(self):
        library.execute(self.args('audit', write_manifest=True))
        (self.root / self.entries[0]['path']).write_text('Changed', encoding='utf-8')
        result, code = library.execute(self.args('audit', write_manifest=False))
        self.assertEqual(2, code)
        self.assertIn('manifest differs', ' '.join(result['findings']))

    def test_reference_identity_ignores_checkout_eol_but_detects_text_changes(self):
        self.entries[0]['status'] = 'reference-only'
        self.save()
        path = self.root / self.entries[0]['path']
        path.write_bytes(b'Original\nSecond line\n')
        self.assertEqual(0, library.execute(self.args('audit', write_manifest=True))[1])
        path.write_bytes(b'Original\r\nSecond line\r\n')
        self.assertEqual(0, library.execute(self.args('audit', write_manifest=False))[1])
        path.write_bytes(b'Edited\r\nSecond line\r\n')
        self.assertEqual(2, library.execute(self.args('audit', write_manifest=False))[1])

    def test_malformed_reference_utf8_returns_setup125(self):
        from contextlib import redirect_stdout
        from io import StringIO
        self.entries[0]['status'] = 'reference-only'
        self.save()
        (self.root / self.entries[0]['path']).write_bytes(b'bad\xfftext')
        output = StringIO()
        with redirect_stdout(output):
            code = library.main(['audit', '--root', str(self.root)])
        self.assertEqual(125, code)
        self.assertIn('valid UTF-8', json.loads(output.getvalue())['error'])

    def test_missing_optional_is_distinct(self):
        self.entries.append(dict(self.entries[0], id='optional', kind='pointer', status='not-acquired', path='development/optional.md'))
        self.save()
        result, code = library.execute(self.args('audit', write_manifest=True))
        self.assertEqual(0, code)
        self.assertEqual(['optional'], result['missingOptional'])

    def test_bounds(self):
        (self.root / self.entries[0]['path']).write_bytes(b'x' * (library.MAX_DOCUMENT + 1))
        with self.assertRaises(library.LibraryError):
            library.load(self.root)

    def test_required_missing_is_finding(self):
        (self.root / self.entries[0]['path']).unlink()
        self.assertEqual(2, library.execute(self.args('audit', write_manifest=True))[1])

    def test_manifest_refresh_does_not_truncate_hardlink_target(self):
        victim = self.root / 'outside.txt'
        victim.write_text('preserve bytes', encoding='utf-8')
        try:
            os.link(victim, self.root / library.MANIFEST)
        except OSError as error:
            self.skipTest(str(error))
        self.assertEqual(0, library.execute(self.args('audit', write_manifest=True))[1])
        self.assertEqual('preserve bytes', victim.read_text(encoding='utf-8'))

    def test_present_not_acquired_is_finding(self):
        self.entries[0]['status'] = 'not-acquired'
        self.save()
        self.assertEqual(2, library.execute(self.args('audit', write_manifest=True))[1])

    def test_case_alias_and_git_metadata_refused(self):
        self.entries[1]['path'] = self.entries[0]['path'].upper()
        self.save()
        with self.assertRaises(library.LibraryError):
            library.load(self.root)
        with self.assertRaises(library.LibraryError):
            library.local_path(self.root, '.GIT/config')

    def test_actual_catalog_audits_and_searches_body(self):
        root = Path(__file__).resolve().parents[2]
        if not (root / library.CATALOG).is_file():
            self.skipTest('complete catalog not present in test-only copy')
        result, code = library.execute(SimpleNamespace(root=root, command='audit', write_manifest=False))
        self.assertEqual(0, code, result)
        self.assertEqual(set(library.DOMAINS), set(result['coverage']))
        result, code = library.execute(SimpleNamespace(root=root, command='search', domain='windows', query='cancellation', limit=5))
        self.assertEqual(0, code)
        self.assertGreater(result['totalMatches'], 0)


if __name__ == '__main__':
    unittest.main()
