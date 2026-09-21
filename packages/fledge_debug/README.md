# fledge_debug

Runtime observability for [Fledge](https://fledge-framework.dev) — FPS / entity / ordering overlay via `fledge_ui`, plus AABB / collider / camera-frustum gizmos on top of the game.

[![pub package](https://img.shields.io/pub/v/fledge_debug.svg)](https://pub.dev/packages/fledge_debug)

## Installation

```yaml
dependencies:
  fledge_debug: ^0.2.1
```

## Quick Start

```dart
import 'package:fledge_camera_2d/fledge_camera_2d.dart';
import 'package:fledge_debug/fledge_debug.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_ui/fledge_ui.dart';

final app = App()
  ..addPlugin(WallTimePlugin())
  ..addPlugin(RenderPlugin())
  ..addPlugin(const CameraPlugin())
  ..addPlugin(const UiPlugin())
  ..addPlugin(const DebugPlugin());

// Wrap the render view: gizmos outermost, then the UI overlay, then the sprite view.
runApp(DebugGizmosLayer(
  app: app,
  child: FledgeUiOverlay(app: app, child: FledgeRenderView(app: app)),
));
```

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs/plugins/debug) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
