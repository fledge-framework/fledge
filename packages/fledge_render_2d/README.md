# fledge_render_2d

2D rendering for [Fledge](https://fledge-framework.dev) games — sprites, texture atlases, animation, materials, plus the core render infrastructure (RenderPlugin, Extractors, RenderWorld, render graph) previously shipped as a separate `fledge_render` package.

[![pub package](https://img.shields.io/pub/v/fledge_render_2d.svg)](https://pub.dev/packages/fledge_render_2d)

## Installation

```yaml
dependencies:
  fledge_render_2d: ^0.2.0
```

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';

void main() async {
  final app = App()
    ..addPlugin(WallTimePlugin())
    ..addPlugin(RenderPlugin());

  // Spawn a sprite.
  app.world.spawn()
    ..insert(Transform2D.from(100, 200))
    ..insert(GlobalTransform2D.identity())
    ..insert(Sprite(texture: playerTexture));

  await app.run();
}
```

Paint the scene into a Flutter widget:

```dart
runApp(MaterialApp(home: FledgeRenderView(app: app)));
```

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs/plugins/render) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
