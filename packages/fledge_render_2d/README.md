# fledge_render_2d

2D rendering for [Fledge](https://fledge-framework.dev) games — sprites, texture atlases, animation, materials, plus the core render infrastructure (RenderPlugin, Extractors, RenderWorld, render graph) previously shipped as a separate `fledge_render` package.

[![pub package](https://img.shields.io/pub/v/fledge_render_2d.svg)](https://pub.dev/packages/fledge_render_2d)

## Installation

```yaml
dependencies:
  fledge_render_2d: ^0.2.1
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

## Directional sprites

`Orientation` tracks one of four cardinal `Direction`s. For 8-, 16- or N-view sprites, `Facing` holds a continuous angle (radians, `0` = +x, clockwise on screen like `Transform2D.rotation`) and picks the view:

```dart
final facing = Facing()..updateFromVector(vx, vy);
final view = facing.viewIndex(16); // 0 = right, 4 = down, 8 = left, 12 = up
```

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs/plugins/render) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
