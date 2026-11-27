# Userscripts

Original lifecycle guidance. A userscript executes through a selected manager in matching browser pages; Node syntax checking does not establish browser or manager compatibility.

## Scope and permissions

Record browser/manager versions, exact sites/paths, frames, timing, user trigger and modified data. Prefer DOM-only behavior with no privileged grants when possible. Manager-specific GM APIs require explicit compatibility testing. Avoid wildcard host access and never inspect authentication tokens as an implementation shortcut.

The [example script](../templates/userscripts/example.user.js) matches only `https://example.com/*`, excludes frames, waits for idle and adds a user-triggered local status button. It performs no network, persistence or automatic form submission. Installing a manager or enabling a script is a separate user action. Do not replace its scope with an account website without reviewing that boundary.

## Implementation

Keep metadata, page adaptation, pure transformations and UI controls distinguishable. Use unique element IDs and idempotent initialization. Prefer stable semantic selectors with a missing-element path. For dynamic pages, observe only the required subtree and disconnect when done; avoid endless interval polling. SPA navigation needs explicit lifecycle handling and duplicate-listener tests.

Insert text with textContent. Treat page DOM and remote responses as untrusted. Never expose privileged APIs to page scripts or evaluate remote/page strings. Avoid floating @require URLs. External requests require narrowly scoped permission, response validation and documented purpose. Settings, clipboard and downloads need explicit user-visible behavior, bounded values and cleanup.

## Tests and failure paths

Run syntax checks with an installed runtime, then exercise an inert fixture and the actual manager in an authorized browser profile. Test mismatch pages, frames, repeated setup, navigation, missing anchors, disabled behavior and removal. No smoke test should submit forms, purchase, send messages or change account state. Record manager/browser version and distinguish static, fixture and actual-page results.

Do not log page content by default. Failure should disable the affected feature and explain the missing selector/API rather than repeatedly retrying. Provide a visible disable/removal route; remove owned observers/listeners and controls without changing unrelated page content. Measure large-page behavior only with representative fixtures and a bounded observation budget.

## Release and offline preparation

Publish inspectable source, version, license, narrow metadata and a deliberate update policy. Dependency hashes help identity but do not establish trust. Retain fixtures for site changes and a rollback version. Offline material consists of script and fixtures; a manager installer is not included and must be acquired separately if required.

Official format/API source checked 2026-11-21: [Tampermonkey documentation](https://www.tampermonkey.net/documentation.php). Metadata and grant decisions must be verified for the selected manager/version. This pack's prose and example are original, not copied manager documentation.
