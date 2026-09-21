# fledge_ui

Retained-mode game HUD/UI for [Fledge](https://fledge-framework.dev) — anchor-based layout, containers, text, images, and solid panels painted on top of the sprite pipeline.

[![pub package](https://img.shields.io/pub/v/fledge_ui.svg)](https://pub.dev/packages/fledge_ui)

## Installation

```yaml
dependencies:
  fledge_ui: ^0.2.1
```

## Quick Start

```dart
import 'package:fledge_camera_2d/fledge_camera_2d.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_ui/fledge_ui.dart';

final app = App()
  ..addPlugin(RenderPlugin())
  ..addPlugin(const CameraPlugin())
  ..addPlugin(const UiPlugin());

// Score display anchored to the top-left corner.
app.world.spawn()
  ..insert(const UiNode())
  ..insert(const UiAnchorComponent(UiAnchor.topLeft))
  ..insert(const UiOffset(x: 12, y: 12))
  ..insert(UiText(text: 'Score: 0', fontSize: 20));

// Wrap the render view with FledgeUiOverlay.
runApp(FledgeUiOverlay(app: app, child: FledgeRenderView(app: app)));
```

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs/plugins/ui) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
