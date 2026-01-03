# Basic ECS Example

A complete example demonstrating core ECS concepts. This example shows both annotation-based and class-based approaches.

## Project Setup

```yaml-tabs
// @tab Annotations
# pubspec.yaml
dependencies:
  fledge_ecs: ^0.1.0
  fledge_ecs_annotations: ^0.1.0

dev_dependencies:
  build_runner: ^2.4.0
  fledge_ecs_generator: ^0.1.0
// @tab Inheritance
# pubspec.yaml
dependencies:
  fledge_ecs: ^0.1.0
```

## Components

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

@component
class Player {}

@component
class Enemy {}
// @tab Inheritance
// lib/components.dart
import 'package:fledge_ecs/fledge_ecs.dart';

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

class Player {}

class Enemy {}
```

## Systems

```dart-tabs
// @tab Annotations
// lib/systems.dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_ecs_annotations/fledge_ecs_annotations.dart';

import 'components.dart';

part 'systems.g.dart';

@system
Future<void> movementSystem(World world) async {
  for (final (entity, pos, vel) in world.query2<Position, Velocity>().iter()) {
    pos.x += vel.dx;
    pos.y += vel.dy;
  }
}

@system
Future<void> printPositionsSystem(World world) async {
  for (final (entity, pos) in world.query1<Position>().iter()) {
    print('Entity ${entity.id}: $pos');
  }
}
// @tab Inheritance
// lib/systems.dart
import 'package:fledge_ecs/fledge_ecs.dart';

import 'components.dart';

class MovementSystem extends System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'movement',
        writes: {ComponentId.of<Position>()},
        reads: {ComponentId.of<Velocity>()},
      );

  @override
  Future<void> run(World world) async {
    for (final (entity, pos, vel) in world.query2<Position, Velocity>().iter()) {
      pos.x += vel.dx;
      pos.y += vel.dy;
    }
  }
}

class PrintPositionsSystem extends System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'print_positions',
        reads: {ComponentId.of<Position>()},
      );

  @override
  Future<void> run(World world) async {
    for (final (entity, pos) in world.query1<Position>().iter()) {
      print('Entity ${entity.id}: $pos');
    }
  }
}
```

## Game Plugin

```dart-tabs
// @tab Annotations
// lib/game_plugin.dart
import 'package:fledge_ecs/fledge_ecs.dart';

import 'components.dart';
import 'systems.g.dart';

class GamePlugin implements Plugin {
  @override
  void build(App app) {
    // Add annotation-generated systems (functions)
    app
      .addSystem(movementSystem)
      .addSystem(printPositionsSystem);

    // Spawn player
    app.world.spawn()
      ..insert(Position(0, 0))
      ..insert(Velocity(1, 0))
      ..insert(Player());

    // Spawn enemies
    for (var i = 0; i < 3; i++) {
      app.world.spawn()
        ..insert(Position(i * 10.0, 0))
        ..insert(Velocity(-0.5, 0))
        ..insert(Enemy());
    }
  }

  @override
  void cleanup() {}
}
// @tab Inheritance
// lib/game_plugin.dart
import 'package:fledge_ecs/fledge_ecs.dart';

import 'components.dart';
import 'systems.dart';

class GamePlugin implements Plugin {
  @override
  void build(App app) {
    // Add class-based systems (instantiated)
    app
      .addSystem(MovementSystem())
      .addSystem(PrintPositionsSystem());

    // Spawn player
    app.world.spawn()
      ..insert(Position(0, 0))
      ..insert(Velocity(1, 0))
      ..insert(Player());

    // Spawn enemies
    for (var i = 0; i < 3; i++) {
      app.world.spawn()
        ..insert(Position(i * 10.0, 0))
        ..insert(Velocity(-0.5, 0))
        ..insert(Enemy());
    }
  }

  @override
  void cleanup() {}
}
```

## Main Application

```dart
// lib/main.dart
import 'package:fledge_ecs/fledge_ecs.dart';

import 'game_plugin.dart';

void main() async {
  final app = App()
    ..addPlugin(TimePlugin())
    ..addPlugin(GamePlugin());

  // Game loop - run 5 frames
  for (var tick = 0; tick < 5; tick++) {
    print('\n=== Tick $tick ===');
    await app.tick();
  }
}
```

## Running

```bash-tabs
// @tab Annotations
dart run build_runner build
dart run lib/main.dart
// @tab Inheritance
dart run lib/main.dart
```

## Output

```
=== Tick 0 ===
Entity 0: Position(1.0, 0.0)
Entity 1: Position(9.5, 0.0)
Entity 2: Position(19.5, 0.0)
Entity 3: Position(29.5, 0.0)

=== Tick 1 ===
Entity 0: Position(2.0, 0.0)
Entity 1: Position(9.0, 0.0)
...
```

## Key Concepts Demonstrated

1. **Component definition** - Plain classes or `@component` annotation
2. **System definition** - Class-based (`extends System`) or `@system` annotation
3. **Plugin** to encapsulate game setup
4. **App builder** as the entry point
5. **Entity spawning** with `app.world.spawn()`
6. **Query iteration** with destructuring
7. **TimePlugin** for delta time tracking
