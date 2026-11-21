# Offline payloads and original substitutes

All 19 acquisition recipes were reviewed. This pack contains **46 selected
archives, 5,570,347,796 bytes** (about 5.19 GiB), plus retained
licenses, provenance, original test doubles and inert examples. Every recipe is
explicitly **partial** or **restricted-with-original**; no arbitrary project is
claimed ready to build offline.

The archives include Node/npm, CMake, Gradle, Rust for Windows/MSVC, Python's
embeddable distribution, a pure-Python packaging wheel and matching source, Godot
standard Windows editor and matching export templates, the WebView2 SDK NuGet
package, Violentmonkey's extension and exact source, and source snapshots for
Stylus, Flutter, .NET SDK, Android NDK samples, vcpkg, Playwright and Lucide.
Also present are a portable Temurin 21 JDK with exact source/build scripts,
JetBrains Mono OFL fonts, a modified Flutter SDK without MinGit, and a modified
browser reference without uBO with corresponding source and component notices.

Read `inventory.json` for exact revisions, URLs, whole/part hashes, sizes,
publisher-checksum comparisons and retained license paths. Read `recipes/` for
each acquisition decision and remaining requirements. Source archives are the
selected upstream trees, not their submodule/LFS/package dependency build graph.

## Verify without network or third-party execution

Python 3.10+ standard library, no packages:

```text
python development/acquisitions/verify.py verify
python -m unittest discover -s development/acquisitions/tests -v
```

The verifier reads inventory-listed contained regular files, rejects linked paths
and Windows path aliases, checks individual/whole SHA-256 and sizes, then streams
ZIP CRC, TAR contents or a passive PE envelope with bounded member counts and expansion. The ordinary verifier never
extracts archives, runs SDKs/package hooks, installs software, accepts vendor
licenses, accesses devices or sends network requests. Safe relative links in
inert source archives are counted and target-checked without materialization.
Source archives may have case-distinct names; use a suitable filesystem if you
later choose to extract them. Concurrent hostile filesystem mutation is outside
the trusted-checkout contract.

Limits: 256 archives, 96 MiB per stored part/support file, 550,000 members and
32 GiB expanded bytes per archive, 4 GiB per member. `--hashes-only` explicitly
skips archive inspection. Exit 0 means the selected checks passed, exit 2 means
invalid input/artifact or a verification failure. Argparse usage errors also use 2.
Recorded hashes establish identity, not a security certification. Some upstream
archives have no publisher-provided checksum; these are explicitly marked false.

## Reconstruct an exact large archive

Git's per-file limit is respected using contiguous 48 MiB parts for archives
larger than 95 MiB. No compressed data is transformed and no LFS server is needed.
For example, choose a **new** output directory whose parent already exists:

```text
python development/acquisitions/verify.py reconstruct godot-export-templates --output C:/Temp/DevTools-Godot-Exports
```

This verifies the selected parts, whole archive and archive contents, flushes an
owned temporary file, then renames it into the new directory. It refuses existing
output directories and linked parents; it does not install/extract the result.
Plan enough additional disk space for the whole reconstructed archive. Existing
host toolchains and caches are neither inventoried nor changed by these commands.

## Distribution decisions and original alternatives

- Microsoft Windows/MSVC SDK and Windows .NET SDK standalone binaries are not
  mirrored under their restricted vendor terms. .NET MIT source is retained;
  `original/windows-inputs.json` records explicit build inputs, not an installed SDK.
- Google's Android SDK bundle is not mirrored under its redistribution restriction.
  Apache-licensed NDK sample source and an original package/API/ABI input validator
  are retained. No license acceptance is automated.
- Unity, Unreal and partner/store SDKs remain vendor-controlled. Original
  `scene-input-save.json` and `offline_contracts.py` provide engine-neutral input,
  scene, save, achievement and fake-purchase fixtures. They are **not vendor API
  replacements**, rendering engines, compilers, billing or production services.
- Flutter source and a **modified Flutter 3.50.1 Windows SDK** are present. The
  entire bundled MinGit subtree is excluded; supply a separately installed Git.
  All other member bytes and notices are preserved. `DERIVATION.json` and
  `derive_flutter.py` record the original publisher input hash, omission and
  independently hashed result. Project pub/plugin caches and target SDKs remain
  separate. Stylus remains source-only under GPL3.
- A **modified DevTools browser reference derived from Mullvad 16.0.2** is present.
  The entire uBO extension is removed because it bundles a noncommercial asset.
  All 181 retained browser file bytes remain unchanged. Exact core source, build
  configuration, NoScript/NSCL and Mullvad extension sources, font licenses and
  attributions accompany it. `BROWSER-DERIVATION.json` and `derive_browser.py`
  record the selection and member identities. It is an independently modified
  reference archive, without vendor endorsement or an official package/signature
  claim. Browser installation, launch and rendering are unverified. Playwright
  remains source-only. The original installer and compiled uBO XPI are excluded.

Third-party files retain upstream terms, including bundled licenses/notices in
their archives. The pack's MIT license does not relicense them. `original/` code
and synthetic SVG/WAV/OBJ/JSON fixtures have their own MIT license. No trademark
endorsement, vendor compatibility, signing, runtime/device/browser testing or
offline project build success is implied by static verification.

## Derivation evidence

Original vendor SDKs and browser executables were never launched. A publisher-
checksum-verified 7-Zip 26.06 tool was used only in owned scratch space to list
and extract the browser installer as data; it was not installed globally. The
built-in tar reader could not inspect that installer (exit 1). The resulting
modified browser ZIP passes the ordinary offline CRC/member checks.

The two derivation scripts operate only on explicitly supplied, already acquired
inputs and new output files; they never download, install or run SDKs/browsers.
Recompression may differ across Python/zlib versions; member data is preserved
and the actual reviewed output SHA-256 is recorded. Inspect the scripts and their
input receipts before any later derivation.

Platform samples also retain Zig binaries/source, official PortableApps.com tools and matching sources, plus a clearly labeled relocatable NSIS compiler derived from unchanged NSIS 3.13 source with zlib 1.4. Its exact bootstrap inputs and host preparation recipe are in `../samples/bootstraps/nsis/`. Actual network-denied sample build evidence is separate from compiler preparation.
