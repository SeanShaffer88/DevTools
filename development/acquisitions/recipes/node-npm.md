# Node.js and npm package cache

Status: **partial**. This is payload coverage, not an installed/complete offline toolchain.

Acquired payload IDs: `node-win-x64`.

Remaining requirements and limits: Node/npm portable Windows x64 distribution retained with complete bundled licenses. Arbitrary project package-lock transitive dependencies/cache/install scripts remain project-specific.

Verify from the repository root: `python development/acquisitions/verify.py verify`. The verifier reads local bytes only and checks archive contents without extraction/execution. `inventory.json` records exact source, version/revision, hashes, retained license paths and publisher-checksum evidence.

Upstream preparation/terms references:
- https://docs.npmjs.com/cli/v11/commands/npm-cache/
- https://docs.npmjs.com/cli/v11/commands/npm-ci/
