# Lighting

`fledge_lighting_2d` adds dynamic 2D lights: point, directional and spot
lights plus scene-wide ambient light. `LightingPlugin` draws them as a
[view pass](/docs/rendering/sprites-animation#view-passes) inside every
`FledgeRenderView` of the app, through the same camera path as the sprites, so
no special widget is needed.

```yaml
dependencies:
  fledge_render_2d: ^0.6.0
  fledge_lighting_2d: ^0.6.0
```

Flutter 3.50+ (Dart 3.14+); desktop first, web and mobile best-effort. Add
`RenderPlugin` first: `LightingPlugin` throws a `StateError` if it can't find
the `Extractors` registry. Lights need a `GlobalTransform2D`, so run
`TransformPropagateSystem` as usual.

<!-- snippet-setup
import 'package:vector_math/vector_math.dart';

late World world;
late App app;
late Entity lamp;
-->

## Quick start

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
        // A blue night: sprites dim and blue, except where a light
        // reaches.
        ambient: AmbientLight(
          color: Color(0xFF101C4C),
          intensity: 0.8,
          blend: AmbientBlend.lightMap,
        ),
      ),
    )
    ..addSystem(TransformPropagateSystem(), schedule: Schedules.preUpdate);
  app.world.getResource<Extractors>()!.register(SpriteExtractor());

  // A street lamp: a pool of warm light on the ground.
  app.world.spawn()
    ..insert(Transform2D.from(200, 200))
    ..insert(GlobalTransform2D())
    ..insert(Light2D.point(
      color: const Color(0xFFFFD49A),
      radius: 120,
      innerRadius: 18,
      aspect: 0.74, // an ellipse, as the ground looks top-down
    ));

  // Every FledgeRenderView of the app is lit.
  runApp(FledgeRenderView(app: app));
}
```

(A real game drives `app.tick()` from a widget; see
[Driving the app from a widget](/docs/rendering/overview#driving-the-app-from-a-widget).)

## Ambient light

`AmbientLight` is a resource that `LightingPlugin` inserts (its `ambient`
argument, default `AmbientLight.white`). It's immutable: insert a new one to
change the time of day.

```dart
app.insertResource(const AmbientLight(
  color: Color(0xFF203060),
  intensity: 0.6,
  blend: AmbientBlend.lightMap,
));
```

`blend` picks the lighting model:

| `blend` | What it does |
|---|---|
| `AmbientBlend.lightMap` | **Recommended.** The ambient colour and every light are added into a light map, and the sprites are multiplied by it. A pixel ends up as its sprite colour × (ambient + the lights reaching it), so a lamp at night shows the ground in its true colours, and nothing gets brighter than it's drawn. `intensity` blends the map's base from white (`0`, full daylight) to `color` (`1`). Lights' `glow` halos are added on top. |
| `AmbientBlend.overSprites` | Multiplies the sprites by `lerp(white, color, intensity)`, then *adds* the lights over the result, so lights paint a glow rather than reveal what's under them. |
| `AmbientBlend.underSprites` | The default, kept for compatibility: an ambient fill (`color` at `intensity` × its alpha) under the sprites, lights added on top. Sprites always draw at full brightness. |

`AmbientLight.white` is white at 0.5 intensity, `underSprites`.
`AmbientLight.dark` is black at 0.2 intensity, `underSprites`. For a dark
scene lit by lamps, use `lightMap` with a dark colour and a high intensity.

`bounds` limits the ambient to a world-space rect, for when the camera can
see past a map's edge (outside it, `lightMap` leaves full light).

## Light2D

A `Light2D` on an entity with `Transform2D` + `GlobalTransform2D` lights the
scene around the entity's position. `LightExtractor` copies every light into
the render world each frame.

```dart
final point = Light2D.point(
  color: const Color(0xFFFFDD88),
  radius: 180,
  innerRadius: 40, // full strength inside this radius
  bands: 0,        // 0 = smooth falloff; n = n flat rings (pixel art)
  aspect: 0.75,    // height / width of the pool
  glow: 0.5,       // additive halo over the lit scene (lightMap only)
);

final moonlight = Light2D.directional(
  color: const Color(0xFF88AAFF),
  intensity: 0.4,
  direction: Vector2(0.3, 1.0), // normalised for you
);

final flashlight = Light2D.spot(
  color: const Color(0xFFFFFFFF),
  direction: Vector2(0, 1),
  angle: 0.4, // cone half-angle, radians
  radius: 240,
);
```

| Type | Behaviour |
|---|---|
| `LightType.point` | All directions; falls off with distance. |
| `LightType.directional` | An even tint over the whole view (its `direction` isn't used for shading). |
| `LightType.spot` | Like a point light, clipped to a wedge of `direction ± angle`. |

`color`, `intensity`, `radius`, `innerRadius`, `bands`, `aspect` and `glow`
are mutable, so a flame can flicker or a street lamp fade in at dusk:

```dart
world.get<Light2D>(lamp)!.intensity = 0.6;
```

`type`, `angle` and `direction` are final; replace the component to change
them. `castsShadow` is reserved and has no effect: there are no shadows.

### Falloff

Inside `innerRadius` a light is at full strength. Past it, it fades as light
does: quickly near the source, then a long soft tail that reaches nothing at
`radius`, with no visible edge (`(1 − u²)²` of the distance `u` between the
two radii). With `bands > 0` the same curve is stepped into that many flat
rings. `falloffStops` builds the gradient. Each light is drawn as its circle
or ellipse, so nothing past its edge is touched. `linearAttenuation(distance,
innerRadius, radius)` is a plain linear curve for gameplay code ("is the
player in the light?").

## Emissive sprites

`Sprite(emissive: true)` draws after the lighting, at full brightness
whatever the ambient: lit windows at night, screens, signs.

## How it draws

`LightingPlugin` inserts the ambient, registers `LightExtractor`, and adds a
`LightingViewPass` to the app's `ViewPasses`. It adds no per-tick systems.
Every `FledgeRenderView` then draws, in world space:

1. the ambient fill, in `underSprites` mode (`paintBehind`);
2. the ordinary sprites;
3. the lighting, in the ambient's `blend` mode (`paintOver`):
   `renderLightMap` and `renderLightGlows` for the light map,
   `renderLightsToCanvas` for the additive modes;
4. the emissive sprites.

The lighting covers the visible world plus `LightingViewPass.margin` (4 world
units), so the edge pixels of a sub-pixel-scrolling camera are covered too.
Lights entirely outside the view are skipped when drawing, but every light is
extracted every frame. The `render*` functions are public, for drawing
lighting into a canvas of your own.

`LitFledgeRenderView` is deprecated: it's a plain `FledgeRenderView` now.

## Limitations

- No shadows (`castsShadow` does nothing).
- No normal maps: `SpriteMaterial.normalMap` is ignored by the canvas backend
  (materials aren't used by the built-in drawer at all; see
  [Render Graph](/docs/rendering/render-graph#materials)).
- No light cookies (shaped masks).
- Particles can't be emissive, so the light map darkens them too.

See the [API reference](https://pub.dev/documentation/fledge_lighting_2d/latest/)
for every member.
