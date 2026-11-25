# Pixel Art

Low-resolution art scaled up needs three things to stay crisp: a whole
number of screen pixels per art pixel, a camera that lands on whole pixels,
and nearest-neighbour texture sampling. `fledge_camera_2d` handles the first
two through `Camera2D`; the third is a setting on the sprite drawer.

<!-- snippet-setup
import 'package:vector_math/vector_math.dart';

late App app;
late Entity player;
-->

## What goes wrong without it

- **Blur**: the canvas drawer samples textures bilinearly by default, so
  scaled-up art pixels smear into their neighbours.
- **Uneven pixels**: at a zoom like 2.5, some art pixels cover two screen
  pixels and some three.
- **Seams and shimmer**: a camera at a fractional position puts tile edges
  between screen pixels, so thin gaps flicker between tiles and edges crawl as
  the camera moves.
- **Judder**: a camera that only moves in whole pixels, at a speed that isn't a
  whole number of pixels per frame, steps unevenly (1, 2, 1, 2 ...).

## The recipe

```dart
App buildPixelArtApp() {
  final app = App()
    ..addPlugin(WallTimePlugin())
    ..addPlugin(RenderPlugin())
    ..addPlugin(const CameraPlugin())
    ..addSystem(TransformPropagateSystem(), schedule: Schedules.preUpdate);
  app.world.getResource<Extractors>()!.register(SpriteExtractor());

  // 1. Nearest-neighbour sampling for every sprite.
  final drawer = app.world.getResource<SpriteDrawer>();
  if (drawer is CanvasSpriteDrawer) {
    drawer.paint.filterQuality = FilterQuality.none;
  }

  final player = app.world.spawn()
    ..insert(Transform2D.from(160, 90))
    ..insert(GlobalTransform2D());

  // 2. A camera showing about 270 art pixels of height, zoomed by a whole
  //    number of physical pixels, following the player.
  app.world.spawn()
    ..insert(Transform2D.from(160, 90))
    ..insert(GlobalTransform2D())
    ..insert(Camera2D(
      projection: OrthographicProjection(viewportHeight: 270),
      scaleWidgetView: true,
      pixelPerfect: true,
    ))
    ..insert(CameraFollow(
      target: player.entity,
      smoothTime: 0.2,
      bounds: const Rect.fromLTWH(0, 0, 1280, 720),
    ));

  return app;
}
```

Use one world unit per art pixel: a 16×16 tile is 16 world units, and sprites
sit on whole world units when they're at rest.

## Texture filtering

`CanvasSpriteDrawer.paint` is the `Paint` behind every sprite draw. It starts
at `FilterQuality.low` (bilinear). Set its `filterQuality` once after adding
`RenderPlugin`, as above. `FilterQuality.none` is nearest-neighbour. The
setting is shared by every sprite, tile and particle the drawer draws.
`fledge_ui` images are drawn with their own paint, already unfiltered.

## What the camera flags do

**`scaleWidgetView: true`** makes `FledgeRenderView` fill the widget's height
with the projection's visible height (here 270 world units). Without it the
widget draws one world unit per logical pixel and ignores the projection.

**`pixelPerfect: true`** does three things:

- With `scaleWidgetView`, the zoom becomes the largest that gives each world
  unit a **whole number of physical pixels**, at the display scaling of the
  widget that paints it (`ActiveCameraView.devicePixelRatio`, recorded by
  `FledgeRenderView`). More of the world shows instead of pixels stretching.
  On a 1080p screen at 125 % scaling with a 540-unit viewport, the zoom is 1.6
  logical pixels (2 physical), not 1 (1.25 physical). When even one physical
  pixel per unit doesn't fit, the zoom falls back to the exact fraction.
- `CameraFollowSystem` snaps the camera's transform to whole **screen**
  pixels (with zoom 2, half world units). Art on whole world units still lands
  on whole screen pixels, and the camera moves in finer steps, so it doesn't
  judder between 1- and 2-unit jumps. The follow keeps its own unrounded
  position, so it eases fully in instead of stalling a pixel short.
- The widget rounds the camera offset to whole pixels, so an odd-sized widget
  doesn't put the world on half pixels.

Only `CameraFollowSystem` snaps the camera. A camera you move yourself should
be snapped by you (see [Utilities](#utilities)).

`OrthographicProjection.pixelPerfect()` is something else: a projection with
one world unit per pixel (`ScalingMode.none`). It doesn't snap anything.

## Smooth scrolling at any speed

A camera on whole screen pixels still judders when its speed isn't a whole
number of pixels per frame: a 120 units/s walk at 144 Hz and zoom 2 is 1.67
pixels a frame. Turn on `subpixelScroll`:

```dart
Camera2D(
  projection: OrthographicProjection(viewportHeight: 270),
  scaleWidgetView: true,
  pixelPerfect: true,
  subpixelScroll: true,
);
```

`FledgeRenderView` then draws the world into an offscreen image with the
camera on whole physical pixels (just as crisp), and draws that image shifted
by the leftover fraction of a pixel, blended across one screen pixel. The
camera glides evenly at any speed and refresh rate, for the cost of one
offscreen image per frame. The follow stops snapping the transform, and
`activeCameraScreenToWorld` uses the exact offset so pointer mapping matches
the shifted frame. View passes (lighting included) are drawn into the same
image, so they line up.

Even scrolling also needs even frame times. When a Flutter ticker drives the
app, time frames by the display's vsync rather than a stopwatch:

```dart
import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:flutter/scheduler.dart';

void useDisplayClock(App app) {
  final hz = PlatformDispatcher.instance.views.first.display.refreshRate;
  app.world.getResource<WallTime>()!.useClock(
    () => SchedulerBinding.instance.currentSystemFrameTimeStamp,
    frameInterval: WallTime.frameIntervalFor(hz),
  );
}
```

That counts every frame in whole refreshes (a display reporting 59 Hz is
counted as 60), so a 120 units/s walk moves exactly 2 units a frame instead of
2 most frames and 2.5 now and then. See
[Time & Fixed Timestep](/docs/scheduling/time).

## Utilities

`fledge_camera_2d` exports small helpers for snapping your own positions
(a hand-driven camera, a sprite's drawn position):

```dart
final x = snapToPixel(12.6);                         // 13.0
final p = snapVector2ToPixel(Vector2(3.4, 7.5));     // new Vector2(3, 8)
final q = Vector2(1.2, 2.8)..snapToPixel();          // in place: (1, 3)
final r = Vector2(1.2, 2.8).snappedToPixel;          // a copy: (1, 3)
snapVector2ToPixelInPlace(q);
```

With `scaleWidgetView` the screen pixel is `1 / zoom` world units; snap
`value * zoom` and divide back, as the follow does. `activeCameraZoom(world,
size)` returns the zoom.

## Tiles and atlases

- Sampling a tile at its very edge can pick up its neighbour in the sheet.
  Leave a gap between cells, or extrude each tile's border pixels into the
  gap, and describe it to the atlas with `paddingX` / `paddingY` and
  `offsetX` / `offsetY` (see
  [Texture atlases](/docs/rendering/sprites-animation#texture-atlases)).
- Place tilemap layers on whole world units (see
  [Rendering Tilemaps](/docs/gameplay/tiled-rendering)).
- For pixel-art lighting, `Light2D(bands: n)` steps the falloff into flat
  rings (see [Lighting](/docs/rendering/lighting)).

## Checklist

- [ ] `CanvasSpriteDrawer.paint.filterQuality = FilterQuality.none`
- [ ] `Camera2D(scaleWidgetView: true, pixelPerfect: true)` with
      `viewportHeight` set to the art resolution you design for
- [ ] The built-in `CameraFollow` moves the camera (or you snap it yourself)
- [ ] One world unit per art pixel; sprites at rest on whole units
- [ ] `subpixelScroll: true` and `WallTime.useClock` if scrolling judders
