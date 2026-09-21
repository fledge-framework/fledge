# fledge_ecs

A Bevy-inspired Entity Component System (ECS) for Dart and Flutter game development.

[![pub package](https://img.shields.io/pub/v/fledge_ecs.svg)](https://pub.dev/packages/fledge_ecs)

## Installation

```yaml
dependencies:
  fledge_ecs: ^0.2.0
```

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';

class Position {
  double x, y;
  Position(this.x, this.y);
}

class Velocity {
  double x, y;
  Velocity(this.x, this.y);
}

class MovementSystem extends System {
  @override
  SystemMeta get meta => SystemMeta(
    name: 'movement',
    reads: {ComponentId.of<Velocity>()},
    writes: {ComponentId.of<Position>()},
    resourceReads: {WallTime},
  );

  @override
  Future<void> run(World world) async {
    final time = world.getResource<WallTime>()!;
    for (final (_, pos, vel) in world.query2<Position, Velocity>().iter()) {
      pos.x += vel.x * time.delta;
      pos.y += vel.y * time.delta;
    }
  }
}

void main() async {
  final app = App()
    ..addPlugin(WallTimePlugin())
    ..addSystem(MovementSystem());

  app.world.spawn()
    ..insert(Position(0, 0))
    ..insert(Velocity(10, 5));

  await app.run();
}
```

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
