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

## Interface-based resource discovery

Iterate every resource that satisfies a given interface or mixin with `World.resourcesOfType<T>()`:

```dart
mixin Serializable {
  Map<String, dynamic> toJson();
}

world.insertResource(Inventory());    // Serializable
world.insertResource(Progress());     // Serializable
world.insertResource(Time());         // not Serializable

for (final s in world.resourcesOfType<Serializable>()) {
  print(s.toJson());
}
```

`fledge_save` uses this to auto-discover `Saveable` resources without manual registration.

## Stage conventions

Systems execute in the order of their stages: `first` → `preUpdate` → `update` → `postUpdate` → `last`. Within a stage, the scheduler parallelises non-conflicting systems and serialises conflicting ones. Two systems in the same stage that share a component write (or one reads what the other writes) *must* run in some order — and when that order isn't declared explicitly, the scheduler falls back to **registration order**. Changing when a plugin is added can silently reorder them.

Recommended placement (mirrors Bevy's convention):

| Stage | What lives here |
|-------|-----------------|
| `first` | Frame-start bookkeeping: input polling, action resolution, time updates |
| `preUpdate` | Input-driven component writes (movement intent, AI steering) |
| `update` | Core game logic; physics clamp/resolve; collision detection |
| `postUpdate` | Reactions to the update stage |
| `last` | Cleanup, render extraction |

When two systems in the same stage conflict, declare the order explicitly:

```dart
SystemMeta(
  name: 'my_movement',
  writes: {ComponentId.of<Velocity>()},
  before: const ['collision_resolution'], // or: after: [...]
)
```

Run `App.checkScheduleOrdering()` in a test or debug boot path to flag every same-stage conflict that currently relies on registration order:

```dart
final app = buildApp();
for (final issue in app.checkScheduleOrdering()) {
  // e.g. OrderingAmbiguity(stage=update): my_movement runs before
  //      collision_resolution by registration order only. Reasons:
  //      both write component Velocity. Add `before: …` …
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
