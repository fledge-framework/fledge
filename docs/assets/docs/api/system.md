# System API Reference

Systems contain game logic that processes entities and components.

## Import

```dart-tabs
// @tab Annotations
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_ecs_annotations/fledge_ecs_annotations.dart';
// @tab Classes
import 'package:fledge_ecs/fledge_ecs.dart';
```

## Defining Systems

```dart-tabs
// @tab Annotations
// Use the @system annotation on a function
@system
Future<void> movementSystem(World world) async {
  for (final (entity, pos, vel) in world.query2<Position, Velocity>().iter()) {
    pos.x += vel.dx;
    pos.y += vel.dy;
  }
}

// After running `build_runner`, use the generated function:
// app.addSystem(movementSystem);
// @tab Classes
// Implement the System interface
class MovementSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'movement',
        writes: {ComponentId.of<Position>()},
        reads: {ComponentId.of<Velocity>()},
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => runCondition?.call(world) ?? true;

  @override
  Future<void> run(World world) async {
    for (final (entity, pos, vel) in world.query2<Position, Velocity>().iter()) {
      pos.x += vel.dx;
      pos.y += vel.dy;
    }
  }
}

// Add to app:
// app.addSystem(MovementSystem());
```

## System Interface

```dart
abstract class System {
  SystemMeta get meta;
  RunCondition? get runCondition => null;
  Future<void> run(World world);
  bool shouldRun(World world) => runCondition?.call(world) ?? true;
}
```

### SystemMeta

Contains metadata about what a system reads and writes:

```dart
class SystemMeta {
  final String name;
  final Set<ComponentId> reads;
  final Set<ComponentId> writes;
  final Set<Type> resourceReads;
  final Set<Type> resourceWrites;
}
```

## System Parameters

Systems can receive various parameters:

### World Parameter

The `World` parameter provides access to entities, components, resources, and queries:

```dart
@system
void mySystem(World world) {
  // Create queries
  final positions = world.query1<Position>();
  final enemies = world.query2<Health, Enemy>();

  // Direct world access
  final entity = world.spawnWith([Position(0, 0)]);
}
```

### Using Commands

Use `Commands` for deferred entity mutations. Create a Commands buffer, queue operations, then apply:

```dart
void spawnerSystem(World world) {
  final commands = Commands();

  for (final (entity, spawner) in world.query1<Spawner>().iter()) {
    if (spawner.shouldSpawn) {
      commands.spawn()
        ..insert(Position(spawner.x, spawner.y))
        ..insert(Enemy());
    }
  }

  commands.apply(world);
}
```

## Function Systems

Create systems without code generation:

```dart
// Simple function system
final mySystem = FunctionSystem(
  'mySystem',
  writes: {ComponentId.of<Position>()},
  reads: {ComponentId.of<Velocity>()},
  run: (World world) {
    final query = world.query2<Position, Velocity>();
    for (final (entity, pos, vel) in query.iter()) {
      pos.x += vel.dx;
    }
  },
);

// With run condition
final conditionalSystem = FunctionSystem(
  'conditionalSystem',
  runIf: (world) => world.getResource<GameState>()?.isPlaying ?? false,
  run: (world) {
    // Only runs when game is playing
  },
);
```

## Async Systems

For systems that need async operations:

```dart
final asyncSystem = AsyncFunctionSystem(
  'asyncSystem',
  run: (World world) async {
    // Async operations allowed
    await Future.delayed(Duration(milliseconds: 16));

    final query = world.query1<Position>();
    for (final (entity, pos) in query.iter()) {
      // Process
    }
  },
);
```

## System Stages

Add systems to specific stages:

```dart
final schedule = Schedule();

schedule.addSystem(inputSystem, stage: CoreStage.preUpdate);
schedule.addSystem(movementSystem, stage: CoreStage.update);
schedule.addSystem(collisionSystem, stage: CoreStage.postUpdate);
schedule.addSystem(renderSystem, stage: CoreStage.last);
```

### Stage Order

1. `CoreStage.first` - Runs before everything
2. `CoreStage.preUpdate` - Input, event processing
3. `CoreStage.update` - Main game logic (default)
4. `CoreStage.postUpdate` - Physics, collision
5. `CoreStage.last` - Rendering, cleanup

## Parallel Execution

Systems that don't conflict run in parallel:

```dart
// These can run in parallel (different components)
@system
void systemA(World world) {
  for (final (_, pos) in world.query1<Position>().iter()) { }
}

@system
void systemB(World world) {
  for (final (_, health) in world.query1<Health>().iter()) { }
}

// These must run sequentially (both write Position)
@system
void systemC(World world) {
  for (final (_, pos) in world.query1<Position>().iter()) { }
}

@system
void systemD(World world) {
  for (final (_, pos) in world.query1<Position>().iter()) { }
}
```

## Best Practices

### Keep Systems Focused

```dart
// Bad - does too much
@system
void gameSystem(World world) {
  // Movement, Collision, Damage, Death, Spawning - too much!
}

// Good - single responsibility
@system
void movementSystem(World world) {
  for (final (_, pos, vel) in world.query2<Position, Velocity>().iter()) { }
}

@system
void collisionSystem(World world) {
  for (final (_, pos, col) in world.query2<Position, Collider>().iter()) { }
}

@system
void damageSystem(World world) {
  for (final (_, health) in world.query1<Health>().iter()) { }
}
```

### Use Commands for Mutations

```dart
// Bad - modifying world during iteration can cause issues
void badSystem(World world) {
  for (final (entity, spawner) in world.query1<Spawner>().iter()) {
    world.spawn(); // Don't do this!
  }
}

// Good - use deferred commands
void goodSystem(World world) {
  final commands = Commands();

  for (final (entity, spawner) in world.query1<Spawner>().iter()) {
    commands.spawn()..insert(NewEntity()); // Queued
  }

  commands.apply(world); // Applied after iteration
}
```

## See Also

- [Schedule](/docs/api/schedule) - System execution order
- [Query](/docs/api/query) - Querying entities
- [Commands](/docs/api/commands) - Deferred mutations
