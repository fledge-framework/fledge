# Lighting (2D)

The `fledge_lighting_2d` package adds dynamic 2D lighting to Fledge — point, directional, and spot lights, plus scene-wide ambient illumination. The backend is a pragmatic Canvas pass: ambient fills the viewport, then sprites draw, then each extracted light adds an additive radial gradient (or a full-screen tint for directional lights).

## Installation

```yaml
dependencies:
  fledge_lighting_2d: ^0.1.0
```

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_lighting_2d/fledge_lighting_2d.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  final app = App()
    ..addPlugin(WallTimePlugin())
    ..addPlugin(RenderPlugin())
    ..addPlugin(const LightingPlugin(ambient: AmbientLight.dark));

  // A torch on the player.
  app.world.spawn()
    ..insert(Transform2D.from(200, 200))
    ..insert(GlobalTransform2D.identity())
    ..insert(Light2D.point(
      color: const Color(0xFFFFDD88),
      radius: 180,
      innerRadius: 40,
    ));

  // A spotlight from a lamppost.
  app.world.spawn()
    ..insert(Transform2D.from(600, 100))
    ..insert(GlobalTransform2D.identity())
    ..insert(Light2D.spot(
      color: const Color(0xFFFFFFFF),
      direction: Vector2(0, 1),
      angle: 0.4,   // cone half-angle in radians
      radius: 240,
    ));

  runApp(LitFledgeRenderView(app: app));
}
```

## Core concepts

### AmbientLight

Scene-wide base illumination — inserted as an ECS resource by `LightingPlugin` and consumed by `LitFledgeRenderView` as the fill layer under the sprite pass.

```dart
const AmbientLight.white           // white × 0.5, neutral half-lit
const AmbientLight.dark            // black × 0.2, torches-only feel
AmbientLight(color: Color(0xFF204060), intensity: 0.35)  // custom
```

`intensity` multiplies the color's alpha before the ambient rect is filled. `0` disables ambient entirely (fully dark scene, lights only); `1` uses the color at its literal alpha.

### Light2D

A dynamic 2D light source. Attach to any entity with `Transform2D` + `GlobalTransform2D`, and `LightExtractor` will emit an `ExtractedLight` into the render world each frame.

Three light types:

| Type | Behaviour |
|------|-----------|
| `LightType.point` | Omnidirectional — falls off with distance from the entity. |
| `LightType.directional` | Parallel rays — treated as an infinite tint across the whole viewport in the Canvas backend. |
| `LightType.spot` | Cone-shaped — falls off with distance and is clipped to a wedge around `direction`. |

Prefer the factory constructors:

```dart
Light2D.point(
  color: const Color(0xFFFFDD88),
  radius: 180,
  innerRadius: 40,       // full intensity inside this radius
)

Light2D.directional(
  color: const Color(0xFF88AAFF),
  intensity: 0.4,
  direction: Vector2(0.3, 1.0),  // normalised by factory
)

Light2D.spot(
  color: const Color(0xFFFFFFFF),
  direction: Vector2(0, 1),
  angle: 0.4,            // cone half-angle in radians
  radius: 240,
)
```

### Falloff

Distance-based falloff is linear between `innerRadius` and `radius`. Pixels inside `innerRadius` are at full intensity; pixels at or past `radius` are dark. Setting `innerRadius == 0` produces a smooth center falloff; approaching `radius` produces a nearly-hard-edged disc.

The `linearAttenuation` function is exported so custom lighting code (or tests) can share the same falloff curve as the extractor.

## LitFledgeRenderView

`LitFledgeRenderView` is a drop-in replacement for `FledgeRenderView`. It paints, in a single `CustomPaint`:

1. **Ambient** — full-screen rect in `AmbientLight.color × intensity`.
2. **Sprites** — the same `renderSpritesToDrawer` path used by `FledgeRenderView`.
3. **Lights** — one additive radial gradient per extracted point/spot light, plus a full-screen additive tint per directional light.

Steps 1 and 3 use `BlendMode.plus`, so light stacks the way you expect: two overlapping torches feel twice as bright.

## Design notes

### Why a widget, not a render node

The Phase 3 `FledgeRenderView` draws sprites directly (it does not walk `RenderGraph`). Threading a `LightingRenderNode` into a graph that nothing else uses would add plumbing without buying anything. `LitFledgeRenderView` inherits the sprite path verbatim and adds two extra passes around it. When the render graph becomes the default entry point in a later phase, a `LightingRenderNode` slots in cleanly next to `SpriteRenderNode` without churn on the widget API.

### Material.normalMap

`SpriteMaterial` grew a `Handle<Texture>? normalMap` slot in this phase. **The Canvas backend ignores it.** Per-pixel normal-mapped lighting needs a `FragmentProgram`, which is future work. The field ships now so game code can set up its data pipelines without a breaking material API change later.

### Future work

- **SDF shadow tracing** — occluder rasterization + a fragment shader that samples the SDF from a light's origin. Requires a shadow-caster component and a real GPU pass. `Light2D.castsShadow` is reserved for this and has no effect today.
- **Cookies** — per-light mask textures (window-shape lights, projected patterns).
- **Per-pixel normal maps** — read `SpriteMaterial.normalMap` in a fragment shader.
- **Culling** — pre-cull lights against the active camera viewport before extraction. Today all lights are extracted every frame.

## Components reference

| Component | Description |
|-----------|-------------|
| `Light2D` | Point / directional / spot light attached to a world entity. |

## Resources reference

| Resource | Description |
|----------|-------------|
| `AmbientLight` | Scene-wide fill. Set at plugin construction; adjustable at runtime. |

## Systems reference

`LightingPlugin` runs no per-tick main-world systems. `LightExtractor` walks `Light2D + GlobalTransform2D` at extraction time (`Schedules.last`, alongside every other extractor) and emits `ExtractedLight` on the render world. The actual light draw happens inside `LitFledgeRenderView` on the paint thread.

## See also

- [2D Rendering](/docs/plugins/render) — `FledgeRenderView`, `SpriteMaterial`.
- [Particles](/docs/plugins/particles) — pair with ambient-dark scenes for glowing effects.
- [Plugins Overview](/docs/plugins/overview)
