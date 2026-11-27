# Python and target-specific wheelhouse

Status: **partial**. This is payload coverage, not an installed/complete offline toolchain.

Acquired payload IDs: `python-embed-win-x64`, `packaging-wheel`, `packaging-source`.

Remaining requirements and limits: Python Windows embeddable distribution plus packaging pure-Python wheel and matching source retained. Embeddable runtime has no pip; use an independently prepared compatible interpreter/pip. Other project requirements and native ABI wheels remain project-specific.

Verify from the repository root: `python development/acquisitions/verify.py verify`. The verifier reads local bytes only and checks archive contents without extraction/execution. `inventory.json` records exact source, version/revision, hashes, retained license paths and publisher-checksum evidence.

Upstream preparation/terms references:
- https://pip.pypa.io/en/stable/cli/pip_download/
- https://pip.pypa.io/en/stable/topics/repeatable-installs/
