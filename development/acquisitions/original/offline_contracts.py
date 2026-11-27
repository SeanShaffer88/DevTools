"""Original no-network readiness contracts and deterministic service test doubles.

These are not vendor SDKs, emulators, billing systems or API-compatible replacements.
"""
from __future__ import annotations

from dataclasses import dataclass, field
import re


def windows_inputs(value):
    if not isinstance(value, dict):
        return {'valid': False, 'findings': ['object required']}
    required = ('compiler', 'compilerVersion', 'windowsSdkVersion', 'architecture', 'flags')
    missing = [x for x in required if not value.get(x)]
    for name in required[:-1]:
        if not isinstance(value.get(name), str):
            missing.append(name + ' must be a string')
    if value.get('architecture') not in ('x86', 'x64', 'arm64'):
        missing.append('supported architecture')
    if not isinstance(value.get('flags'), list) or any(not isinstance(x, str) for x in value.get('flags', [])):
        missing.append('flags must be string array')
    return {'valid': not missing, 'findings': missing, 'compilerExecuted': False,
            'sdkInstalled': 'Unknown', 'compatibility': 'Unverified'}


def android_inputs(value):
    if not isinstance(value, dict):
        return {'valid': False, 'findings': ['object required']}
    findings = []
    app_id = value.get('applicationId')
    if not isinstance(app_id, str) or not re.fullmatch(r'[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+', app_id):
        findings.append('invalid applicationId')
    minimum, target = value.get('minSdk'), value.get('targetSdk')
    if not isinstance(minimum, int) or isinstance(minimum, bool) or not isinstance(target, int) or isinstance(target, bool) or not 1 <= minimum <= target <= 999:
        findings.append('require integer 1 <= minSdk <= targetSdk <= 999')
    abis = value.get('abis', [])
    if not isinstance(abis, list) or not abis or any(not isinstance(x, str) or x not in ('armeabi-v7a', 'arm64-v8a', 'x86', 'x86_64') for x in abis) or len(set(abis)) != len(abis):
        findings.append('invalid or duplicate ABI list')
    packages = value.get('sdkPackages', [])
    if not isinstance(packages, list) or not packages or any(not isinstance(x, str) or not re.fullmatch(r'[A-Za-z0-9_.;-]+', x) for x in packages):
        findings.append('invalid SDK package IDs')
    # Deliberately inert: no acceptance of licenses and no executable command.
    return {'valid': not findings, 'findings': findings, 'requestedPackages': packages,
            'licenseAcceptance': 'NotPerformed', 'sdkAcquisition': 'NotPerformed',
            'deviceCompatibility': 'Unverified'}


def scene_contract(value):
    if not isinstance(value, dict):
        return {'valid': False, 'findings': ['object required']}
    findings = []
    if type(value.get('schemaVersion')) is not int or value['schemaVersion'] != 1:
        findings.append('schemaVersion must be 1')
    if value.get('coordinateSystem') not in ('right-handed-y-up', 'left-handed-y-up'):
        findings.append('declare coordinateSystem')
    entities = value.get('entities', [])
    if not isinstance(entities, list) or len(entities) > 10000:
        findings.append('bounded entity array required')
        entities = []
    ids = [x.get('id') for x in entities if isinstance(x, dict)]
    if len(ids) != len(entities) or any(not isinstance(x, str) or not x for x in ids) or len(set(ids)) != len(ids):
        findings.append('unique nonempty entity IDs required')
    actions = value.get('inputActions', {})
    if not isinstance(actions, dict) or not actions or any(not isinstance(k, str) or not isinstance(v, str) for k, v in actions.items()):
        findings.append('named input action map required')
    return {'valid': not findings, 'findings': findings, 'engineExecuted': False,
            'vendorApiCompatibility': False}


@dataclass
class FakeServices:
    """Injected in-memory adapter: deterministic, explicit, never charges or persists."""
    products: frozenset[str] = frozenset(('example.cosmetic',))
    achievements: set[str] = field(default_factory=set)
    saves: dict[str, bytes] = field(default_factory=dict)
    receipts: dict[str, dict] = field(default_factory=dict)
    closed: bool = False

    def _open(self):
        if self.closed:
            raise RuntimeError('adapter closed')

    def save(self, slot, data):
        self._open()
        if not isinstance(slot, str) or not re.fullmatch(r'[A-Za-z0-9_-]{1,64}', slot):
            raise ValueError('invalid slot')
        if not isinstance(data, bytes) or len(data) > 1024 * 1024:
            raise ValueError('save must be bytes up to 1 MiB')
        self.saves[slot] = data

    def load(self, slot):
        self._open()
        return self.saves.get(slot)

    def unlock(self, achievement):
        self._open()
        if not isinstance(achievement, str) or not re.fullmatch(r'[A-Za-z0-9_.-]{1,64}', achievement):
            raise ValueError('invalid achievement')
        self.achievements.add(achievement)

    def purchase(self, product, request_id, *, approved=False):
        self._open()
        if product not in self.products or not isinstance(request_id, str) or not re.fullmatch(r'[A-Za-z0-9_-]{1,64}', request_id):
            raise ValueError('invalid product/request ID')
        if request_id in self.receipts:
            receipt = self.receipts[request_id]
            if receipt['product'] != product:
                raise ValueError('request ID already used for another product')
            return dict(receipt)
        receipt = {'product': product, 'requestId': request_id,
                   'status': 'fake-approved' if approved else 'fake-declined', 'charged': False}
        self.receipts[request_id] = receipt
        return dict(receipt)

    def close(self):
        self.closed = True
