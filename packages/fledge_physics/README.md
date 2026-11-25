# fledge_physics

Physics and collision handling for [Fledge](https://fledge-framework.dev) games — layer-based collision detection, wall-sliding resolution, sensor trigger zones, and A* grid pathfinding.

[![pub package](https://img.shields.io/pub/v/fledge_physics.svg)](https://pub.dev/packages/fledge_physics)

## Installation

```yaml
dependencies:
  fledge_physics: ^0.6.0
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

- [Physics](https://fledge-framework.dev/docs/gameplay/physics): collision, layers, sensors, events, fixed-timestep mode, and the [system-ordering rule](https://fledge-framework.dev/docs/gameplay/physics#moving-things-system-ordering) that prevents movement-through-walls bugs.
- [Pathfinding](https://fledge-framework.dev/docs/gameplay/pathfinding): `CollisionGrid`, A* `Pathfinder`, movement costs, path smoothing and lanes.
- [API reference](https://pub.dev/documentation/fledge_physics/latest/)

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
