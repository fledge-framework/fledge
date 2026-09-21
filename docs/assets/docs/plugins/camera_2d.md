# Camera (2D)

The `fledge_camera_2d` package provides 2D cameras, cinematics, and viewport helpers for Fledge games — smooth follow, trauma-based screen shake, letterbox / pillarbox, parallax scrolling, orthographic / isometric / oblique projections, and fade / wipe transitions.

Extracted from `fledge_render_2d` in Phase 6 of the framework restructure, `fledge_camera_2d` depends on `fledge_render_2d` (for `CameraView` and `Viewport`, which flow through the render graph slot). The reverse dependency does not exist — the render pipeline knows nothing about camera components.

## Installation

```yaml
dependencies:
  fledge_camera_2d: ^0.1.0
```

## Quick Start

```dart
import 'package:fledge_camera_2d/fledge_camera_2d.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';

final app = App()
  ..addPlugin(WallTimePlugin())
  ..addPlugin(RenderPlugin())
  ..addPlugin(const CameraPlugin());

// Spawn a camera that follows the player with a subtle shake on hit.
app.world.spawn()
  ..insert(Transform2D.from(0, 0))
  ..insert(GlobalTransform2D.identity())
  ..insert(Camera2D(projection: OrthographicProjection(viewportHeight: 240)))
  ..insert(CameraFollow(target: playerEntity, smoothing: 0.15))
  ..insert(CameraShake());
```

## CameraPlugin

`CameraPlugin` wires four systems into `Schedules.postUpdate` with explicit ordering:

1. `CameraFollowSystem` — sets the base camera position from the follow target.
2. `CameraShakeSystem` — decays trauma and adds the shake delta.
3. `ParallaxSystem` — reads the final camera position and adjusts parallax entities.
4. `CameraTransitionSystem` — advances fade / wipe overlays.

It also inserts a `ViewportSize` resource (defaults to 1280×720) unless one is already registered.

## Camera2D

The base component — mark an entity as a camera:

```dart
world.spawn()
  ..insert(Transform2D.from(0, 0))
  ..insert(GlobalTransform2D.identity())
  ..insert(Camera2D(
    projection: OrthographicProjection(viewportHeight: 20),
    pixelPerfect: true,
  ));
```

`Camera2D` carries the projection, an optional viewport (for split-screen), and pixel-perfect flags. Rendering pulls the world-space position from `GlobalTransform2D`; game code writes to `Transform2D`.

## Projections

Three built-in projections implement the shared `Projection` interface:

### OrthographicProjection

Flat 2D projection — the default for top-down and side-scrollers.

```dart
OrthographicProjection(
  viewportHeight: 20,           // world units visible vertically
  scalingMode: ScalingMode.fixedHeight,
  near: -100,
  far: 100,
)
```

`ScalingMode` values: `fixedHeight` (default), `fixedWidth`, `fixedVertical`, `none`.

### IsometricProjection

2:1 isometric skew for iso games — screen X and Y are combinations of world X and Y so that tiles form diamonds.

```dart
IsometricProjection(viewportHeight: 200)
```

### ObliqueProjection

Parametric skew for oblique games — like isometric, but you choose the angle. Useful for "2.5D" city-builders.

```dart
ObliqueProjection(viewportHeight: 200, angle: math.pi / 6)
```

## Follow

`CameraFollow` smoothly lerps the camera's `Transform2D.translation` toward another entity each frame:

```dart
world.get<CameraFollow>(cameraEntity)!.smoothing = 0.15;  // damped follow
world.get<CameraFollow>(cameraEntity)!.smoothing = 1.0;   // instant snap
world.get<CameraFollow>(cameraEntity)!.offset = const Offset(0, -20);
```

The system uses the target's `GlobalTransform2D`, so it works with parented targets. When the target entity is despawned, `CameraFollowSystem` logs a warning once and stops updating that camera.

## Shake

`CameraShake` implements Kasper Kamperman's trauma model: a scalar `trauma` in `[0, 1]` decays each frame, and shake magnitude scales as `trauma²`. Bump it from game code:

```dart
world.get<CameraShake>(cameraEntity)!.addTrauma(0.5);  // small hit
world.get<CameraShake>(cameraEntity)!.addTrauma(1.0);  // explosion
```

The `trauma²` scaling makes small hits feel light while big hits feel violent. Tune via `maxOffsetX`, `maxOffsetY`, `maxRotationRadians`, and `traumaDecayPerSec`.

## Parallax

`Parallax(factor)` scrolls entities at a different rate than the camera. `factor` is a scalar in `[0, 1]`:

- `1.0` — moves 1:1 with the world (default, no parallax).
- `0.5` — mid-ground; scrolls at half the camera speed.
- `0.0` — infinitely far; never moves relative to the viewport.

```dart
// Distant mountain layer.
world.spawn()
  ..insert(Transform2D.from(0, 100))
  ..insert(GlobalTransform2D.identity())
  ..insert(Sprite(texture: mountainsTexture, layer: DrawLayer.background))
  ..insert(const Parallax(0.2));
```

`ParallaxSystem` rewrites the `GlobalTransform2D` of parallax entities after `CameraShakeSystem` has run, so parallax reads the final composited camera position. Only root parallax entities (no parent) are supported.

## Letterbox / pillarbox

`OrthographicProjection` has built-in target-aspect support. Set `LetterboxConfig` to render the game at a fixed aspect ratio regardless of window size, with black bars on the letterboxed edges:

```dart
final projection = OrthographicProjection(
  viewportHeight: 240,
  letterbox: LetterboxConfig(targetAspect: 16 / 9),
);
```

Use `computeLetterbox(config, screenSize)` and `computeGutter(config, screenSize)` from `fledge_camera_2d` to draw the black gutter rects on top of the game.

## Transitions

`CameraFadeTransition` and `CameraWipeTransition` are components you attach to a camera to fade / wipe the whole viewport:

```dart
world.entity(cameraEntity).insert(CameraFadeTransition(
  duration: 0.5,
  color: const Color(0xFF000000),
));

// Or wipe left-to-right:
world.entity(cameraEntity).insert(CameraWipeTransition(
  duration: 0.4,
  direction: WipeDirection.leftToRight,
));
```

`CameraTransitionSystem` advances `elapsed` each frame. Widget code reads `progress` (or `effectiveProgress` with `reverse` applied) to draw the overlay. Set `reverse = true` to play the transition out instead of in.

Naming note: the components are `CameraFadeTransition` / `CameraWipeTransition` (not `FadeTransition` / `WipeTransition`) to avoid clashing with Flutter's `package:flutter/material.dart` widget classes.

## Pixel-perfect

Games rendering at exact pixel scale should enable `Camera2D.pixelPerfect = true` and use `OrthographicProjection.pixelPerfect()` — this snaps the projection matrix to whole pixels.

Utilities on the `Vector2` extension:

```dart
final snapped = position.snappedToPixel;  // returns a new Vector2
position.snapToPixel();                   // in place

// Or the free function:
final snapped = snapVector2ToPixel(position);
```

## Split-screen

Multiple cameras with different viewports render side by side:

```dart
world.spawn()
  ..insert(Transform2D.from(0, 0))
  ..insert(GlobalTransform2D.identity())
  ..insert(Camera2D(
    viewport: Viewport(x: 0, y: 0, width: 0.5, height: 1),
    order: 0,
  ));

world.spawn()
  ..insert(Transform2D.from(0, 0))
  ..insert(GlobalTransform2D.identity())
  ..insert(Camera2D(
    viewport: Viewport(x: 0.5, y: 0, width: 0.5, height: 1),
    order: 1,
  ));
```

## Components reference

| Component | Description |
|-----------|-------------|
| `Camera2D` | Marks an entity as a camera. Carries the projection, viewport, and pixel-perfect flag. |
| `CameraFollow` | Smoothly follow another entity. |
| `CameraShake` | Trauma-based screen shake. |
| `Parallax` | Multiplier vs. the camera for background/foreground layers. |
| `CameraFadeTransition` | Full-viewport fade overlay. |
| `CameraWipeTransition` | Directional wipe overlay. |

## Resources reference

| Resource | Description |
|----------|-------------|
| `ViewportSize` | Tracks the current viewport dimensions. Inserted by `CameraPlugin` if not already present. |

## Systems reference

| System | Schedule | Description |
|--------|----------|-------------|
| `CameraFollowSystem` | `postUpdate` | Lerps camera toward the follow target. |
| `CameraShakeSystem` | `postUpdate` | Decays trauma, applies shake delta. |
| `ParallaxSystem` | `postUpdate` | Adjusts parallax entities' `GlobalTransform2D`. |
| `CameraTransitionSystem` | `postUpdate` | Advances fade / wipe transitions. |

## See also

- [2D Rendering](/docs/plugins/render) — `RenderPlugin`, `CameraView`, sprite rendering.
- [Pixel-Perfect Rendering](/docs/guides/pixel-perfect-rendering) — how to keep pixel art crisp.
- [Plugins Overview](/docs/plugins/overview)
