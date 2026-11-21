# Target browsers and browser test dependencies

Status: **partial**. This is payload coverage, not an installed/complete offline toolchain.

Acquired payload IDs: `playwright-source`, `mullvad-browser-core-source`, `mullvad-build-source`, `mullvad-extension-source`, `ublock-source`, `noscript-source`, `noscript-nscl-source`, `mullvad-extension`, `noscript-extension`, `devtools-browser-reference-no-ublock`.

Remaining requirements and limits: Playwright source and a modified DevTools browser reference derived from Mullvad 16.0.2 are retained with exact Firefox core source, build configuration, NoScript/NSCL and Mullvad extension sources. The entire uBO extension was removed because it contains a noncommercial Peter Lowe asset; uBO code source remains a separate reference only. This is an independently modified archive, with no vendor endorsement or official package/signature claim. Browser installation, runtime and compatibility remain unverified. BROWSER-DERIVATION.json records the original input checksum and 181 unchanged retained member identities.

Verify from the repository root: `python development/acquisitions/verify.py verify`. The verifier reads local bytes only and checks archive contents without extraction/execution. `inventory.json` records exact source, version/revision, hashes, retained license paths and publisher-checksum evidence.

Upstream preparation/terms references:
- https://playwright.dev/docs/browsers
- https://www.mozilla.org/en-US/MPL/
- https://www.mozilla.org/en-US/foundation/trademarks/distribution-policy/
