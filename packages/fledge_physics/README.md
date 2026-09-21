# fledge_physics

Physics and collision handling for [Fledge](https://fledge-framework.dev) games — layer-based collision detection, wall-sliding resolution, and sensor trigger zones.

[![pub package](https://img.shields.io/pub/v/fledge_physics.svg)](https://pub.dev/packages/fledge_physics)

## Installation

```yaml
dependencies:
  fledge_physics: ^0.2.1
```

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_physics/fledge_physics.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';

void main() async {
  final app = App()
    ..addPlugin(WallTimePlugin())
    ..addPlugin(PhysicsPlugin());

  // Solid wall.
  app.world.spawn()
    ..insert(Transform2D.from(100, 50))
    ..insert(Collider.single(RectangleShape(x: 0, y: 0, width: 100, height: 20)))
    ..insert(const CollisionConfig.solid());

  // Trigger zone.
  app.world.spawn()
    ..insert(Transform2D.from(200, 100))
    ..insert(Collider.single(RectangleShape(x: 0, y: 0, width: 50, height: 50)))
    ..insert(const CollisionConfig.sensor());

  await app.run();
}
```

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs/plugins/physics) for guides, API reference, and advanced usage — including the [system-ordering rules](https://fledge-framework.dev/docs/plugins/physics#system-ordering) that prevent movement-through-walls bugs.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
