# 06 — Android plugins

## The v2 plugin system (current since Godot 4.2)

- A v2 plugin is an Android library built against the Godot
  Android library; its init class extends `GodotPlugin`, its
  manifest entries use the `org.godotengine.plugin.v2` prefix,
  and it is packaged through an EditorExportPlugin into the
  project's `addons/` — **not** as a `.gdap` file. The `.gdap` +
  `res://android/plugins` flow in Godot 3 / 4.0–4.1 docs is
  **deprecated**; v1 plugins are legacy.
- Building or bundling a plugin requires a **Gradle build**
  (docs/03). Plugins are enabled per export preset.
- Official starting points: `m4gr3d/Godot-Android-Plugin-Template`
  and the GDExtension-Android-Plugin-Template on GitHub.
- Before writing a plugin for simple Java interop, check the
  built-ins: Godot 4.4 added the `JavaClassWrapper` singleton and
  a bundled `AndroidRuntime` plugin, which cover many cases that
  used to need a custom plugin.

## Play Billing — GodotGooglePlayBilling

- `GodotGooglePlayBilling` used to live in the godotengine org; its
  repo **moved** to
  **godot-sdk-integrations/godot-google-play-billing**. That org
  describes itself as hosting *community-maintained* SDK
  integrations that the Godot Foundation **does not maintain or
  endorse** (org description, checked 2026-11-27) — so treat it as
  the canonical community plugin, not as engine-supported code.
- Versioning: **1.x releases are for Godot 3; 2.0.0 and later are
  for Godot 4.** (Release 2.0.0 is the latest attested, Aug 2025 —
  check the releases page; see SOURCES.md.) The current build
  bundles **billing-ktx 8.0.0**, which satisfies Play's PBL 8+
  requirement (docs/05); it packages v2-style into
  `addons/GodotGooglePlayBilling/`.
- Purchases must be acknowledged or Google refunds them (the docs
  have said so since the Godot 3 era).
- Ignore the legacy Asset Library listing claiming a "Godot
  Google Play Billing 3.2.0" — its versioning matches nothing in
  the godot-sdk-integrations releases; provenance unverified. Get
  the plugin from the godot-sdk-integrations releases.

## AdMob — Poing Studios, in its new home

- The maintained AdMob plugin is **Poing Studios'**, now in the
  monorepo **poingstudios/godot-admob-plugin** (docs at
  poingstudios.github.io/godot-admob-plugin). The old per-platform
  repos (`godot-admob-android`, `godot-admob-ios`) are **archived**
  — anything pointing at them is stale.
- Current line is **v5.x** (v5.1.0, Sep 2026, per the Asset Store
  changelog), supporting Godot 4.2+. v5 moved to the Google Mobile
  Ads Next-Gen SDK, dropped `config.gd` (configuration now lives
  in Project Settings under `admob/`), removed Smart Banners, and
  fetches its native binaries through the editor's AdMob Manager.
- **Unresolved:** a Godot Asset Store page (godot-mobile-plugins'
  Firebase listing, May 2026) links an AdMob plugin at
  `godot-sdk-integrations/godot-admob`, but that org's repository
  list on 2026-11-27 shows no such repo. Until it appears there,
  Poing Studios' plugin is the one to use.

## Play Games Services — GodotPlayGameServices

Checked 2026-11-27 against the repo README and its org listing.

- The maintained plugin is
  **godot-sdk-integrations/godot-play-game-services** (MIT,
  maintainer Jacob Ibáñez Sánchez / `Iakobs`; moved into the org in
  October 2024). Same org caveat as billing above: community
  maintained, not Foundation-endorsed.
- It wraps the **Play Games Services v2** SDK (README badge:
  21.0.0) and installs v2-style into
  `addons/GodotPlayGameServices/` (download from the Godot Asset
  Store or the GitHub releases; latest release **v3.4.0, Jul 20,
  2026**). README says Godot **4.3+**; older 4.x lines use the
  branch selector. Activity is current — a Nov 21, 2026 commit
  fixed export errors on Godot 4.8.
- Since v3.0 the features are **Nodes** you add to scenes, not
  autoloads; only the main `GodotPlayGamesServices` singleton stays,
  and it needs **manual initialization**. Sign-in is no longer
  checked automatically — call it yourself.
- Features: the Godot 3 line's README lists sign-in, players,
  achievements, leaderboards, events, and **snapshots** (Play
  Games' Saved Games, i.e. cloud save). The Godot 4 README doesn't
  list them in text — check the plugin's nodes in the editor's
  Create New Node dialog before relying on one.
- Setup that trips people up:
  - Needs a **Gradle build** (docs/03).
  - The **Game ID** goes in the Android export preset under
    `godot_play_game_services/game_id`; don't change it later.
  - Create an **Android OAuth client** for *every* signing
    certificate you use: debug keystore, release keystore, **and
    the Play App Signing certificate** (SHA-1 from Play Console →
    Release → Setup → App signing). The last one is the one most
    often missed; without it, sign-in fails only in Play-installed
    builds.
  - adb log `APP NOT CORRECTLY CONFIGURED TO USE GOOGLE PLAY GAME
    SERVICES … DEVELOPER_ERROR` = package name / SHA-1 / Game ID
    mismatch, or an unpublished game tested with a non-tester
    account.
  - Silent sign-in failure with `ClassNotFoundException …
    games.internal.v2.resolution.zza` in adb = the Google Cloud
    OAuth consent screen is *Internal*; set it to *External →
    Testing* and add test users.
- **Ignore** `Iakobs/godot-google-play-game-services-android-plugin`
  and its `.gdap` files — that is the Godot 3.5/3.6 line (last
  release Oct 2024).

## Firebase and analytics — no maintained all-in-one plugin

Checked 2026-11-27. There is **no** maintained, org-hosted
Firebase plugin for Godot that covers **Analytics** or **Remote
Config**. What exists:

| Plugin | Covers | Status |
|---|---|---|
| `syntaxerror247/GodotFirebaseAndroid` (Asset Store "Godot Firebase Android", Godot 4.2+) | Auth (email, Google), Firestore, Realtime Database, Storage | v1.0, May 2025. **No Analytics, no Remote Config.** |
| `godot-mobile-plugins/godot-firebase` (Asset Store "Firebase Plugin", Android + iOS) | Auth (email, Google, anonymous), Firestore | v1.0, May 2026. **No Analytics, no Remote Config.** |
| `FeatureKillersGames/FirebaseAnalyticsGodotAndroidPlugin` (Godot 4.2+) | Analytics events + user properties | **Archived May 7, 2026** — read-only; don't build on it. |
| `DrMoriarty/godot-firebase-remoteconfig` | Remote Config | Old NativeLib-era plugin; not a v2 plugin. Treat as stale. |

What that means for a project that needs analytics or remote
config:

- **Write a thin v2 plugin** from `m4gr3d/Godot-Android-Plugin-Template`
  that wraps only the Firebase calls you use (log event, set user
  property, fetch/activate config). This is the most reliable
  route but you own the maintenance.
- **Fork the archived analytics plugin** (MIT) as a starting point
  — same ownership cost, less code to write.
- The GA4 **Measurement Protocol** (plain HTTPS, so it works from
  GDScript's `HTTPRequest`) is **not a substitute**: Google says it
  *augments* events from gtag / Tag Manager / Firebase, that sending
  only Measurement Protocol events gives partial reporting, and some
  event names are reserved for automatic collection.
- Any analytics SDK has to be declared in the Play **Data Safety**
  form. Whether it also needs user consent (EEA/UK) depends on what
  it collects; check before launch rather than assuming the ad
  consent flow covers it (Unverified here).

> Reminder for this family: games ship free with **no ads**
> (AGENTS.md rule 9). AdMob is documented here because "which
> plugin is real and current" is exactly the kind of question this
> repo exists to answer — not as a recommendation to add it.
