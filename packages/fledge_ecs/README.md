# fledge_ecs

A Bevy-inspired Entity Component System (ECS) for Dart and Flutter game development.

[![pub package](https://img.shields.io/pub/v/fledge_ecs.svg)](https://pub.dev/packages/fledge_ecs)

## Features

- **Entities & Components**: Spawn entities and attach pure data components
- **Systems**: Define game logic that operates on component queries
- **Resources**: Share global state across systems
- **Events**: Communicate between systems with typed events
- **Plugins**: Bundle related functionality into reusable modules
- **Scheduling**: Control system execution order with stages

## Installation

```yaml
dependencies:
  fledge_ecs: ^0.1.0
```

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';

// Define components (pure data)
class Position {
  double x, y;
  Position(this.x, this.y);
}

class Velocity {
  double x, y;
  Velocity(this.x, this.y);
}

// Define a system
class MovementSystem extends System {
  @override
  SystemMeta get meta => SystemMeta(
    name: 'movement',
    reads: {ComponentId.of<Velocity>()},
    writes: {ComponentId.of<Position>()},
    resourceReads: {Time},
  );

  @override
  Future<void> run(World world) async {
    final time = world.getResource<Time>()!;
    for (final (_, pos, vel) in world.query2<Position, Velocity>().iter()) {
      pos.x += vel.x * time.delta;
      pos.y += vel.y * time.delta;
    }
  }
}

void main() async {
  // Create the app
  final app = App()
    ..addPlugin(TimePlugin())
    ..addSystem(MovementSystem());

  // Spawn an entity
  app.world.spawn()
    ..insert(Position(0, 0))
    ..insert(Velocity(10, 5));

  // Run the game loop
  while (true) {
    await app.tick();
  }
}
```

## Documentation

- [Getting Started Guide](https://fledge-framework.dev/docs/getting-started)
- [API Reference](https://pub.dev/documentation/fledge_ecs)
- [Examples](https://github.com/fledge-framework/fledge/tree/main/examples)

## Related Packages

| Package | Description |
|---------|-------------|
| [fledge_render](https://pub.dev/packages/fledge_render) | Core rendering infrastructure |
| [fledge_render_2d](https://pub.dev/packages/fledge_render_2d) | 2D sprites, cameras, animation |
| [fledge_input](https://pub.dev/packages/fledge_input) | Action-based input handling |
| [fledge_audio](https://pub.dev/packages/fledge_audio) | Music and sound effects |
| [fledge_window](https://pub.dev/packages/fledge_window) | Window management |
| [fledge_tiled](https://pub.dev/packages/fledge_tiled) | Tiled tilemap support |

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
