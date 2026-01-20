# Quick Start

Let's build a simple simulation to understand Fledge's core concepts. We'll create entities that move around based on their velocity.

## Step 1: Define Components

Components are pure data containers. Create a file for your components:

```dart-tabs
// @tab Annotations
// lib/components.dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_ecs_annotations/fledge_ecs_annotations.dart';

part 'components.g.dart';

@component
class Position {
  double x;
  double y;

  Position(this.x, this.y);

  @override
  String toString() => 'Position($x, $y)';
}

@component
class Velocity {
  double dx;
  double dy;

  Velocity(this.dx, this.dy);
}

/// Marker component to identify player entities
@component
class Player {}
// @tab Inheritance
// lib/components.dart

// Components are just plain Dart classes - no annotation needed
class Position {
  double x;
  double y;

  Position(this.x, this.y);

  @override
  String toString() => 'Position($x, $y)';
}

class Velocity {
  double dx;
  double dy;

  Velocity(this.dx, this.dy);
}

/// Marker component to identify player entities
class Player {}
```

If using annotations, run `dart run build_runner build` to generate the `.g.dart` files.

## Step 2: Define Systems

Systems contain the game logic. They query for entities with specific components and process them:

```dart-tabs
// @tab Annotations
// lib/systems.dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_ecs_annotations/fledge_ecs_annotations.dart';

import 'components.dart';

part 'systems.g.dart';

@system
void movementSystem(World world) {
  for (final (_, pos, vel) in world.query2<Position, Velocity>().iter()) {
    pos.x += vel.dx;
    pos.y += vel.dy;
  }
}

@system
void printPositionsSystem(World world) {
  print('--- Entity Positions ---');
  for (final (entity, pos) in world.query1<Position>().iter()) {
    print('Entity ${entity.id}: $pos');
  }
}
// @tab Inheritance
// lib/systems.dart
import 'package:fledge_ecs/fledge_ecs.dart';

import 'components.dart';

class MovementSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'movement',
        writes: {ComponentId.of<Position>()},
        reads: {ComponentId.of<Velocity>()},
      );

  @override
  Future<void> run(World world) async {
    for (final (_, pos, vel) in world.query2<Position, Velocity>().iter()) {
      pos.x += vel.dx;
      pos.y += vel.dy;
    }
  }
}

class PrintPositionsSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'printPositions',
        reads: {ComponentId.of<Position>()},
      );

  @override
  Future<void> run(World world) async {
    print('--- Entity Positions ---');
    for (final (entity, pos) in world.query1<Position>().iter()) {
      print('Entity ${entity.id}: $pos');
    }
  }
}
```

## Step 3: Create a Plugin

Plugins encapsulate game setup: systems, resources, and initial entities.

```dart-tabs
// @tab Annotations
// lib/game_plugin.dart
import 'package:fledge_ecs/fledge_ecs.dart';

import 'components.dart';
import 'systems.dart';

class SimulationPlugin implements Plugin {
  @override
  void build(App app) {
    // Add systems (use the generated wrappers)
    app
      .addSystem(MovementSystemWrapper())
      .addSystem(PrintPositionsSystemWrapper());

    // Spawn initial entities
    app.world.spawn()
      ..insert(Position(0, 0))
      ..insert(Velocity(1, 0));

    app.world.spawn()
      ..insert(Position(10, 5))
      ..insert(Velocity(0, 1));

    app.world.spawn()
      ..insert(Position(0, 0))
      ..insert(Velocity(0.5, 0.5))
      ..insert(Player());
  }

  @override
  void cleanup() {}
}
// @tab Inheritance
// lib/game_plugin.dart
import 'package:fledge_ecs/fledge_ecs.dart';

import 'components.dart';
import 'systems.dart';

class SimulationPlugin implements Plugin {
  @override
  void build(App app) {
    // Add class-based systems
    app
      .addSystem(MovementSystem())
      .addSystem(PrintPositionsSystem());

    // Spawn initial entities
    app.world.spawn()
      ..insert(Position(0, 0))
      ..insert(Velocity(1, 0));

    app.world.spawn()
      ..insert(Position(10, 5))
      ..insert(Velocity(0, 1));

    app.world.spawn()
      ..insert(Position(0, 0))
      ..insert(Velocity(0.5, 0.5))
      ..insert(Player());
  }

  @override
  void cleanup() {}
}
```

## Step 4: Create the App

The App is the main entry point that combines plugins and runs the game loop:

```dart
// lib/main.dart
import 'package:fledge_ecs/fledge_ecs.dart';

import 'game_plugin.dart';

void main() async {
  final app = App()
    ..addPlugin(TimePlugin())        // Provides delta time
    ..addPlugin(SimulationPlugin()); // Your game setup

  // Run 5 frames manually
  for (var i = 0; i < 5; i++) {
    print('\n=== Tick $i ===');
    await app.tick();
  }
}
```

## Step 5: Run It

```bash
dart run build_runner build  # Only needed if using annotations
dart run lib/main.dart
```

You should see output showing the entities moving each tick:

```
=== Tick 0 ===
--- Entity Positions ---
Entity 0: Position(1.0, 0.0)
Entity 1: Position(10.0, 6.0)
Entity 2: Position(0.5, 0.5)

=== Tick 1 ===
--- Entity Positions ---
Entity 0: Position(2.0, 0.0)
Entity 1: Position(10.0, 7.0)
Entity 2: Position(1.0, 1.0)
```

## Understanding What Happened

1. **Components** (`Position`, `Velocity`, `Player`) are just data classes decorated with `@component`

2. **Systems** (`movementSystem`, `printPositionsSystem`) are functions that process entities with specific components

3. **Plugins** (`SimulationPlugin`) encapsulate game setup: adding systems and spawning initial entities

4. **App** is the entry point that combines plugins and runs the game loop

5. **TimePlugin** provides the `Time` resource with delta time between frames

## Adding More Features

### Using Commands for Deferred Mutations

When you need to spawn or despawn entities during a system, use Commands. Commands defer mutations until a safe point to avoid invalidating iterators:

```dart
void spawnBulletsSystem(World world) {
  final commands = Commands();

  for (final (_, pos, shooter) in world.query2<Position, Shooter>().iter()) {
    if (shooter.shouldShoot) {
      commands.spawn()
        ..insert(Position(pos.x, pos.y))
        ..insert(Velocity(10, 0))
        ..insert(Bullet());
      shooter.shouldShoot = false;
    }
  }

  // Apply all queued commands after iteration
  commands.apply(world);
}
```

### Filtering Queries

Use `With<T>` and `Without<T>` to filter queries:

```dart-tabs
// @tab Annotations
// Only process entities that have Player component
@system
void playerMovement(World world) {
  for (final (_, pos, vel) in world.query2<Position, Velocity>(
    filter: const With<Player>(),
  ).iter()) {
    // Only player entities
  }
}

// Process all entities except those with Static component
@system
void physicsSystem(World world) {
  for (final (_, pos) in world.query1<Position>(
    filter: const Without<Static>(),
  ).iter()) {
    // All non-static entities
  }
}
// @tab Inheritance
// Only process entities that have Player component
class PlayerMovementSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'playerMovement',
        writes: {ComponentId.of<Position>()},
        reads: {ComponentId.of<Velocity>()},
      );

  @override
  Future<void> run(World world) async {
    for (final (_, pos, vel) in world.query2<Position, Velocity>(
      filter: const With<Player>(),
    ).iter()) {
      // Only player entities
    }
  }
}

// Process all entities except those with Static component
class PhysicsSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'physics',
        writes: {ComponentId.of<Position>()},
      );

  @override
  Future<void> run(World world) async {
    for (final (_, pos) in world.query1<Position>(
      filter: const Without<Static>(),
    ).iter()) {
      // All non-static entities
    }
  }
}
```

## Next Steps

Now that you understand the basics, learn more about:

- [Core Concepts](/docs/getting-started/core-concepts) - Deep dive into ECS architecture
- [Entities & Components](/docs/guides/entities-components) - Advanced component patterns
- [Systems](/docs/guides/systems) - System ordering and stages
