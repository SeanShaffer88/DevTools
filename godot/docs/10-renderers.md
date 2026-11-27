# 10 — Choosing a renderer for Android

Checked 2026-11-27 against the Godot **4.7** docs page "Overview of
renderers" (docs.godotengine.org → Tutorials → Rendering). Re-check
that page for the engine version you pin (AGENTS.md rule 2).

## The three renderers

| | Compatibility | Mobile | Forward+ |
|---|---|---|---|
| Driver | OpenGL | Vulkan, Direct3D 12 or Metal (RenderingDevice) | Vulkan, Direct3D 12 or Metal (RenderingDevice) |
| On mobile | Yes — low-end | Yes — high-end; **the mobile default** | Supported but poorly optimized; don't use |
| Runs without Vulkan | Yes | No | No |
| Old / low-end hardware | Fastest | Runs, slower than Compatibility | Slowest |
| Cost profile | Low base, high scaling | Medium base, medium scaling | High base, low scaling |
| Feature set | 2D + core 3D | Most features, limited by mobile hardware | All features |

Docs' starting rule: **Mobile** for newer mobile devices and 3D
with advanced features; **Compatibility** for older devices, for
the widest hardware range, for 2D, or when you want the best
performance and don't need advanced features. Every game is
different — measure on your minimum-spec device.

## Feature differences that matter on Android

Only in Mobile and Forward+ (not Compatibility): FXAA, SMAA, 2D
MSAA, screen-space roughness limiter, debanding, decals, **particle
trails**, particle SDF collision, depth-of-field blur, variable rate
shading, 2D HDR viewport, HDR output, CompositorEffects, compute
shaders (Mobile: with a performance penalty on older devices),
light projector textures, PCSS for omni/spot lights.

Only in Compatibility (not Mobile): **SSAO**.

In all three: **glow**, fog (depth and height), tonemapping,
adjustments, fullscreen-quad post-processing, 3D MSAA, SSAA,
screen and depth textures, ReflectionProbe (Compatibility 2 per
mesh, Mobile 8 per mesh).

Not on mobile renderers at all (Forward+ only): volumetric fog,
SSR, SSIL, SDFGI, VoxelGI, TAA, FSR2, sub-surface scattering.

Lights: Mobile allows 8 omni/spot lights per mesh and 256 per
view; Compatibility 8 per mesh (raisable), and lights with shadows
use extra passes with less accurate blending.

Color precision: Mobile renders RGB10A2 (RGBA16F with HDR 2D on);
Compatibility RGBA8. Bright, saturated neon looks can band or clip
differently between the two — compare on device.

## Fallback behavior

- Since Godot 4.4, Mobile/Forward+ fall back Vulkan ↔ Direct3D 12,
  and if RenderingDevice isn't supported at all the engine falls
  back to **Compatibility** so the game still runs — possibly
  looking different. Turn this off with *Rendering → Rendering
  Device → Fallback to OpenGL 3* if you'd rather fail than look
  wrong.
- Switching renderers can need scene, lighting and environment
  tweaks; Mobile ↔ Forward+ needs fewer than either ↔
  Compatibility. Decide early (pre-production) rather than late.

## Practical guidance for this family

- 3D mobile game with glow/particle-trail effects → start on
  **Mobile**, and keep a Compatibility test build so the fallback
  path is never a surprise.
- 2D game, or a 3D game that must run on old/cheap phones →
  **Compatibility**.
- Budget numbers (draw calls, particle counts) are project
  decisions, not engine facts — prove them on the min-spec device.
