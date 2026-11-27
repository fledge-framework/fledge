# fledge_ui

Retained-mode game HUD/UI and generic placement mode for [Fledge](https://fledge-framework.dev) — anchor-based layout, containers, text, images, solid panels painted on top of the sprite pipeline, plus a `PlacementCorePlugin` that runs Stardew-adjacent "drop-a-hotbar-item-into-the-world" flows (mode state, validator seam, world-space ghost preview).

[![pub package](https://img.shields.io/pub/v/fledge_ui.svg)](https://pub.dev/packages/fledge_ui)

## Installation

```yaml
dependencies:
  fledge_ui: ^0.7.1
```

## Quick Start

```dart
import 'package:fledge_camera_2d/fledge_camera_2d.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_ui/fledge_ui.dart';
import 'package:flutter/widgets.dart';

App buildApp() {
  final app = App()
    ..addPlugin(RenderPlugin()) // first: UiPlugin needs its Extractors
    ..addPlugin(const UiPlugin()); // inserts ViewportSize if CameraPlugin hasn't

  // Score display anchored to the top-left corner.
  app.world.spawn()
    ..insert(const UiNode())
    ..insert(const UiAnchorComponent(UiAnchor.topLeft))
    ..insert(const UiOffset(x: 12, y: 12))
    ..insert(UiText(text: 'Score: 0', fontSize: 20));

  return app;
}

/// Wrap the render view with FledgeUiOverlay, keeping ViewportSize (1280×720
/// by default) equal to the space the view gets.
Widget gameWithHud(App app) => LayoutBuilder(
  builder: (context, constraints) {
    app.world.getResource<ViewportSize>()!.updateFromSize(constraints.biggest);
    return FledgeUiOverlay(app: app, child: FledgeRenderView(app: app));
  },
);
```

UI nodes are display-only (not focusable, no hit testing); build menus from Flutter widgets. The overlay draws images with `Canvas.drawImageRect` and panels with `drawRect` / `drawRRect`, outside the sprite pipeline, in screen space; a `UiImage` tint multiplies the image's colour and alpha. Pass `FledgeUiOverlay(repaint: ...)` the same once-a-frame listenable as `FledgeRenderView` to repaint the HUD every frame without a rebuild.

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs/ui/hud) for guides, API reference, and advanced usage. Placement mode is covered in [Placement](https://fledge-framework.dev/docs/gameplay/placement).

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
