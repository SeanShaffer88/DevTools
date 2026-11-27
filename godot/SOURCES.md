# SOURCES.md — where the facts live

Checked 2026-11-17. Godot and Play both move on a yearly cadence;
re-check the starred rows before any release.

| Topic | Authority | Where |
|---|---|---|
| Current version, release policy * | Godot download archive + Release Policy docs page | godotengine.org/download/archive · docs.godotengine.org (about/release_policy) |
| Export prerequisites per version * | "Exporting for Android", versioned per release | docs.godotengine.org → Tutorials → Export |
| Gradle builds, AAB/AAR | "Gradle builds for Android" | docs.godotengine.org → Tutorials → Export |
| Export option names | Class reference: EditorExportPlatformAndroid | docs.godotengine.org → Classes |
| C# platform support * | "C#/.NET" docs section | docs.godotengine.org → Tutorials → Scripting → C# |
| Version control | "Version control systems" (Best practices) | docs.godotengine.org |
| Android plugins | "Godot Android plugins" (Platform → Android) | docs.godotengine.org |
| Play target API * | Play Console Help, target API policy (answer 11926878) | support.google.com/googleplay/android-developer |
| AAB requirement | Play Console Help (answer 2481797) | support.google.com/googleplay/android-developer |
| 16 KB page sizes * | Android Developers guide | developer.android.com/guide/practices/page-sizes |
| Play Billing versions * | Play Billing release notes + deprecation schedule | developer.android.com |
| Billing plugin | godot-sdk-integrations/godot-google-play-billing | github.com/godot-sdk-integrations |
| AdMob plugin | poingstudios/godot-admob-plugin | github.com/poingstudios |
| Renderer choice * | "Overview of renderers" (checked 2026-11-27, 4.7) | docs.godotengine.org → Tutorials → Rendering |
| Play Games plugin * | godot-sdk-integrations/godot-play-game-services (checked 2026-11-27) | github.com/godot-sdk-integrations |
| Plugin org status | godot-sdk-integrations org description: community-maintained, not Foundation-endorsed (checked 2026-11-27) | github.com/godot-sdk-integrations |
| Firebase plugins * | Asset Store listings + repos named in docs/06 (checked 2026-11-27) | store.godotengine.org · github.com |
| GA4 Measurement Protocol | Google Analytics developer docs | developers.google.com/analytics/devguides/collection/protocol/ga4 |
| CI images | abarichello/godot-ci | github.com/abarichello/godot-ci |
| Asset Store | Godot blog + store | godotengine.org · store.godotengine.org |
| Demo projects | godotengine/godot-demo-projects | github.com/godotengine |

## Honestly Unverified (as of 2026-11-17)

- The exact .NET floor for C# Android exports in current Godot —
  the 4.3 docs say .NET 7.0+ (arm64/x64 only); a third-party guide
  claims .NET 9+. The official current C# page keeps the
  "experimental" label without a floor. Check that page for your
  version before printing a number.
- Whether 4.7.2's build template compiles against API 36 by
  default (third-party attested; the docs' SDK list still shows
  the 35 series — the templates appear to run ahead of the docs).
- The exact latest release of the billing plugin (2.0.0 attested
  August 2025; check the repo's releases page).
- Whether `godot-sdk-integrations/godot-admob` exists: an Asset
  Store page links it, but the org's repository list (2026-11-27)
  doesn't show it.
- The Godot 4 Play Games plugin's exact feature list (the 4.x
  README doesn't list features in text).
- Whether analytics SDKs need EEA/UK consent beyond the Data
  Safety form for a given game.
- The official Discord invite string and the godot-ci images'
  exact bundled SDK components.

## Physics reference capture — 2026-11-22

[Physics resources](docs/physics-resources.md) links Godot 4.7 manual / 4.7.2 API snapshots and licensed community subsets. [Central provenance](../development/vendor/SOURCES.json) retains immutable commits, exact byte identities, capture date, licenses and attribution. Kodeco is reference only; the requested Physics Gotchas identity remains unresolved. Third-party addons were not installed or executed.
