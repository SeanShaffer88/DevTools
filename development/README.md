# Offline development library

Original guides and inert examples cover Windows, Android apps/games, websites,
PC games, userscripts, userstyles and dependencies. Catalog entries distinguish
original material, pinned vendored references, reference-only pointers and resources
partial or restricted acquisition coverage. Static examples and source snapshots are not verified applications.

Use installed Python 3.10 or newer; no packages, network, services or background work:

```text
python development/tools/library.py audit --root .
python development/tools/library.py search "cancellation" --domain windows --limit 5
python development/tools/library.py plan --domain android-games
python -m unittest discover -s development/tests -v
```

Commands emit JSON by default (`--format text` uses readable Unicode JSON).
Exit codes: 0 completed/pass, 2 audit findings, 125 setup/invalid catalog.
Argparse usage errors return 2. `audit --write-manifest` explicitly refreshes the
reviewed catalog's file hashes and sizes in `development/manifest.json`; ordinary
audit verifies it without writing. Review intended content changes before refreshing.
The manifest's `catalogSha256` covers seed bytes, optional vendor catalog bytes and
vendor SOURCES bytes joined with newlines in that order; vendor license/source file
identities are verified against SOURCES as well as catalogued resource hashes.
Manifest `identityEncoding` is `utf8-lf` for reference-only canonical documents:
their UTF-8 text has CRLF/CR normalized to LF before size/hash calculation, so Git
checkout EOL settings do not invalidate identical content. Original/vendored entries
use `raw-bytes`; read budgets always count actual bytes read.
Reference-only documents must be valid UTF-8; malformed text is a setup error.

Only catalog-listed local files are read. Limits: 512 entries, 1 MiB per file,
16 MiB cumulative input, search result limit 1–50, query at most 512 characters.
Symlinks/reparse points and path escapes are rejected. Metadata source URLs are
HTTPS without credentials and never fetched. Do not place secrets in curated docs.
Concurrent untrusted mutation of the repository is outside this offline tool's
contract; use a trusted, stable checkout.

Planning lists guides/examples/references and explicit missing optional resources.
It does not install dependencies or execute examples. Upstream source and license
metadata must be checked before adapting or distributing third-party material.
Original library content uses [MIT](LICENSE); `vendor/` retains upstream terms.

## Acquired dependencies and original substitutes

See [acquisitions/README.md](acquisitions/README.md) and its 18 per-recipe reports
for the exact redistributable payloads, retained licenses, source identities and
remaining requirements. Binary archives/chunks use a separate streaming verifier
and are never decoded by the bounded text search. Original contracts and local
service fakes cover feasible restricted-toolchain workflows without claiming
vendor API compatibility.

```text
python development/acquisitions/verify.py verify
python -m unittest discover -s development/acquisitions/tests -v
```

No SDK installation, third-party execution, device/browser check or arbitrary
project offline build is implied.
