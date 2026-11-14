# Lighting (2D)

The `fledge_lighting_2d` package adds dynamic 2D lighting to Fledge: point, directional and spot lights, plus scene-wide ambient light. `LightingPlugin` draws it as a view pass inside every `FledgeRenderView` of the app, through the same camera path as the sprites, so no special widget is needed.

The recommended model is the **light map** (`AmbientBlend.lightMap`), the usual one in 2D games: the ambient colour and every light are added into one layer, and the sprites are multiplied by it. A pixel ends up as its sprite colour × (ambient + the lights reaching it), so a lamp at night shows the ground in its true colours around it, and nothing gets brighter than it's drawn. Sprites marked `emissive` draw after the light map at full brightness (lit windows, screens, signs).

## Installation

```yaml
dependencies:
  fledge_lighting_2d: ^0.5.0
```

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_lighting_2d/fledge_lighting_2d.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final app = App()
    ..addPlugin(RenderPlugin()) // first: it holds the view passes
    ..addPlugin(
      const LightingPlugin(
        // A blue night: sprites at about a third of their brightness,
        // except where a light reaches.
        ambient: AmbientLight(
          color: Color(0xFF101C4C),
          intensity: 0.8,
          blend: AmbientBlend.lightMap,
        ),
      ),
    );

  // A street lamp: a pool of warm light on the ground.
  app.world.spawn()
    ..insert(Transform2D.from(200, 200))
    ..insert(GlobalTransform2D.identity())
    ..insert(Light2D.point(
      color: const Color(0xFFFFD49A),
      radius: 120,
      innerRadius: 18,
      aspect: 0.74,  // an ellipse, as the ground looks top-down
    ));

  runApp(FledgeRenderView(app: app));
}
```

## Core concepts

### AmbientLight

Scene-wide base light, a resource inserted by `LightingPlugin`. Replace it at runtime to change the time of day.

| `blend` | What it does |
|---|---|
| `AmbientBlend.lightMap` | **Recommended.** Ambient and lights add into a light map that multiplies the sprites. `intensity` blends the map's base from white (`0`, full daylight) to `color` (`1`). Lights' `glow` halos are added on top. |
| `AmbientBlend.overSprites` | Multiplies the sprites by the ambient, then *adds* the lights over the result: lights paint a glow rather than reveal what's under them. |
| `AmbientBlend.underSprites` | The default, for compatibility: an ambient fill under the sprites, lights added on top. Sprites always draw at full brightness. |

`bounds` limits the ambient to a world-space rect (useful when the camera can see past a map's edge).

### Light2D

A dynamic 2D light source. Attach it to any entity with `Transform2D` + `GlobalTransform2D`, and `LightExtractor` emits an `ExtractedLight` into the render world each frame. `color`, `intensity`, `radius`, `innerRadius`, `bands`, `aspect` and `glow` are mutable: fade a lamp in at dusk by changing its `intensity`.

| Type | Behaviour |
|------|-----------|
| `LightType.point` | Omnidirectional; falls off with distance from the entity. |
| `LightType.directional` | Parallel rays; an even tint across the whole viewport in the Canvas backend. |
| `LightType.spot` | Cone-shaped; falls off with distance and is clipped to a wedge around `direction`. |

```dart
Light2D.point(
  color: const Color(0xFFFFDD88),
  radius: 180,
  innerRadius: 40, // full intensity inside this radius
  bands: 0,        // 0 = smooth falloff; n = n flat rings
  aspect: 0.75,    // height / width of the pool
  glow: 0.5,       // additive halo over the lit scene (lightMap only)
)

Light2D.directional(
  color: const Color(0xFF88AAFF),
  intensity: 0.4,
  direction: Vector2(0.3, 1.0), // normalised by the factory
)

Light2D.spot(
  color: const Color(0xFFFFFFFF),
  direction: Vector2(0, 1),
  angle: 0.4, // cone half-angle in radians
  radius: 240,
)
```

### Falloff

Inside `innerRadius` a light is at full strength. Past it, light fades as light does: quickly near the source, then a long soft tail that reaches nothing at `radius`, with no visible edge (the curve is `(1 - u²)²` of the distance `u` between the two radii). With `bands > 0` the same curve is stepped into that many flat rings, for a pixel-art look. `falloffStops` builds the gradient. Every light is drawn as its circle (or ellipse), so nothing past its edge is ever touched. `linearAttenuation` is a plain linear curve for custom code and tests.

### Emissive sprites

`Sprite(emissive: true)` draws after the lighting at full brightness, whatever the ambient: lit windows at night, screens, meteors. See [View passes](/docs/plugins/render#view-passes).

## How it draws

`LightingPlugin` adds a `LightingViewPass` to the app's `ViewPasses` (inserted by `RenderPlugin`, so add `RenderPlugin` first). Every `FledgeRenderView` then draws, in world space through the active camera:

1. the ordinary sprites;
2. the lighting, in the ambient's `blend` mode (`renderLightMap` and `renderLightGlows` for the light map; `renderLightsToCanvas` for the additive modes);
3. the emissive sprites.

`LitFledgeRenderView` is deprecated: it's a plain `FledgeRenderView` now.

### Material.normalMap

`SpriteMaterial` has a `Handle<Texture>? normalMap` slot. **The Canvas backend ignores it.** Per-pixel normal-mapped lighting needs a `FragmentProgram`, which is future work.

### Future work

- **SDF shadow tracing**: occluder rasterization plus a fragment shader sampling the SDF from a light's origin. `Light2D.castsShadow` is reserved for this and has no effect today.
- **Cookies**: per-light mask textures (window-shaped lights, projected patterns).
- **Per-pixel normal maps**: read `SpriteMaterial.normalMap` in a fragment shader.
- **Culling**: lights are culled against the visible world when drawn, but all are extracted every frame.

## Components reference

| Component | Description |
|-----------|-------------|
| `Light2D` | Point / directional / spot light attached to a world entity. |

## Resources reference

| Resource | Description |
|----------|-------------|
| `AmbientLight` | Scene-wide base light and blend mode. Set at plugin construction; replace it at runtime. |

## Systems reference

`LightingPlugin` runs no per-tick main-world systems. `LightExtractor` walks `Light2D + GlobalTransform2D` at extraction time and emits `ExtractedLight` on the render world; `LightingViewPass` draws them on the paint thread.

## See also

- [2D Rendering](/docs/plugins/render): `FledgeRenderView`, view passes, `SpriteMaterial`.
- [Particles](/docs/plugins/particles): pair with dark scenes for glowing effects.
- [Plugins Overview](/docs/plugins/overview)
