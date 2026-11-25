# fledge_debug

Runtime observability for [Fledge](https://fledge-framework.dev) — FPS / entity / ordering overlay via `fledge_ui`, plus AABB / collider / camera-frustum gizmos on top of the game.

[![pub package](https://img.shields.io/pub/v/fledge_debug.svg)](https://pub.dev/packages/fledge_debug)

## Installation

```yaml
dependencies:
  fledge_debug: ^0.7.0
```

## Quick Start

```dart
import 'package:fledge_camera_2d/fledge_camera_2d.dart';
import 'package:fledge_debug/fledge_debug.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_ui/fledge_ui.dart';
import 'package:flutter/widgets.dart';

final app = App()
  ..addPlugin(WallTimePlugin())
  ..addPlugin(RenderPlugin())
  ..addPlugin(const CameraPlugin())
  ..addPlugin(const UiPlugin())
  ..addPlugin(const DebugPlugin());

// Wrap the render view: gizmos outermost, then the UI overlay, then the sprite view.
Widget gameView() => DebugGizmosLayer(
  app: app,
  child: FledgeUiOverlay(app: app, child: FledgeRenderView(app: app)),
);
```

`DebugPlugin` inserts `DebugConfig` (keeping one you inserted first), `FrameStats`, `SystemStats` and `ScheduleOrderingReport`. Pass `overlay: false` if you don't use `fledge_ui`. Gizmos (`showAabbGizmos`, `showColliderGizmos`, `showCameraFrustum`) are off by default; turn them on by inserting `config.copyWith(...)`.

### Performance panel for Flutter UIs

Games that draw their HUD in Flutter can show the stats without `fledge_ui`: install `DebugStatsPlugin` and put a `DebugPerfPanel` over the render view. It shows FPS and frame times, the app's tick time, Flutter's build and raster times with a count of frames that missed their refresh, entity and sprite counts, and a frame-time graph.

```dart
app.addPlugin(const DebugStatsPlugin());

Stack(children: [
  FledgeRenderView(app: app),
  if (showPerf) Positioned(top: 8, left: 8, child: DebugPerfPanel(app: app)),
]);
```

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs/ui/debug) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
