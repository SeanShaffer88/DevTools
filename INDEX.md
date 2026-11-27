# INDEX — DevTools knowledge library master map

One repo, twelve development knowledge bases and resource collections, plus the local developer toolkit.
This file is the router: find the domain, then the file, in seconds.

## How an AI should use this repo

1. Start here. Match the task to a domain in the table below.
2. Open that domain's `manifest.json` (file map + reading order) and `AGENTS.md` (its rules).
3. Short on context? Upload the domain's `ai-bundle.md` instead — the whole domain in one file.
4. Use the task routing table for direct jumps to the single best file.
5. The root `README.md` + `toolkit.json` describe the PowerShell toolkit scripts, a separate thing from the knowledge library. `ai_tools/` holds offline Python CLI checks.

## Offline Development Workflows

Start with [development/README.md](development/README.md) for the cross-domain offline library covering Windows software, Android apps, Android games, websites, PC games, userscripts, userstyles and developer dependencies, PortableApps.com packaging and WoW addons. Its original guides and templates fill workflow gaps while linking to the canonical domain material below. [SOURCES.json](development/vendor/SOURCES.json) records the small licensed source snapshots actually present.

~~~powershell
python development/tools/library.py audit
python development/tools/library.py search "keyboard focus" --domain websites
python development/tools/library.py plan --domain dependencies
~~~

The catalog distinguishes local content, reference-only pointers and partial or restricted acquisition coverage. [Offline payloads and original substitutes](development/acquisitions/README.md) records all 19 recipe decisions, retained licenses and exact archive identities. Run `python development/acquisitions/verify.py verify` for the separate offline binary/archive gate. Search reads curated local files without network access. Read dependency acquisition and licensing notes before preparing an offline toolchain. Validation proves the recorded files and examples, with actual builds and device/browser checks reported separately.

Original [platform samples](development/samples/README.md) provide a reproducible `Build-OfflineSamples.ps1` entrypoint for ten build/validation targets, including real PortableApps PAL/PAF compilation. Android requires an explicitly supplied private licensed SDK. Generated binaries remain local verification artifacts; runtime/device/installer checks are separate.

## Domains

| Domain | Folder | Covers | Start | Single-file bundle |
| --- | --- | --- | --- | --- |
| PortableApps.com packaging | [`portableapps/`](portableapps/) | PortableApps.com format, Launcher + Installer INI, packaging workflow, updating, failure modes, submission | [portableapps/manifest.json](portableapps/manifest.json) | [portableapps/ai-bundle.md](portableapps/ai-bundle.md) |
| World of Warcraft addon development | [`wow-addons/`](wow-addons/) | Addon anatomy, Lua, API/events/widgets, flavors + interface numbers (Forever first, interface 16001), libraries, packaging | [wow-addons/manifest.json](wow-addons/manifest.json) | [wow-addons/ai-bundle.md](wow-addons/ai-bundle.md) |
| Kotlin Android apps and games | [`kotlin/`](kotlin/) | Kotlin, Compose, architecture, Room, coroutines, testing, Play release, billing, games (Compose Canvas, libGDX, native graphics) | [kotlin/manifest.json](kotlin/manifest.json) | [kotlin/ai-bundle.md](kotlin/ai-bundle.md) |
| ForAI resource library | [`forai/`](forai/) | The big curated library: dev resources, Windows development repositories, AI resources, catalogs and category files, with its own AI index and full-text file | [forai/AI_INDEX.md](forai/AI_INDEX.md) | [forai/llms-full.txt](forai/llms-full.txt) |
| WinDevKit shared development resources | [`windevkit/`](windevkit/) | Windows dev kits and crates (image, OCR, PDF, thumbnails and more), bindings, templates, schemas, tools — built for the wider Windows dev community | [windevkit/docs/CATALOG.md](windevkit/docs/CATALOG.md) | [windevkit/README.md](windevkit/README.md) |
| AI development resource index | [`ai-resources/`](ai-resources/) | Curated pointers: toolchains, MCP servers, agent frameworks, local inference, models/providers, RAG + vector, eval/observability, coding agents, ML libraries, learning references | [ai-resources/manifest.json](ai-resources/manifest.json) | [ai-resources/resources.json](ai-resources/resources.json) |
| Godot for Android games and apps | [`godot/`](godot/) | Godot engine versions, project anatomy, Android export pipeline, Google Play, plugins, testing/CI, permissions | [godot/manifest.json](godot/manifest.json) | [godot/ai-bundle.md](godot/ai-bundle.md) |
| Windows desktop development system | [`knowledge/`](knowledge/) | Rule layers (Elite Prompt, Engineering Contract V4.0, guardrails), tiers + sanctioned stacks, QUALITY.md gate, SeanPak packaging, TesselGUI design, release verification | [knowledge/manifest.json](knowledge/manifest.json) | [knowledge/ai-bundle.md](knowledge/ai-bundle.md) |
| Flutter development pack | [`flutter/`](flutter/) | Toolchain, Dart, widgets/UI, state, navigation, networking, storage, testing, Windows desktop, Android release, flavors, performance, architecture | [flutter/manifest.json](flutter/manifest.json) | [flutter/ai-bundle.md](flutter/ai-bundle.md) |
| Offline development workflows | [`development/`](development/) | Cross-domain offline library: Windows software, Android apps and games, websites, PC games, userscripts/userstyles, developer dependencies, PortableApps, WoW addons — guides, templates, platform samples, offline payloads | [development/README.md](development/README.md) | [development/README.md](development/README.md) |
| AV/EDR scrub-tool index | [`av-scrub-index/`](av-scrub-index/) | Machine-readable dataset of official antivirus/EDR removal tools: downloads, silent switches, Safe Mode notes, JSON schema | [av-scrub-index/dist/index.json](av-scrub-index/dist/index.json) | [av-scrub-index/README.md](av-scrub-index/README.md) |
| Prompt-engineering library | [`prompt-architect/`](prompt-architect/) | Prompt Architect: how models read prompts, pattern catalogue, blueprints for nine task classes, cost/safety guides, evaluation rubric | [prompt-architect/fundamentals/how-llms-read-prompts.md](prompt-architect/fundamentals/how-llms-read-prompts.md) | [prompt-architect/guides/cheat-sheet.md](prompt-architect/guides/cheat-sheet.md) |

## Task routing — the one best file

| Task / question | Go to |
| --- | --- |
| Package a Windows app as PortableApps.com Portable | [portableapps/docs/07-end-to-end-workflow.md](portableapps/docs/07-end-to-end-workflow.md) |
| PortableApps format specification | [portableapps/docs/01-format-spec.md](portableapps/docs/01-format-spec.md) |
| PortableApps Launcher INI key (any key) | [portableapps/reference/launcher-keys.md](portableapps/reference/launcher-keys.md) |
| PortableApps Launcher INI in depth | [portableapps/docs/04-launcher-ini-reference.md](portableapps/docs/04-launcher-ini-reference.md) |
| PortableApps Installer INI key | [portableapps/reference/installer-keys.md](portableapps/reference/installer-keys.md) |
| PortableApps package layout | [portableapps/reference/package-layout.md](portableapps/reference/package-layout.md) |
| Update an existing PortableApps package | [portableapps/docs/16-updating-a-package.md](portableapps/docs/16-updating-a-package.md) |
| PortableApps failure / troubleshooting | [portableapps/docs/17-failure-mode-reference.md](portableapps/docs/17-failure-mode-reference.md) |
| Validate a PortableApps package | [portableapps/tools/check-package.py](portableapps/tools/check-package.py) |
| Start a new PortableApps package | [portableapps/tools/new-package.sh](portableapps/tools/new-package.sh) |
| WoW addon anatomy and .toc files | [wow-addons/docs/01-addon-anatomy.md](wow-addons/docs/01-addon-anatomy.md) |
| WoW interface numbers (Forever = 16001) | [wow-addons/reference/interface-numbers.md](wow-addons/reference/interface-numbers.md) |
| WoW flavors and interface numbers in depth | [wow-addons/docs/04-flavors-and-interface-numbers.md](wow-addons/docs/04-flavors-and-interface-numbers.md) |
| Lua as used in WoW | [wow-addons/docs/02-lua-in-wow.md](wow-addons/docs/02-lua-in-wow.md) |
| WoW API, events and widgets | [wow-addons/docs/03-api-events-and-widgets.md](wow-addons/docs/03-api-events-and-widgets.md) |
| WoW common events list | [wow-addons/reference/common-events.md](wow-addons/reference/common-events.md) |
| WoW addon libraries (Ace3 etc.) | [wow-addons/docs/05-libraries-and-frameworks.md](wow-addons/docs/05-libraries-and-frameworks.md) |
| Validate a WoW addon | [wow-addons/tools/check-addon.py](wow-addons/tools/check-addon.py) |
| Scaffold a new WoW addon | [wow-addons/templates/minimal/Minimal.toc](wow-addons/templates/minimal/Minimal.toc) |
| Kotlin language for Android | [kotlin/docs/01-kotlin-language-for-android.md](kotlin/docs/01-kotlin-language-for-android.md) |
| Jetpack Compose UI | [kotlin/docs/05-jetpack-compose-ui.md](kotlin/docs/05-jetpack-compose-ui.md) |
| Room / DataStore / file persistence | [kotlin/docs/11-data-persistence-room-datastore-files.md](kotlin/docs/11-data-persistence-room-datastore-files.md) |
| Coroutines and Flow | [kotlin/docs/10-coroutines-flow-and-concurrency.md](kotlin/docs/10-coroutines-flow-and-concurrency.md) |
| Android architecture patterns (MVVM etc.) | [kotlin/docs/08-architecture-patterns.md](kotlin/docs/08-architecture-patterns.md) |
| Google Play requirements and deadlines | [kotlin/reference/play-requirements-and-deadlines.md](kotlin/reference/play-requirements-and-deadlines.md) |
| Build, sign and release an Android app (Kotlin) | [kotlin/docs/19-build-signing-release-and-google-play.md](kotlin/docs/19-build-signing-release-and-google-play.md) |
| Play submission checklist (Kotlin) | [kotlin/checklists/play-submission-checklist.md](kotlin/checklists/play-submission-checklist.md) |
| Choose a game route on Android (Kotlin) | [kotlin/docs/23-games-overview-choosing-a-route.md](kotlin/docs/23-games-overview-choosing-a-route.md) |
| Game route comparison table | [kotlin/reference/game-route-comparison.md](kotlin/reference/game-route-comparison.md) |
| ADB and tooling commands | [kotlin/reference/adb-and-tooling-commands.md](kotlin/reference/adb-and-tooling-commands.md) |
| Validate a Kotlin Android project | [kotlin/tools/check-project.py](kotlin/tools/check-project.py) |
| Android API levels | [kotlin/reference/api-levels.md](kotlin/reference/api-levels.md) |
| Godot engine versions | [godot/docs/01-engine-and-versions.md](godot/docs/01-engine-and-versions.md) |
| Godot version matrix | [godot/reference/version-matrix.md](godot/reference/version-matrix.md) |
| Godot Android export pipeline | [godot/docs/03-export-pipeline.md](godot/docs/03-export-pipeline.md) |
| Google Play from Godot | [godot/docs/05-google-play.md](godot/docs/05-google-play.md) |
| Godot first-export checklist | [godot/checklists/first-export-checklist.md](godot/checklists/first-export-checklist.md) |
| Godot Android permissions | [godot/docs/09-permissions.md](godot/docs/09-permissions.md) |
| Godot Android plugins (billing, AdMob, Play Games, Firebase) | [godot/docs/06-plugins.md](godot/docs/06-plugins.md) |
| Godot renderer choice for Android | [godot/docs/10-renderers.md](godot/docs/10-renderers.md) |
| Windows project tiers and sanctioned stacks | [knowledge/docs/02-tiers-and-stacks.md](knowledge/docs/02-tiers-and-stacks.md) |
| Stack decision table (task to stack) | [knowledge/reference/stack-decision-table.md](knowledge/reference/stack-decision-table.md) |
| Package a Windows program with SeanPak | [knowledge/docs/08-packaging-seanpak.md](knowledge/docs/08-packaging-seanpak.md) |
| TesselGUI Carmine design system | [knowledge/docs/07-design-tesselgui.md](knowledge/docs/07-design-tesselgui.md) |
| TesselGUI Carmine token values | [knowledge/reference/tesselgui-carmine-tokens.md](knowledge/reference/tesselgui-carmine-tokens.md) |
| Release shape and verification (Windows) | [knowledge/docs/09-release-and-verification.md](knowledge/docs/09-release-and-verification.md) |
| QUALITY.md quality gate | [knowledge/docs/04-quality-gates.md](knowledge/docs/04-quality-gates.md) |
| Engineering contract (V4.0 distilled) | [knowledge/docs/03-engineering-contract.md](knowledge/docs/03-engineering-contract.md) |
| Flutter state management | [flutter/guides/04-state-management.md](flutter/guides/04-state-management.md) |
| Flutter for Windows desktop | [flutter/guides/09-windows-desktop.md](flutter/guides/09-windows-desktop.md) |
| Flutter Android release | [flutter/guides/10-android-release.md](flutter/guides/10-android-release.md) |
| Flutter toolchain setup | [flutter/guides/01-getting-started-and-toolchain.md](flutter/guides/01-getting-started-and-toolchain.md) |

| Godot editor addons — all nine, with the demo project | [godot/toolbox/README.md](godot/toolbox/README.md) |
| Godot addon: accessibility checker | [godot/toolbox/addons/accessibility/README.md](godot/toolbox/addons/accessibility/README.md) |
| Godot addon: asset health scanner | [godot/toolbox/addons/asset_health/README.md](godot/toolbox/addons/asset_health/README.md) |
| Godot addon: dialogue / quest graph | [godot/toolbox/addons/dialogue_quest/README.md](godot/toolbox/addons/dialogue_quest/README.md) |
| Godot addon: export doctor | [godot/toolbox/addons/export_doctor/README.md](godot/toolbox/addons/export_doctor/README.md) |
| Godot addon: network simulation | [godot/toolbox/addons/network_sim/README.md](godot/toolbox/addons/network_sim/README.md) |
| Godot addon: responsive UI checker | [godot/toolbox/addons/responsive_ui/README.md](godot/toolbox/addons/responsive_ui/README.md) |
| Godot addon: scene search | [godot/toolbox/addons/scene_search/README.md](godot/toolbox/addons/scene_search/README.md) |
| Godot addon: time machine (session record/replay) | [godot/toolbox/addons/time_machine/README.md](godot/toolbox/addons/time_machine/README.md) |
| Godot addon: visual regression | [godot/toolbox/addons/visual_regression/README.md](godot/toolbox/addons/visual_regression/README.md) |
| AI resources: MCP servers and directories | [ai-resources/categories/mcp-servers.md](ai-resources/categories/mcp-servers.md) |
| AI resources: agent frameworks | [ai-resources/categories/agent-frameworks.md](ai-resources/categories/agent-frameworks.md) |
| AI resources: local inference runners | [ai-resources/categories/local-inference.md](ai-resources/categories/local-inference.md) |
| AI resources: coding agents | [ai-resources/categories/coding-agents.md](ai-resources/categories/coding-agents.md) |
| AI resources: toolchains by language/platform | [ai-resources/categories/toolchains.md](ai-resources/categories/toolchains.md) |
| AI resources: machine-readable index (all entries) | [ai-resources/resources.json](ai-resources/resources.json) |

| ForAI library entry point (AI index) | [forai/AI_INDEX.md](forai/AI_INDEX.md) |
| ForAI: Windows development repositories catalog | [forai/catalogs/windows-development-repositories.md](forai/catalogs/windows-development-repositories.md) |
| ForAI: software development resources catalog | [forai/catalogs/software-development-resources.md](forai/catalogs/software-development-resources.md) |
| ForAI: machine-readable resources | [forai/resources.json](forai/resources.json) |
| WinDevKit kit catalog (all kits) | [windevkit/docs/CATALOG.md](windevkit/docs/CATALOG.md) |
| WinDevKit pain points / why the kits exist | [windevkit/docs/PAIN_POINTS.md](windevkit/docs/PAIN_POINTS.md) |

| AV/EDR official removal tools dataset (JSON) | [av-scrub-index/dist/index.json](av-scrub-index/dist/index.json) |
| AV/EDR removal tools schema | [av-scrub-index/data/schema/uninstaller.schema.json](av-scrub-index/data/schema/uninstaller.schema.json) |
| Prompt engineering: how models read prompts | [prompt-architect/fundamentals/how-llms-read-prompts.md](prompt-architect/fundamentals/how-llms-read-prompts.md) |
| Prompt engineering cheat sheet | [prompt-architect/guides/cheat-sheet.md](prompt-architect/guides/cheat-sheet.md) |

## Same task, different stack — pick by stack first

- **Releasing an Android app:** Kotlin → `kotlin/docs/19-build-signing-release-and-google-play.md` · Godot → `godot/docs/05-google-play.md` · Flutter → `flutter/guides/10-android-release.md`. Play deadlines that apply to all: `kotlin/reference/play-requirements-and-deadlines.md`.
- **Packaging a Windows program:** house system (SeanPak) → `knowledge/docs/08-packaging-seanpak.md` · PortableApps.com format → `portableapps/docs/07-end-to-end-workflow.md`.
- **Choosing a stack:** `knowledge/reference/stack-decision-table.md`, then the domain for that stack.

## Provenance

Merged 2026-11-18 from PafDev, WowDev, KotlinDev, and the knowledge layer of GodotDevTools, joining the Windows desktop base (`knowledge/`, 2026-11-17) and the Flutter pack (`flutter/`, 2026-11-18) already here. Domain content is unchanged apart from a banner in each domain README and merge fields in each domain manifest. The Godot editor addons project followed on 2026-11-18 as `godot/toolbox/` (complete and openable in Godot), and the ai-knowledge-vault resource index as `ai-resources/`. Binary files in the toolbox (demo PNGs and the addon release zips) were uploaded through the GitHub web interface because the batched text push cannot carry binaries; the source repo's generated `.godot/` editor cache and local `reports/` output were not carried over. ForAI and WinDevKit joined on 2026-11-18 (`forai/`, `windevkit/`). With the library complete, the seven copied source repos — PafDev, WowDev, KotlinDev, GodotDevTools, ai-knowledge-vault, ForAI, and WinDevKit — were archived on GitHub on 2026-11-18; this repo is their single live home. Archived repos stay readable and downloadable on GitHub, and can be unarchived at any time. On 2026-11-23 a full audit of every owned repo added the last two resource collections that belonged here — the AV-Scrub-Index dataset (`av-scrub-index/`) and the Prompt Architect library (`prompt-architect/`); their source repos were archived on GitHub on 2026-11-23, joining the seven archived in round 3.

## Godot realistic physics

[Godot physics resources](godot/docs/physics-resources.md) covers all 11 requested references, corrected API guidance and licensed offline source subsets. Addon source presence is not installation or runtime verification.
