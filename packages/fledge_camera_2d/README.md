# fledge_camera_2d

2D cameras for [Fledge](https://fledge-framework.dev) games — follow, shake, letterbox, parallax, projections, transitions.

[![pub package](https://img.shields.io/pub/v/fledge_camera_2d.svg)](https://pub.dev/packages/fledge_camera_2d)

## Installation

```yaml
dependencies:
  fledge_camera_2d: ^0.2.1
```

## Quick Start

```dart
import 'package:fledge_camera_2d/fledge_camera_2d.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';

final app = App()
  ..addPlugin(RenderPlugin())
  ..addPlugin(const CameraPlugin());

// Spawn a camera that follows the player.
app.world.spawn()
  ..insert(Transform2D.from(0, 0))
  ..insert(GlobalTransform2D.identity())
  ..insert(Camera2D(projection: OrthographicProjection()))
  ..insert(CameraFollow(target: playerEntity, smoothing: 0.15))
  ..insert(CameraShake());
```

### Follow feel

`smoothing` is the fraction of the remaining distance the camera covers per 1/60 s (1 = locked on). For a softer start and stop, set `smoothTime` instead: a critically damped spring that eases in and out and settles in about that many seconds, without overshooting.

```dart
CameraFollow.marker(smoothTime: 0.25)
```

Both follows use `WallTime.delta`, so they feel the same at 60 Hz and 144 Hz and stay steady through uneven frames. The follow keeps its own unrounded position and only the camera's transform is snapped (see `pixelPerfect` below), so a catch-up eases fully in rather than stalling a pixel short. If something else moves the camera (a transition, a teleport), the follow carries on from there.

### Keeping the camera inside the map

Give `CameraFollow` a `bounds` rect and the follow stops at its edges, so nothing outside the map shows. It uses the projection's visible size and the `ViewportSize` resource; on an axis where the map is smaller than the view, the camera centres on it.

```dart
CameraFollow.marker(bounds: const Rect.fromLTWH(0, 0, 2048, 1280))
```

### Zoom in the widget render path

By default `FledgeRenderView` follows the camera's position but draws one world unit per logical pixel. Set `scaleWidgetView` to make it honour the projection, e.g. for pixel art with a fixed 270-unit viewport height and whole-number zoom:

```dart
Camera2D(
  projection: OrthographicProjection(viewportHeight: 270),
  scaleWidgetView: true,
  pixelPerfect: true, // whole physical pixels per world unit
)
```

With `pixelPerfect`, the zoom is the largest that gives each world unit a **whole number of physical pixels**, at the display scaling of the widget that paints it (`ActiveCameraView.devicePixelRatio`, recorded by `FledgeRenderView`). Under Windows display scaling of 125 % or 150 %, a whole *logical* zoom would draw art pixels at uneven widths and make a sprite moving a whole world unit step by uneven pixel counts, so it would visibly run ahead of a smoothly scrolling camera and snap back. On a 1080p screen at 125 % with a 540-unit viewport, the zoom is 1.6 logical pixels (2 physical), not 1 (1.25 physical).

Map pointer positions to world coordinates with `activeCameraScreenToWorld(world, widgetSize, localPosition)` from `fledge_render_2d`, which uses the same zoom.

With both flags on, `CameraFollow` snaps the camera to whole *screen* pixels (at zoom 2, half world units) and keeps its `bounds` inside the area actually drawn. Art on whole world units still lands on whole screen pixels, and the follow moves in finer steps, so it scrolls evenly instead of juddering between 1- and 2-unit jumps.

A camera snapped to whole screen pixels still judders when its speed isn't a whole number of pixels per frame, e.g. a 120 units/s walk at 144 Hz is 1.67 pixels a frame at zoom 2. Set `subpixelScroll: true` to have `FledgeRenderView` draw the world with the camera on whole pixels (just as crisp) and then shift the finished frame by the leftover fraction of a pixel, blended across one screen pixel. The camera then glides evenly at any speed and refresh rate, at the cost of one offscreen image per frame. The follow stops snapping the transform, and `activeCameraScreenToWorld` uses the exact offset, so pointer mapping matches the shifted frame.

For even scrolling, also time frames by the display: when a Flutter ticker drives the app, call `WallTime.useClock` with `SchedulerBinding.instance.currentSystemFrameTimeStamp` and `frameInterval: WallTime.frameIntervalFor(refreshRate)` (see `fledge_ecs`). That counts a display reporting 59 Hz as 60, so a 120 units/s walk moves exactly 2 units a frame and the snapped camera steps evenly, rather than 2 most frames and 2.5 now and then.

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs/plugins/camera_2d) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
