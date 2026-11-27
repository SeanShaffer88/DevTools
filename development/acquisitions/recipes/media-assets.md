# Fonts, icons, audio, models and sample datasets

Status: **partial**. This is payload coverage, not an installed/complete offline toolchain.

Acquired payload IDs: `lucide-source`, `jetbrains-mono-fonts`.

Original offline substitute: `original/media`. Original MIT code; no vendor API compatibility or production service behavior claimed.

Remaining requirements and limits: The pinned JetBrains Mono 2.304 font archive (OFL 1.1), Lucide source/icons with ISC notices, and original MIT SVG/WAV/OBJ/JSON fixtures are retained. Respect reserved font names and each asset license. Rendering and embedding were not tested; rights to unrelated assets are not implied.

Verify from the repository root: `python development/acquisitions/verify.py verify`. The verifier reads local bytes only and checks archive contents without extraction/execution. `inventory.json` records exact source, version/revision, hashes, retained license paths and publisher-checksum evidence.

Upstream preparation/terms references:
- https://spdx.org/licenses/
- https://creativecommons.org/publicdomain/zero/1.0/
