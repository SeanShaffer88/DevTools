import importlib.util
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

P = Path(__file__).resolve().parents[1] / 'original' / 'offline_contracts.py'
spec = importlib.util.spec_from_file_location('offline_contracts', P)
m = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = m
spec.loader.exec_module(m)


class OriginalContractTests(unittest.TestCase):
    def test_malformed_json_shapes_are_rejected(self):
        for fn in (m.windows_inputs, m.android_inputs, m.scene_contract):
            for value in (None, [], 42, 'text'):
                self.assertFalse(fn(value)['valid'])
        self.assertFalse(m.android_inputs({'abis': [{}]})['valid'])
        self.assertFalse(m.scene_contract({'entities': [{'id': {}}]})['valid'])
        self.assertFalse(m.android_inputs({'applicationId': []})['valid'])
        self.assertFalse(m.windows_inputs({'compiler': {}})['valid'])
        self.assertFalse(m.scene_contract({'schemaVersion': True})['valid'])
    def test_service_lifecycle_is_offline_and_idempotent(self):
        with patch('socket.socket', side_effect=AssertionError('network')), patch('subprocess.Popen', side_effect=AssertionError('process')):
            s = m.FakeServices()
            s.save('one', b'original')
            self.assertEqual(b'original', s.load('one'))
            s.unlock('first.save')
            s.unlock('first.save')
            self.assertEqual({'first.save'}, s.achievements)
            first = s.purchase('example.cosmetic', 'request1', approved=True)
            self.assertEqual(first, s.purchase('example.cosmetic', 'request1'))
            self.assertFalse(first['charged'])
            first['status'] = 'mutated'
            self.assertEqual('fake-approved', s.purchase('example.cosmetic', 'request1')['status'])
            s.close()
            with self.assertRaises(RuntimeError): s.load('one')

    def test_service_rejects_invalid_inputs(self):
        s = m.FakeServices()
        for slot in ('../escape', '', 'a' * 65):
            with self.assertRaises(ValueError): s.save(slot, b'x')
        with self.assertRaises(ValueError): s.save('slot', b'x' * (1024 * 1024 + 1))
        with self.assertRaises(ValueError): s.purchase('not-in-catalog', 'x')

    def test_android_contract(self):
        value = {'applicationId': 'org.example.app', 'minSdk': 26, 'targetSdk': 36,
                 'abis': ['arm64-v8a'], 'sdkPackages': ['platforms;android-36']}
        self.assertTrue(m.android_inputs(value)['valid'])
        value['applicationId'] = '../bad'
        value['minSdk'] = 99
        self.assertFalse(m.android_inputs(value)['valid'])

    def test_windows_and_scene_contracts(self):
        self.assertFalse(m.windows_inputs({})['valid'])
        self.assertTrue(m.windows_inputs({'compiler': 'cl.exe', 'compilerVersion': 'pinned',
            'windowsSdkVersion': 'pinned', 'architecture': 'x64', 'flags': ['/W4']})['valid'])
        v = {'schemaVersion': 1, 'coordinateSystem': 'right-handed-y-up',
             'entities': [{'id': 'player'}], 'inputActions': {'confirm': 'Enter'}}
        self.assertTrue(m.scene_contract(v)['valid'])
        v['entities'].append({'id': 'player'})
        self.assertFalse(m.scene_contract(v)['valid'])


if __name__ == '__main__': unittest.main()
