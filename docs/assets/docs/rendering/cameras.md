# Cameras

`fledge_camera_2d` adds 2D cameras: a `Camera2D` component, follow, shake,
parallax, transitions, projections and pixel snapping. It tells
`FledgeRenderView` where to look through the `ActiveCameraView` resource.

```yaml
dependencies:
  fledge_render_2d: ^0.6.0
  fledge_camera_2d: ^0.6.0
```

Flutter 3.50+ (Dart 3.14+); desktop first, web and mobile best-effort. Add
`CameraPlugin` alongside `RenderPlugin`, and `WallTimePlugin` for
frame-rate-independent follow and shake.

<!-- snippet-setup
import 'package:vector_math/vector_math.dart';

late World world;
late Entity player;
late Entity cameraEntity;
-->

## Quick start

```dart
final app = App()
  ..addPlugin(WallTimePlugin())
  ..addPlugin(RenderPlugin())
  ..addPlugin(const CameraPlugin())
  ..addSystem(TransformPropagateSystem(), schedule: Schedules.preUpdate);

final player = app.world.spawn()
  ..insert(Transform2D.from(400, 300))
  ..insert(GlobalTransform2D());

app.world.spawn()
  ..insert(Transform2D.from(400, 300))
  ..insert(GlobalTransform2D())
  ..insert(Camera2D())
  ..insert(CameraFollow(target: player.entity, smoothing: 0.15))
  ..insert(CameraShake());
```

`FledgeRenderView` now draws the world with the camera's position at the
centre of the widget, one world unit per logical pixel.

## What CameraPlugin adds

It inserts a `ViewportSize` resource (1280×720, unless you inserted one
first) and five systems in `Schedules.postUpdate`, already ordered after
`TransformPropagateSystem.systemName`:

| System | Does |
|---|---|
| `CameraFollowSystem` | Moves cameras with `CameraFollow` towards their target. |
| `CameraShakeSystem` | Decays `CameraShake` trauma and picks this frame's shake offset. |
| `ParallaxSystem` | Offsets `Parallax` entities by the camera position (shake included). |
| `CameraTransitionSystem` | Advances `CameraFadeTransition` / `CameraWipeTransition`. |
| `ActiveCameraViewSystem` | Publishes the active camera, plus its shake offset, to `ActiveCameraView`. |

They run in that order. Order your own camera logic with their `systemName`
constants, e.g. `before: [CameraFollowSystem.systemName]` to retarget the
camera this frame, or `after: [ActiveCameraViewSystem.systemName]` to read
where it ended up.

## How the widget uses the camera

Each frame `ActiveCameraViewSystem` picks the active `Camera2D`
(`isActive: true`) with the lowest `order` and writes its world position
(plus its `CameraShake` offset, if it has one), its `pixelPerfect` and
`subpixelScroll` flags, and its zoom into `ActiveCameraView`. `FledgeRenderView`, `DebugGizmosLayer`, view passes and
the [camera helpers](/docs/rendering/overview#camera-aware-drawing-in-your-own-widgets)
all draw through it.

What the widget path uses from the camera, and what it doesn't:

- **Position**: yes. The camera's `GlobalTransform2D` position sits at the
  widget's centre.
- **Zoom**: only with `scaleWidgetView: true` (see below). Otherwise one world
  unit is one logical pixel, whatever the projection says.
- **Rotation**: no. A rotated camera (including the rotation part of
  `CameraShake`) draws unrotated.
- **Projection shape**: no. `IsometricProjection` and `ObliqueProjection`
  contribute only their visible height to the zoom; their skew isn't applied.
- **Viewport and split-screen**: no. `Camera2D.viewport` and multiple
  simultaneous views are only read by the opt-in `CameraDriverNode` (see
  [Render Graph](/docs/rendering/render-graph)). Split-screen isn't supported
  in the widget path: every `FledgeRenderView` of an app shows the same
  camera.

With no active camera, `ActiveCameraView` keeps its last value, and with no
`ActiveCameraView` at all the widgets draw world = screen.

## Camera2D

```dart
Camera2D(
  projection: OrthographicProjection(viewportHeight: 270),
  order: 0,               // lowest active order wins
  isActive: true,
  scaleWidgetView: true,  // honour the projection's zoom in the widget
  pixelPerfect: false,    // see Pixel Art
  subpixelScroll: false,  // see Pixel Art
);
```

### Zoom

By default the widget draws one world unit per logical pixel. Set
`scaleWidgetView: true` and the zoom becomes
`widgetHeight / projection.visibleHeight(...)`, so the projection's visible
height fills the widget:

| Projection | Visible height (the widget fills this) |
|---|---|
| `OrthographicProjection(scalingMode: ScalingMode.fixedHeight, viewportHeight: h)` (the default mode) | `h` world units |
| `OrthographicProjection(scalingMode: ScalingMode.fixedWidth, viewportWidth: w)` | `w / aspect`, so `w` units fill the width |
| `OrthographicProjection.pixelPerfect()` (`ScalingMode.none`) | the widget's own height: zoom 1 |
| `IsometricProjection(viewportSize: s)` | `s` |
| `ObliqueProjection(viewportHeight: h)` | `h` |

`OrthographicProjection`'s defaults are 10×10 world units, which is tiny:
always set `viewportHeight` (or width) when you turn on `scaleWidgetView`. To
zoom at runtime, change the projection's `viewportHeight`; the next frame
picks it up. `Camera2D.widgetZoom(size, devicePixelRatio:)` returns the zoom
for a widget size.

### Projections

`Camera2D.projection` takes any `Projection`:

- `OrthographicProjection(scalingMode:, viewportWidth:, viewportHeight:, letterbox:)`,
  the default: flat 2D.
- `IsometricProjection(viewportSize: 20)`: a 2:1 isometric skew.
- `ObliqueProjection(viewportWidth: 20, viewportHeight: 20, angleRadians: math.pi / 4, depthFactor: 0.5)`:
  a cabinet (`depthFactor` 0.5) or cavalier (1.0) skew.

As noted above, the widget path takes only the zoom from a projection. For an
isometric or oblique game, place sprites in screen-space positions yourself;
`IsometricProjection.worldToIso(v)` and `ObliqueProjection.worldToOblique(v)`
do the conversion. `matrix(size)`, `visibleWidth` and `visibleHeight` are
there for custom renderers.

`OrthographicProjection.pixelPerfect()` only means one world unit per pixel.
It doesn't snap anything; snapping is `Camera2D.pixelPerfect`, covered in
[Pixel Art](/docs/rendering/pixel-art).

### Screen and world coordinates

Use the `fledge_render_2d` helpers, which match exactly what the widget
draws (zoom, pixel snapping and sub-pixel scrolling included):

```dart
import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';

/// Where a click at [local] (widget-local logical pixels) lands in a
/// widget of [size].
Offset clickToWorld(World world, Size size, Offset local) =>
    activeCameraScreenToWorld(world, size, local);
```

`Camera2D.screenToWorld` and `worldToScreen` use the same mapping without a
`World`: y points down, the camera's position is the centre of its viewport,
and one world unit spans `camera.widgetZoom(size)` logical pixels (1 unless
`scaleWidgetView`), with the pixel-perfect rounding the widget applies. They
invert each other. They take the camera's own transform, so a screen shake
isn't included; the `activeCamera…` helpers above map what was actually drawn.

```dart
Vector2 clickToWorldFor(
  Camera2D camera,
  GlobalTransform2D cameraTransform,
  Size size,
  Offset local,
) => camera.screenToWorld(
  Vector2(local.dx, local.dy),
  cameraTransform,
  RenderSize(size.width, size.height),
);
```

## Following a target

```dart
CameraFollow(
  target: player,
  smoothing: 0.15,        // fraction of the gap closed per 1/60 s; 1 = locked on
  offset: const Offset(0, -32),
  bounds: const Rect.fromLTWH(0, 0, 2048, 1280),
);
```

- **`smoothing`** (0..1, default 0.15): a damped follow, the same at any frame
  rate (it uses `WallTime.delta`; without a `WallTime` resource it steps once
  per run).
- **`smoothTime`**: set it instead for a critically damped spring that eases
  in and out and settles in about that many seconds without overshooting.
- **`offset`**: added to the target's position (look ahead, frame the player
  low).
- **`bounds`**: the view stays inside this world rect; where the rect is
  smaller than the view, the camera centres on it.

The follow keeps its own unrounded position and only snaps the camera's
transform when the camera is pixel-perfect. If something else moves the
camera (a cutscene, a teleport), the follow carries on from there. When the
target has `PreviousTransform2D`, the camera follows its interpolated
position (see [Transforms](/docs/rendering/transforms#smooth-movement-between-fixed-steps)).
A root camera's `GlobalTransform2D` is written straight away, so systems later
in the frame see the new position without another propagation pass.

**Bounds and the visible size.** The clamp uses the area the widget actually
shows: the size the camera's widget was last painted at (recorded on
`ActiveCameraView`), divided by the camera's widget zoom, so one world unit
per logical pixel unless `scaleWidgetView` is on. Before the first paint, or
if you don't draw through `FledgeRenderView`, it uses the `ViewportSize`
resource in place of the widget's size. That defaults to 1280×720 and isn't
updated for you, so keep it in step with your view in that case, e.g. from a
`LayoutBuilder`:

```dart
void onViewportResized(World world, Size size) =>
    world.getResource<ViewportSize>()!.updateFromSize(size);
```

### Following whoever carries a marker

`CameraFollow.marker(...)` follows the first entity carrying
`CameraFollowTarget`, so the camera can exist before the player does, and
moving the marker hands the camera to another entity (a cutscene, a
possessed character):

```dart
world.spawn()
  ..insert(Transform2D.from(0, 0))
  ..insert(Camera2D())
  ..insert(CameraFollow.marker(smoothTime: 0.25));

world.insert(player, const CameraFollowTarget());
```

With an explicit `target` that is despawned (or has no
`GlobalTransform2D`), the system prints one warning and leaves that camera
alone until the target is back.

## Shake

`CameraShake` is trauma-based: `addTrauma` bumps `trauma` (clamped to 0..1),
the offset scales with `trauma²`, and trauma decays at `traumaDecayPerSec`.

```dart
world.get<CameraShake>(cameraEntity)!.addTrauma(0.5); // an explosion
```

| Field | Default |
|---|---|
| `trauma` | 0 |
| `traumaDecayPerSec` | 1.5 (a full shake lasts about 0.7 s) |
| `maxOffsetX`, `maxOffsetY` | 12 world units |
| `maxRotationRadians` | 0.15 (not drawn by the widget path) |
| `rng` | a new `math.Random()`; pass a seeded one for repeatable shakes |

The shake is a render-time offset: `CameraShakeSystem` stores this frame's
offset on the component (`offsetX`, `offsetY`, `rotationOffset`) and never
touches the camera's `Transform2D`. `ActiveCameraViewSystem` adds the offset
to the position it publishes, so the shake shows the same frame, with or
without `CameraFollow`, and the follow, bounds and save data all see the
steady camera position. `CameraShakeSystem(fixedDelta: 1 / 60)` uses a fixed
step instead of `WallTime`, for tests.

## Parallax

`Parallax(factor)` makes an entity scroll slower than the world: its drawn
position is `translation + (1 − factor) × cameraPosition`. `1` moves with the
world (no parallax), `0.5` at half speed, `0` stays fixed on screen.

```dart
world.spawn()
  ..insert(Transform2D.from(0, 0))
  ..insert(GlobalTransform2D())
  ..insert(const Parallax(0.3))
  ..insert(Sprite(texture: kSolidColorTexture, layer: DrawLayer.background));
```

`ParallaxSystem` rewrites the entity's `GlobalTransform2D` after
propagation, reading the active camera's `Transform2D` plus its shake
offset, so a factor-0 layer stays fixed on screen while the world shakes. It works on root entities only, and parallax layers must not be
`StaticTransform`.

## Letterboxing

`OrthographicProjection(letterbox: LetterboxConfig(targetAspect: 16 / 9))`
keeps the projection's aspect ratio, but nothing in the widget path draws
bars or crops the view. To letterbox a `FledgeRenderView`, size the widget
yourself: wrap it in Flutter's `AspectRatio` on a black background, or
compute the rects:

```dart
const viewport = RenderSize(1920, 1200);
final game = computeLetterbox(viewport, 16 / 9); // where the game goes
final bars = computeGutter(viewport, game);      // up to two bar rects
```

## Transitions

Camera transitions are components on the camera entity that
`CameraTransitionSystem` advances with `WallTime.delta`:

```dart
world.insert(
  cameraEntity,
  CameraFadeTransition(duration: 0.5, color: const Color(0xFF000000)),
);
world.insert(
  cameraEntity,
  CameraWipeTransition(
    duration: 0.4,
    direction: WipeDirection.leftToRight,
    reverse: true,
  ),
);
```

`progress` runs from 0 to 1; `effectiveProgress` is the same with `reverse`
applied; `isComplete` turns true at the end. A finished transition stays on
the entity until you remove it, so you can chain the next step off it.
Nothing draws them for you. A view pass can:

```dart
class CameraFadePass extends ViewPass {
  const CameraFadePass();

  @override
  void paintOver(World world, Canvas canvas, Rect visibleWorld) {
    for (final (_, fade) in world.query1<CameraFadeTransition>().iter()) {
      final alpha = fade.color.a * fade.effectiveProgress;
      canvas.drawRect(
        visibleWorld,
        Paint()..color = fade.color.withValues(alpha: alpha),
      );
    }
  }
}
```

Add it with `app.world.getResource<ViewPasses>()!.add(const CameraFadePass())`.
This follows the class's convention: the overlay's opacity is
`effectiveProgress` × the colour's alpha, so a plain fade covers the screen
and `reverse: true` uncovers it. Paint it in `paintOver` and emissive sprites still show through; a
Flutter widget stacked over the view covers everything. For scene changes,
`TransitionState` in `fledge_render_2d` (see
[Scene fades](/docs/rendering/sprites-animation#scene-fades)) also tracks the
loading phase.

## Reference

| Type | Kind | Purpose |
|---|---|---|
| `Camera2D` | component | Projection, order, active flag, widget zoom and pixel options. |
| `CameraFollow`, `CameraFollowTarget` | components | Follow an entity or a marker. |
| `CameraShake` | component | Trauma-based shake. |
| `Parallax` | component | Scroll factor for a root entity. |
| `CameraFadeTransition`, `CameraWipeTransition` | components | Overlay timing. |
| `ViewportSize` | resource | View size used by follow bounds before the first paint, and by `fledge_ui` layout. |
| `ActiveCameraView` | resource (`fledge_render_2d`) | What the widgets draw through. |
| `CameraDriverNode` | render-graph node | Opt-in; see [Render Graph](/docs/rendering/render-graph). |

Pixel-snapping helpers (`snapToPixel`, `snapVector2ToPixel`,
`snapVector2ToPixelInPlace`, `Vector2.snappedToPixel`) are covered in
[Pixel Art](/docs/rendering/pixel-art). Full signatures are in the
[API reference](https://pub.dev/documentation/fledge_camera_2d/latest/).
