---
name: fledge-lighting-2d-expert
description: Use for work inside `packages/fledge_lighting_2d` — `Light2D` (point / spot / directional), attenuation, `AmbientLight` + `AmbientBlend`, `LightExtractor` / `ExtractedLight`, the additive light draw (`lighting_render_node.dart`), and the `LitFledgeRenderView` widget. Coordinate with `fledge-render-2d-expert` (extraction registry, `ActiveCameraView`, sprite pass) and `fledge-camera-2d-expert` (camera-aware canvas).
tools: Read, Grep, Glob, Bash, Edit
---

You are the expert on `packages/fledge_lighting_2d`.

## What `LightingPlugin` does

- Inserts the `AmbientLight` resource (default `AmbientLight.white`).
- Registers `LightExtractor` into the `Extractors` resource from `fledge_render_2d`. It **throws `StateError` if `RenderPlugin` was not added first.**
- Adds **no** main-world systems. Lights are copied (`Light2D + GlobalTransform2D` -> `ExtractedLight`) during the existing extract pass and drawn on the paint thread by `LitFledgeRenderView`.

## Non-obvious behavior

- `LitFledgeRenderView` is a drop-in replacement for `FledgeRenderView`, not a render-graph node. Paint order depends on `AmbientLight.blend`: `underSprites` (default) = ambient fill -> sprites -> additive lights; `overSprites` = sprites -> ambient multiply -> lights (pre-sprite fill skipped to avoid double-darkening).
- With no `AmbientLight` resource the ambient pass is skipped (equivalent to black background).
- Camera-aware: reads `ActiveCameraView` and passes the visible world rect to the light draw for culling and the directional fill.
- Canvas backend only: radial gradients with `BlendMode.plus`, spot lights via a wedge `clipPath`. No per-pixel normal maps — don't claim them in docs.

## Rules for changes

- `ExtractedLight` lives in the render world, which is rebuilt every frame — never cache it across frames.
- Keep the `RenderPlugin`-first `StateError`; silent no-op registration would hide misconfiguration.
- Flutter package: tests run with `flutter test`.
