# Introduction to Fledge

Fledge is a modern, Bevy-inspired Entity Component System (ECS) game framework for Flutter, designed specifically for desktop game development on Windows, macOS, and Linux.

## What is Fledge?

Fledge brings the power and ergonomics of Bevy's ECS architecture to the Flutter ecosystem. It provides:

- **Clean ECS architecture** with separation of data (components) and logic (systems)
- **Archetype-based storage** for excellent cache locality and performance
- **Code generation** to minimize boilerplate
- **Automatic parallel execution** of systems based on dependency analysis
- **Modular plugin system** for composable game features

## Why ECS?

Entity Component System is a software architectural pattern that favors composition over inheritance. Instead of deep class hierarchies, you compose game objects from small, focused data components and process them with systems.

```dart
// Traditional OOP approach
class Player extends Character {
  // Inherits from Character, which inherits from Entity...
  // Deep hierarchies become hard to maintain
}

// ECS approach
final player = world.spawn()
  ..insert(Position(0, 0))
  ..insert(Velocity(0, 0))
  ..insert(Health(100))
  ..insert(Player()); // Just a marker component
```

### Benefits of ECS

1. **Flexibility**: Add or remove capabilities at runtime by adding/removing components
2. **Performance**: Archetype storage keeps related data together in memory
3. **Testability**: Systems are pure functions that are easy to test in isolation
4. **Parallelism**: Independent systems can run concurrently

## Fledge vs Other Frameworks

| Feature | Fledge | Flame | Unity |
|---------|--------|-------|-------|
| Architecture | ECS | Component-based | Hybrid |
| Storage | Archetype | Hash map | Archetype |
| Parallelism | Automatic | Manual | Jobs |
| Type Safety | Strong | Moderate | Weak |

## Getting Started

Ready to build your first game with Fledge? Head to the [Installation](/docs/getting-started/installation) guide to get started.

## Example

Here's a taste of what Fledge code looks like:

```dart-tabs
// @tab Annotations
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_ecs_annotations/fledge_ecs_annotations.dart';

part 'main.g.dart';

// Define components with annotations (generates boilerplate)
@component
class Position {
  double x, y;
  Position(this.x, this.y);
}

@component
class Velocity {
  double dx, dy;
  Velocity(this.dx, this.dy);
}

// Define a system with annotation (generates wrapper class)
@system
void movementSystem(World world) {
  final dt = world.getResource<Time>()!.delta;
  for (final (_, pos, vel) in world.query2<Position, Velocity>().iter()) {
    pos.x += vel.dx * dt;
    pos.y += vel.dy * dt;
  }
}

// Create a plugin to organize game setup
class GamePlugin implements Plugin {
  @override
  void build(App app) {
    app.addSystem(MovementSystemWrapper());

    // Spawn initial entities
    app.world.spawn()
      ..insert(Position(0, 0))
      ..insert(Velocity(1, 0.5));
  }

  @override
  void cleanup() {}
}

void main() async {
  await App()
    .addPlugin(TimePlugin())   // Provides delta time
    .addPlugin(GamePlugin())   // Your game setup
    .run();
}
// @tab Inheritance
import 'package:fledge_ecs/fledge_ecs.dart';

// Define components as plain classes (no annotations)
class Position {
  double x, y;
  Position(this.x, this.y);
}

class Velocity {
  double dx, dy;
  Velocity(this.dx, this.dy);
}

// Define a system by implementing the System interface
class MovementSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'movement',
        writes: {ComponentId.of<Position>()},
        reads: {ComponentId.of<Velocity>()},
        resourceReads: {Time},
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => runCondition?.call(world) ?? true;

  @override
  Future<void> run(World world) async {
    final dt = world.getResource<Time>()!.delta;
    for (final (_, pos, vel) in world.query2<Position, Velocity>().iter()) {
      pos.x += vel.dx * dt;
      pos.y += vel.dy * dt;
    }
  }
}

// Create a plugin to organize game setup
class GamePlugin implements Plugin {
  @override
  void build(App app) {
    app.addSystem(MovementSystem());

    // Spawn initial entities
    app.world.spawn()
      ..insert(Position(0, 0))
      ..insert(Velocity(1, 0.5));
  }

  @override
  void cleanup() {}
}

void main() async {
  await App()
    .addPlugin(TimePlugin())   // Provides delta time
    .addPlugin(GamePlugin())   // Your game setup
    .run();
}
```

This simple example demonstrates the core concepts: entities, components, systems, plugins, and the App builder. In the following guides, we'll explore each of these in depth.
