# Systems

Systems hold your game logic. Each one is an object with a `run(World world)`
method and a `SystemMeta` that names it and declares what data it touches. You
register systems in a [schedule](/docs/scheduling/schedules), and the scheduler
runs them every frame in a dependency-respecting order.

<!-- snippet-setup
class Position {
  double x, y;
  Position(this.x, this.y);
}

class Velocity {
  double dx, dy;
  Velocity(this.dx, this.dy);
}

class Acceleration {
  double ax, ay;
  Acceleration(this.ax, this.ay);
}

class Friction {
  final double factor;
  Friction(this.factor);
}

class MaxSpeed {
  final double value;
  MaxSpeed(this.value);
}

class Bullet {}

class Lifetime {
  double seconds;
  Lifetime(this.seconds);
}

class GameConfig {
  bool paused = false;
}

class Score {
  int points = 0;
}
-->

## Writing a system

The usual form is a class that `extends System`:

```dart
class MovementSystem extends System {
  static const String systemName = 'movement';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    reads: {ComponentId.of<Velocity>()},
    writes: {ComponentId.of<Position>()},
    resourceReads: {WallTime},
  );

  @override
  void run(World world) {
    final dt = world.getResource<WallTime>()?.delta ?? 0;
    for (final (_, pos, vel) in world.query2<Position, Velocity>().iter()) {
      pos.x += vel.dx * dt;
      pos.y += vel.dy * dt;
    }
  }
}

void main() {
  final app = App()
    ..addPlugin(WallTimePlugin())
    ..addSystem(MovementSystem(), schedule: Schedules.update);
}
```

`extends System` gives you the default `runCondition` (none) and `shouldRun`.
If you `implements System` instead, you must write `meta`, `runCondition`,
`shouldRun` and `run` yourself.

### The `systemName` convention

Give every system other code may order against a `static const String
systemName`, use it in `SystemMeta(name: systemName)`, and reference the
constant (never a string literal) in `before:`/`after:`:

```dart
class SteeringSystem extends System {
  static const String systemName = 'steering';

  @override
  SystemMeta get meta =>
      SystemMeta(name: systemName, writes: {ComponentId.of<Velocity>()});

  @override
  void run(World world) {}
}

class ApplyVelocitySystem extends System {
  static const String systemName = 'applyVelocity';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    reads: {ComponentId.of<Velocity>()},
    writes: {ComponentId.of<Position>()},
    after: [SteeringSystem.systemName],
  );

  @override
  void run(World world) {}
}
```

All built-in Fledge systems follow this pattern. See
[Ordering & Sets](/docs/scheduling/ordering-and-sets).

## `FunctionSystem`

For small systems, `FunctionSystem` takes the name first and the body as
`run:`. Every `SystemMeta` field is a named parameter, plus `runIf:` for a
[run condition](/docs/ecs/states-run-conditions):

```dart
final friction = FunctionSystem(
  'friction',
  reads: {ComponentId.of<Friction>()},
  writes: {ComponentId.of<Velocity>()},
  runIf: (world) => !(world.getResource<GameConfig>()?.paused ?? false),
  run: (world) {
    for (final (_, vel, f) in world.query2<Velocity, Friction>().iter()) {
      vel.dx *= f.factor;
      vel.dy *= f.factor;
    }
  },
);

final app = App()
  ..insertResource(GameConfig())
  ..addSystem(friction, schedule: Schedules.fixedUpdate);
```

`SyncSystem` is also exported: extend it and implement `runSync` instead of
`run`. It adds nothing over `extends System` with a `void run`.

## `SystemMeta`

| Field | Meaning |
|---|---|
| `name` | Display name, and the handle for `before:`/`after:` |
| `reads` / `writes` | Component types, as `ComponentId.of<T>()` |
| `resourceReads` / `resourceWrites` | Resource types, e.g. `{WallTime}` |
| `eventReads` / `eventWrites` | Event types |
| `exclusive` | Conflicts with every other system in its schedule |
| `before` / `after` | Names of systems or sets this one must precede / follow |
| `sets` | Names of the [system sets](/docs/scheduling/ordering-and-sets#system-sets) it joins |

Access declarations don't restrict what `run` can do (it gets the whole
world). They feed the scheduler: two systems in the same schedule **conflict**
when one writes something the other reads or writes. Conflicting systems
without an explicit `before`/`after` between them run in registration order,
and `App.checkScheduleOrdering()` reports each such pair. Declare access
honestly, then make the order explicit (see
[Ordering & Sets](/docs/scheduling/ordering-and-sets)).

## How systems run

Dart runs your game on one isolate, so the scheduler runs systems **one at a
time**. Within a schedule the order is computed once from the dependency graph
(explicit `before`/`after`, sets, then registration order for conflicting
pairs) and reused every frame.

### Keep systems synchronous

`System.run` returns `FutureOr<void>`. A synchronous system declares
`void run(World world)` and the next system starts immediately. A system that
returns a `Future` is awaited before the next one starts, and an `async`
method always costs a trip through the event loop, even when it awaits
nothing. Make systems synchronous unless they truly wait.

Never await platform I/O (file reads, asset loads, network) inside a system:
the whole frame stalls until it finishes. Start the work in the background and
pick up the result on a later frame:

```dart
class SaveFile {
  Future<String>? pending;
  String? contents;
}

class LoadSaveSystem extends System {
  static const String systemName = 'loadSave';

  @override
  SystemMeta get meta =>
      SystemMeta(name: systemName, resourceWrites: {SaveFile});

  @override
  void run(World world) {
    final save = world.getResource<SaveFile>();
    if (save == null || save.contents != null || save.pending != null) return;
    // Started once; the future completes on its own, between frames.
    save.pending = Future.value('{"level": 3}') // e.g. File(...).readAsString()
      ..then((text) => save.contents = text);
  }
}
```

`AsyncFunctionSystem('name', run: (world) async { ... })` exists for the rare
system that must finish an await before the next system runs. The frame waits
for it, so it isn't for slow I/O.

## Structural changes: Commands

Spawning and despawning inside a query loop is safe (queries snapshot their
matches), but the clean pattern is to queue changes on a
[`Commands`](/docs/ecs/commands) buffer and apply it when the loop is done:

```dart
class LifetimeSystem extends System {
  static const String systemName = 'lifetime';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    writes: {ComponentId.of<Lifetime>()},
    resourceReads: {WallTime},
  );

  @override
  void run(World world) {
    final dt = world.getResource<WallTime>()?.delta ?? 0;
    final commands = Commands();
    for (final (entity, life) in world.query1<Lifetime>().iter()) {
      life.seconds -= dt;
      if (life.seconds <= 0) commands.despawn(entity);
    }
    commands.apply(world);
  }
}
```

## A movement pipeline

Several systems that all write `Velocity` conflict with each other. Chain them
explicitly so the order is part of the code, not an accident of registration:

```dart
class AccelerationSystem extends System {
  static const String systemName = 'acceleration';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    reads: {ComponentId.of<Acceleration>()},
    writes: {ComponentId.of<Velocity>()},
  );

  @override
  void run(World world) {
    for (final (_, vel, acc) in world.query2<Velocity, Acceleration>().iter()) {
      vel.dx += acc.ax;
      vel.dy += acc.ay;
    }
  }
}

class SpeedLimitSystem extends System {
  static const String systemName = 'speedLimit';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    reads: {ComponentId.of<MaxSpeed>()},
    writes: {ComponentId.of<Velocity>()},
    after: [AccelerationSystem.systemName],
  );

  @override
  void run(World world) {
    for (final (_, vel, max) in world.query2<Velocity, MaxSpeed>().iter()) {
      final speed = math.sqrt(vel.dx * vel.dx + vel.dy * vel.dy);
      if (speed > max.value) {
        vel.dx *= max.value / speed;
        vel.dy *= max.value / speed;
      }
    }
  }
}

class IntegrateSystem extends System {
  static const String systemName = 'integrate';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    reads: {ComponentId.of<Velocity>()},
    writes: {ComponentId.of<Position>()},
    resourceReads: {FixedTimestep},
    after: [SpeedLimitSystem.systemName],
  );

  @override
  void run(World world) {
    final dt = world.getResource<FixedTimestep>()!.stepSeconds;
    for (final (_, pos, vel) in world.query2<Position, Velocity>().iter()) {
      pos.x += vel.dx * dt;
      pos.y += vel.dy * dt;
    }
  }
}

class MovementPlugin extends Plugin {
  @override
  void build(App app) {
    app
      ..addSystem(IntegrateSystem(), schedule: Schedules.fixedUpdate)
      ..addSystem(SpeedLimitSystem(), schedule: Schedules.fixedUpdate)
      ..addSystem(AccelerationSystem(), schedule: Schedules.fixedUpdate);
  }
}
```

The registration order in `MovementPlugin` is deliberately backwards: the
`after:` edges still run acceleration, then the speed limit, then integration.
The pipeline lives in `fixedUpdate` and steps by `FixedTimestep.stepSeconds`,
so it behaves the same at any frame rate (see
[Time & Fixed Timestep](/docs/scheduling/time)).

## Generated systems

With `fledge_ecs_generator`, an `@system` function declares its data through
its parameter types (`Query2<A, B>` reads, `QueryMut1<A>` writes, `Res<T>`,
`ResMut<T>`, `EventReader<T>`, `EventWriter<T>`, `Commands`), and the
generator writes a `XWrapper` class with the matching `SystemMeta` and a
`systemName`. You register the wrapper, never the function:

```dart fragment
@system
void gravity(QueryMut1<Velocity> query, Res<FixedTimestep> step) {
  for (final (_, vel) in query.iter()) {
    vel.dy += 9.8 * step.value.stepSeconds;
  }
}

app.addSystem(GravityWrapper(), schedule: Schedules.fixedUpdate);
```

`@system` can't set a schedule or `before`/`after`; pass those at registration
or hand-write a class. Details are on [Code Generation](/docs/app/codegen).

## Testing a system

A system is a plain object, so a test can build a `World` and call `run`:

```dart
final world = World()..insertResource(Score());
final award = FunctionSystem(
  'award',
  resourceWrites: {Score},
  run: (world) => world.getResource<Score>()!.points += 10,
);

award.run(world);
assert(world.getResource<Score>()!.points == 10);
```

To exercise ordering, run conditions and change detection the way a game does,
build an `App` and call `await app.tick()`.

## See also

- [Queries](/docs/ecs/queries)
- [Commands](/docs/ecs/commands)
- [Schedules & the Frame](/docs/scheduling/schedules)
- [Ordering & Sets](/docs/scheduling/ordering-and-sets)
