import hashlib
import importlib.util
import io
import json
import struct
import stat
from pathlib import Path
import tempfile
import unittest
import zipfile

P = Path(__file__).resolve().parents[1] / 'verify.py'
spec = importlib.util.spec_from_file_location('acquisition_verify', P)
v = importlib.util.module_from_spec(spec)
spec.loader.exec_module(v)


def identity(path, data):
    return {'path': path, 'sizeBytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}


def fixture(root):
    stream = io.BytesIO()
    with zipfile.ZipFile(stream, 'w') as z:
        z.writestr('source/example.txt', b'payload')
    data = stream.getvalue()
    (root / 'part1').write_bytes(data[:40])
    (root / 'part2').write_bytes(data[40:])
    (root / 'LICENSE').write_bytes(b'original test license')
    (root / 'report.md').write_text('Original test report')
    artifact = {'id': 'example', 'recipe': 'windows-sdk', 'url': 'https://example.org/source.zip',
        'format': 'zip', 'filename': 'source.zip', 'sizeBytes': len(data),
        'sha256': hashlib.sha256(data).hexdigest(),
        'pieces': [identity('part1', data[:40]), identity('part2', data[40:])],
        'licenseFiles': [identity('LICENSE', b'original test license')]}
    inventory = {'schemaVersion': 1, 'artifacts': [artifact], 'supportFiles': [],
        'recipes': [{'id': x, 'status': 'partial', 'artifactIds': ['example'],
                     'report': 'report.md'} for x in sorted(v.RECIPE_IDS)]}
    (root / 'inventory.json').write_text(json.dumps(inventory))
    return inventory, data


class VerifierTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.inventory, self.data = fixture(self.root)

    def tearDown(self): self.temp.cleanup()

    def write_inventory(self):
        (self.root / 'inventory.json').write_text(json.dumps(self.inventory))

    def test_split_archive_identity_crc_and_reconstruction(self):
        self.assertTrue(v.verify(self.root)['valid'])
        target = self.root / 'new-output'
        result = v.reconstruct(self.root, 'example', target)
        self.assertEqual(self.data, Path(result['output']).read_bytes())
        with self.assertRaises(v.Invalid): v.reconstruct(self.root, 'example', target)

    def test_truncation_and_order_fail(self):
        (self.root / 'part1').write_bytes(b'x')
        with self.assertRaises(v.Invalid): v.verify(self.root)

    def test_reordered_parts_fail_whole_digest(self):
        self.inventory['artifacts'][0]['pieces'].reverse()
        self.write_inventory()
        with self.assertRaises(v.Invalid): v.verify(self.root)

    def test_paths_and_windows_aliases_fail(self):
        for path in ('../escape', '/absolute', 'C:/drive', 'a:stream', 'NUL', 'dir./file', 'a\\b'):
            with self.subTest(path=path), self.assertRaises(v.Invalid): v.relative(path)

    def test_case_duplicate_and_schema_fail(self):
        piece = dict(self.inventory['artifacts'][0]['pieces'][0])
        piece['path'] = piece['path'].upper()
        self.inventory['supportFiles'].append(piece)
        self.write_inventory()
        with self.assertRaises(v.Invalid): v.load(self.root)
        (self.root / 'inventory.json').write_text('[]')
        with self.assertRaises(v.Invalid): v.load(self.root)

    def test_unsafe_member_and_crc_fail_without_extraction(self):
        stream = io.BytesIO()
        with zipfile.ZipFile(stream, 'w') as z: z.writestr('../escape', b'x')
        with self.assertRaises(v.Invalid): v.archive_check(stream, 'zip')
        broken = self.data.replace(b'payload', b'changed')
        with self.assertRaises(zipfile.BadZipFile): v.archive_check(io.BytesIO(broken), 'zip')
        self.assertFalse((self.root.parent / 'escape').exists())

    def test_expansion_limit_and_unsafe_link_fail(self):
        old = v.MAX_EXPANDED
        try:
            v.MAX_EXPANDED = 1
            with self.assertRaises(v.Invalid): v.archive_check(io.BytesIO(self.data), 'zip')
        finally: v.MAX_EXPANDED = old
        with self.assertRaises(v.Invalid): v._link_target('root/link', '../../escape')
        with self.assertRaises(v.Invalid): v._link_target('root/link', 'x' * 4097)

    def test_zip_link_target_is_bounded_before_read(self):
        stream = io.BytesIO()
        info = zipfile.ZipInfo('source/link')
        info.external_attr = (stat.S_IFLNK | 0o777) << 16
        with zipfile.ZipFile(stream, 'w') as z: z.writestr(info, b'x' * 4097)
        with self.assertRaisesRegex(v.Invalid, 'target too large'):
            v.archive_check(stream, 'zip')

    def test_failed_reconstruction_leaves_no_output(self):
        (self.root / 'part1').write_bytes(b'x')
        target = self.root / 'new-output'
        with self.assertRaises(v.Invalid): v.reconstruct(self.root, 'example', target)
        self.assertFalse(target.exists())

    def test_source_url_type_is_rejected(self):
        self.inventory['artifacts'][0]['url'] = {}
        self.write_inventory()
        with self.assertRaises(v.Invalid): v.load(self.root)

    def test_pe_envelope_is_passive_and_bounded(self):
        data = bytearray(512)
        data[:2] = b'MZ'
        struct.pack_into('<I', data, 60, 128)
        data[128:132] = b'PE\0\0'
        struct.pack_into('<HH', data, 132, 0x8664, 1)
        struct.pack_into('<H', data, 148, 240)
        struct.pack_into('<H', data, 152, 0x20b)
        result = v.pe_check(io.BytesIO(data))
        self.assertEqual('NotInspected', result['embeddedInstallerContents'])
        self.assertFalse(result['executed'])
        with self.assertRaises(v.Invalid): v.pe_check(io.BytesIO(data[:200]))
        broken = bytearray(data)
        struct.pack_into('<I', broken, 60, 0xffffffff)
        with self.assertRaises(v.Invalid): v.pe_check(io.BytesIO(broken))
        broken = bytearray(data)
        struct.pack_into('<II', broken, 392 + 16, 1000, 500)
        with self.assertRaises(v.Invalid): v.pe_check(io.BytesIO(broken))
        broken = bytearray(data)
        struct.pack_into('<H', broken, 152, 0)
        with self.assertRaises(v.Invalid): v.pe_check(io.BytesIO(broken))
        with self.assertRaises(v.Invalid): v.pe_check(io.BytesIO(b'invalid'))


if __name__ == '__main__': unittest.main()
