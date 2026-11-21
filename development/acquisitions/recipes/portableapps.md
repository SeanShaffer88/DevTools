# PortableApps.com Development Tools

Status: **partial**. Official Launcher 2.2.9, Installer 3.9.24 and NSIS Portable 3.13 archives are saved, with matching NSIS 3.13/2.46.5 Unicode and 7-Zip source. The official tool archives are extracted as data; they are never installed to prepare a build. Original third-party license and source records are in inventory.json.

The original development/samples/portableapps fixture wraps the original native Windows sample. Its target is real PAL launcher and PAF installer compilation. A successful build is **Built** only, not Installation Verified or Runtime Portability Verified. No installer launch, registry tracing, upgrade, drive-letter relocation or host cleanup claim follows from compilation.

Use portableapps/AGENTS.md, docs/01-format-spec.md, docs/02-installer-and-installer-ini.md, docs/03-launcher-overview.md and docs/04-launcher-ini-reference.md. Tool version currency was checked against live publisher pages on 2026-11-21. AppCompactor is not part of this sample.

Verification: python development/acquisitions/verify.py verify. The ordinary verifier passively checks PAF PE envelopes; it does not install or inspect their internal payload. Source ZIP/TAR archives receive full bounded content scans. Separate preparation receipts record tool extraction and member identities.

Primary sources:
- https://portableapps.com/apps/development/portableapps.com_installer
- https://portableapps.com/apps/development/portableapps.com_launcher
- https://portableapps.com/apps/development/nsis_portable
- https://nsis.sourceforge.io/Download

The GUI generators and stock NSIS 3.13 compiler fail native startup with error623 under zero-capability AppContainer isolation. The sample uses the exact official source backend interfaces and a saved, relocatable x86 NSIS 3.13 compiler built from unchanged source with static zlib 1.4. See `../../samples/bootstraps/nsis/` for source pins, notices and the host preparation recipe. This derived compiler is explicitly not a publisher-provided binary. Generated PAF artifacts stay local pending corresponding-source redistribution review.
