# Movement System Example

A physics-based movement system with velocity and acceleration.

## Components

```dart-tabs
// @tab Annotations
import 'package:fledge_ecs_annotations/fledge_ecs_annotations.dart';

part 'components.g.dart';

@component
class Position {
  double x, y;
  Position(this.x, this.y);
}

@component
class Velocity {
  double dx, dy;
  Velocity([this.dx = 0, this.dy = 0]);
}

@component
class Acceleration {
  double ax, ay;
  Acceleration([this.ax = 0, this.ay = 0]);
}

@component
class Friction {
  double factor;
  Friction([this.factor = 0.98]);
}

@component
class MaxSpeed {
  double value;
  MaxSpeed(this.value);
}
// @tab Classes
class Position {
  double x, y;
  Position(this.x, this.y);
}

class Velocity {
  double dx, dy;
  Velocity([this.dx = 0, this.dy = 0]);
}

class Acceleration {
  double ax, ay;
  Acceleration([this.ax = 0, this.ay = 0]);
}

class Friction {
  double factor;
  Friction([this.factor = 0.98]);
}

class MaxSpeed {
  double value;
  MaxSpeed(this.value);
}
```

## Systems

```dart-tabs
// @tab Annotations
import 'dart:math';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_ecs_annotations/fledge_ecs_annotations.dart';

part 'systems.g.dart';

@system
Future<void> accelerationSystem(World world) async {
  for (final (_, vel, acc) in world.query2<Velocity, Acceleration>().iter()) {
    vel.dx += acc.ax;
    vel.dy += acc.ay;
  }
}

@system
Future<void> frictionSystem(World world) async {
  for (final (_, vel, friction) in world.query2<Velocity, Friction>().iter()) {
    vel.dx *= friction.factor;
    vel.dy *= friction.factor;
  }
}

@system
Future<void> speedLimitSystem(World world) async {
  for (final (_, vel, maxSpeed) in world.query2<Velocity, MaxSpeed>().iter()) {
    final speed = sqrt(vel.dx * vel.dx + vel.dy * vel.dy);
    if (speed > maxSpeed.value) {
      final scale = maxSpeed.value / speed;
      vel.dx *= scale;
      vel.dy *= scale;
    }
  }
}

@system
Future<void> movementSystem(World world) async {
  for (final (_, pos, vel) in world.query2<Position, Velocity>().iter()) {
    pos.x += vel.dx;
    pos.y += vel.dy;
  }
}
// @tab Classes
import 'dart:math';

import 'package:fledge_ecs/fledge_ecs.dart';

class AccelerationSystem extends System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'acceleration',
        writes: {ComponentId.of<Velocity>()},
        reads: {ComponentId.of<Acceleration>()},
      );

  @override
  Future<void> run(World world) async {
    for (final (_, vel, acc) in world.query2<Velocity, Acceleration>().iter()) {
      vel.dx += acc.ax;
      vel.dy += acc.ay;
    }
  }
}

class FrictionSystem extends System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'friction',
        writes: {ComponentId.of<Velocity>()},
        reads: {ComponentId.of<Friction>()},
      );

  @override
  Future<void> run(World world) async {
    for (final (_, vel, friction) in world.query2<Velocity, Friction>().iter()) {
      vel.dx *= friction.factor;
      vel.dy *= friction.factor;
    }
  }
}

class SpeedLimitSystem extends System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'speed_limit',
        writes: {ComponentId.of<Velocity>()},
        reads: {ComponentId.of<MaxSpeed>()},
      );

  @override
  Future<void> run(World world) async {
    for (final (_, vel, maxSpeed) in world.query2<Velocity, MaxSpeed>().iter()) {
      final speed = sqrt(vel.dx * vel.dx + vel.dy * vel.dy);
      if (speed > maxSpeed.value) {
        final scale = maxSpeed.value / speed;
        vel.dx *= scale;
        vel.dy *= scale;
      }
    }
  }
}

class MovementSystem extends System {
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
```

## Plugin Setup

```dart-tabs
// @tab Annotations
import 'package:fledge_ecs/fledge_ecs.dart';

import 'systems.g.dart';

class PhysicsPlugin implements Plugin {
  @override
  void build(App app) {
    // Physics order matters!
    app
      .addSystem(accelerationSystem)
      .addSystem(frictionSystem)
      .addSystem(speedLimitSystem)
      .addSystem(movementSystem);
  }

  @override
  void cleanup() {}
}

void main() async {
  await App()
    .addPlugin(TimePlugin())
    .addPlugin(PhysicsPlugin())
    .run();
}
// @tab Classes
import 'package:fledge_ecs/fledge_ecs.dart';

import 'systems.dart';

class PhysicsPlugin implements Plugin {
  @override
  void build(App app) {
    // Physics order matters!
    app
      .addSystem(AccelerationSystem())
      .addSystem(FrictionSystem())
      .addSystem(SpeedLimitSystem())
      .addSystem(MovementSystem());
  }

  @override
  void cleanup() {}
}

void main() async {
  await App()
    .addPlugin(TimePlugin())
    .addPlugin(PhysicsPlugin())
    .run();
}
```
