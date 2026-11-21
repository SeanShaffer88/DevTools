# Offline development coverage

Version 1 is a practical lifecycle overlay, not an exhaustive API manual, SDK mirror or promise that arbitrary projects build offline. Read the canonical root domain before choosing tools. Search/audit only read cataloged local files; reference code is not automatically executed.

| Domain | Original offline working material | Existing canonical depth | Remaining project-specific evidence |
| --- | --- | --- | --- |
| Windows software | Lifecycle guide; quality contract | knowledge; windevkit; root toolkit | Matching SDK/runtime/cache, native UI/footprint/upgrade/signing |
| Android apps | Lifecycle guide; acceptance contract | kotlin; flutter; Android helpers | SDK/JDK/Gradle compatibility, actual device, release signing/store policy |
| Android games | Lifecycle guide; game acceptance contract | godot; kotlin; asset/replay helpers | Matching export templates, hardware/backend/thermal/lifecycle matrix |
| Websites | Lifecycle guide; local HTML/CSS/JS example | quality resources; acquired web references | Real browser/accessibility audit, server auth, deployment/headers/TLS |
| PC games | Lifecycle guide; versioned save schema/fixture | godot; asset/replay helpers | Engine/toolchain, replay determinism, hardware performance, distribution |
| Userscripts | Lifecycle guide; narrow example.com script | Original guidance and linked official manager/API references | Manager install, browser injection/security scope, actual site compatibility |
| Userstyles | Lifecycle guide; narrow original UserCSS | Original guidance and linked official manager/API references; design material | Actual manager parsing, site selectors, zoom/print/forced colors |
| Dependencies | Lifecycle guide; inert acquisition plan | ai-resources; pinned GitHub catalog; toolkit | Pinned selected downloads/licenses present; complete project caches and isolated disconnected build remain required |

## Availability and trust

- Original guides/templates are local authored content. Examples have no external dependencies, network requests or persistence; they do not install or enable themselves.
- Vendored resources retain separate upstream identity/license evidence. Their presence is not runtime, security or redistribution certification for a derived product.
- Reference-only pointers are discoverable, but a URL does not become offline documentation. Not-acquired components remain explicit gaps.
- CLI integrity hashes establish local identity, not safety. Fixture/static checks remain distinct from target browser, engine, device and release evidence.

## Using the packs

Select one domain guide plus its template. Fill in actual versions, targets, write boundaries, executable/argument arrays and acceptance gates. Reuse canonical material through links instead of duplicating it. Prepare dependency caches through a reviewed acquisition plan, then test the selected project's declared build with networking unavailable. Keep private registries, signing keys, authentication data, user files and runtime profiles outside this library.

Each project records Pass/Fail/Unknown/NotRun, commands and exit codes, dated evidence paths and remaining gaps. No tool activation, external publication, device state change or package hook execution follows merely from a catalog match.

## Acquisition follow-through

All 18 acquisition recipes now have explicit local assessment reports in
`acquisitions/recipes/`. Redistributable selected payloads and exact licenses are
recorded in `acquisitions/inventory.json`; restricted SDKs have original input,
scene/save or service-double substitutes where feasible. Every recipe remains
partial or restricted-with-original because project dependencies, vendor APIs,
activation and runtime validation are separate requirements. The acquisition
verifier checks byte identity and bounded inert archive contents offline.
