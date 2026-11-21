# Rust toolchain and Cargo vendored sources

Status: **partial**. This is payload coverage, not an installed/complete offline toolchain.

Acquired payload IDs: `rust-win-msvc`.

Remaining requirements and limits: Rust standalone Windows MSVC toolchain archive retained with bundled notices. Separately licensed MSVC linker/Windows SDK and per-project locked crate/native source graph remain required. No install, proc macro or build script was executed.

Verify from the repository root: `python development/acquisitions/verify.py verify`. The verifier reads local bytes only and checks archive contents without extraction/execution. `inventory.json` records exact source, version/revision, hashes, retained license paths and publisher-checksum evidence.

Upstream preparation/terms references:
- https://doc.rust-lang.org/cargo/commands/cargo-vendor.html
