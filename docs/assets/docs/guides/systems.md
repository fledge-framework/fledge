# Systems Guide

This guide covers advanced patterns for writing and organizing systems in Fledge.

## System Basics

Systems are the logic units that process entities. They receive the `World` and create queries inside the function. You can define systems using either annotations or class-based inheritance:

```dart-tabs
// @tab Annotations
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_ecs_annotations/fledge_ecs_annotations.dart';

part 'systems.g.dart';

@system
Future<void> movementSystem(World world) async {
  for (final (entity, pos, vel) in world.query2<Position, Velocity>().iter()) {
    pos.x += vel.dx;
    pos.y += vel.dy;
  }
}
// @tab Inheritance
import 'package:fledge_ecs/fledge_ecs.dart';

class MovementSystem implements System {
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
```

## Alternative System Styles

Beyond the basic `System` interface, Fledge provides convenience classes for common patterns.

### FunctionSystem (Recommended for Simple Systems)

For most systems, `FunctionSystem` is the simplest approach:

```dart
final movementSystem = FunctionSystem(
  'movement',
  writes: {ComponentId.of<Position>()},
  reads: {ComponentId.of<Velocity>()},
  run: (world) {
    for (final (_, pos, vel) in world.query2<Position, Velocity>().iter()) {
      pos.x += vel.dx;
      pos.y += vel.dy;
    }
  },
);

// With run condition
final pausableSystem = FunctionSystem(
  'pausable',
  runIf: (world) => !world.getResource<GameState>()!.isPaused,
  run: (world) { /* ... */ },
);

// With explicit ordering
final physicsSystem = FunctionSystem(
  'physics',
  after: ['input'],
  before: ['render'],
  run: (world) { /* ... */ },
);
```

### SyncSystem (No Async Needed)

For systems that don't need async operations, extend `SyncSystem` to avoid the `Future<void>` boilerplate:

```dart
class MovementSystem extends SyncSystem {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'movement',
        writes: {ComponentId.of<Position>()},
        reads: {ComponentId.of<Velocity>()},
      );

  @override
  void runSync(World world) {
    for (final (_, pos, vel) in world.query2<Position, Velocity>().iter()) {
      pos.x += vel.dx;
      pos.y += vel.dy;
    }
  }
}
```

### When to Use Each Style

| Style | Use When |
|-------|----------|
| `FunctionSystem` | Simple systems, quick prototyping, inline definitions |
| `SyncSystem` | Class-based systems that don't need async |
| `System` interface | Full control, async operations, complex lifecycle |
| `@system` annotation | Code generation preferred, minimal boilerplate |

## System Parameters

### Multiple Queries

Systems can create multiple queries:

```dart-tabs
// @tab Annotations
@system
void combatSystem(World world) {
  final players = world.query2<Position, Health>(filter: const With<Player>());
  final enemies = world.query2<Position, Damage>(filter: const With<Enemy>());

  for (final (playerEntity, playerPos, playerHealth) in players.iter()) {
    for (final (enemyEntity, enemyPos, damage) in enemies.iter()) {
      if (distance(playerPos, enemyPos) < 20) {
        playerHealth.current -= damage.amount;
      }
    }
  }
}
// @tab Inheritance
class CombatSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'combat',
        writes: {ComponentId.of<Health>()},
        reads: {ComponentId.of<Position>(), ComponentId.of<Damage>()},
      );

  @override
  Future<void> run(World world) async {
    final players = world.query2<Position, Health>(filter: const With<Player>());
    final enemies = world.query2<Position, Damage>(filter: const With<Enemy>());

    for (final (playerEntity, playerPos, playerHealth) in players.iter()) {
      for (final (enemyEntity, enemyPos, damage) in enemies.iter()) {
        if (distance(playerPos, enemyPos) < 20) {
          playerHealth.current -= damage.amount;
        }
      }
    }
  }
}
```

### World Access

The `World` parameter provides full access to entities and components:

```dart-tabs
// @tab Annotations
@system
void mySystem(World world) {
  for (final (entity, pos) in world.query1<Position>().iter()) {
    // Check for additional components
    if (world.has<Special>(entity)) {
      // Handle special case
    }
  }
}
// @tab Inheritance
class MySystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'mySystem',
        reads: {ComponentId.of<Position>()},
      );

  @override
  Future<void> run(World world) async {
    for (final (entity, pos) in world.query1<Position>().iter()) {
      // Check for additional components
      if (world.has<Special>(entity)) {
        // Handle special case
      }
    }
  }
}
```

### Commands

For deferred entity mutations, use a Commands buffer that you apply after iteration:

```dart
void spawnerSystem(World world) {
  final commands = Commands();

  for (final (entity, pos, spawner) in world.query2<Position, Spawner>().iter()) {
    if (spawner.timer <= 0) {
      commands.spawn()
        ..insert(Position(pos.x, pos.y))
        ..insert(Enemy());
      spawner.timer = spawner.interval;
    } else {
      spawner.timer -= 1;
    }
  }

  commands.apply(world);
}
```

## System Organization

### By Stage

Organize systems by when they should run:

```dart-tabs
// @tab Annotations
// Input stage - CoreStage.preUpdate
@system
void inputSystem(World world) {
  for (final (_, input) in world.query1<InputReceiver>(filter: const With<Player>()).iter()) {
    // Process player input
  }
}

// Update stage - CoreStage.update (default)
@system
void movementSystem(World world) {
  for (final (_, pos, vel) in world.query2<Position, Velocity>().iter()) {
    // Apply movement
  }
}

// Physics stage - CoreStage.postUpdate
@system
void collisionSystem(World world) {
  for (final (_, pos, collider) in world.query2<Position, Collider>().iter()) {
    // Detect and resolve collisions
  }
}

// Render stage - CoreStage.last
@system
void renderSystem(World world) {
  for (final (_, pos, sprite) in world.query2<Position, Sprite>().iter()) {
    // Draw sprites
  }
}
// @tab Inheritance
// Input stage - CoreStage.preUpdate
class InputSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'input',
        reads: {ComponentId.of<InputReceiver>()},
      );

  @override
  Future<void> run(World world) async {
    for (final (_, input) in world.query1<InputReceiver>(filter: const With<Player>()).iter()) {
      // Process player input
    }
  }
}

// Update stage - CoreStage.update (default)
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
      // Apply movement
    }
  }
}

// Physics stage - CoreStage.postUpdate
class CollisionSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'collision',
        reads: {ComponentId.of<Position>(), ComponentId.of<Collider>()},
      );

  @override
  Future<void> run(World world) async {
    for (final (_, pos, collider) in world.query2<Position, Collider>().iter()) {
      // Detect and resolve collisions
    }
  }
}

// Render stage - CoreStage.last
class RenderSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'render',
        reads: {ComponentId.of<Position>(), ComponentId.of<Sprite>()},
      );

  @override
  Future<void> run(World world) async {
    for (final (_, pos, sprite) in world.query2<Position, Sprite>().iter()) {
      // Draw sprites
    }
  }
}
```

### By Feature

Group related systems together:

```dart-tabs
// @tab Annotations
// combat_systems.dart
@system
void damageSystem(World world) { /* ... */ }

@system
void deathSystem(World world) { /* ... */ }

@system
void healthRegenSystem(World world) { /* ... */ }

// movement_systems.dart
@system
void velocitySystem(World world) { /* ... */ }

@system
void frictionSystem(World world) { /* ... */ }

@system
void boundarySystem(World world) { /* ... */ }
// @tab Inheritance
// combat_systems.dart
class DamageSystem implements System { /* ... */ }
class DeathSystem implements System { /* ... */ }
class HealthRegenSystem implements System { /* ... */ }

// movement_systems.dart
class VelocitySystem implements System { /* ... */ }
class FrictionSystem implements System { /* ... */ }
class BoundarySystem implements System { /* ... */ }
```

## Common Patterns

### Accumulator Pattern

Process all entities to compute a result:

```dart-tabs
// @tab Annotations
@system
void countEnemiesSystem(World world) {
  final stats = world.getResource<GameStats>()!;
  var count = 0;
  for (final _ in world.query1<Enemy>().iter()) {
    count++;
  }
  stats.enemyCount = count;
}
// @tab Inheritance
class CountEnemiesSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'countEnemies',
        resourceWrites: {GameStats},
      );

  @override
  Future<void> run(World world) async {
    final stats = world.getResource<GameStats>()!;
    var count = 0;
    for (final _ in world.query1<Enemy>().iter()) {
      count++;
    }
    stats.enemyCount = count;
  }
}
```

### Pairwise Iteration

Compare entities against each other:

```dart
void collisionDetection(World world) {
  final commands = Commands();
  final entities = world.query2<Position, Collider>().iter().toList();

  for (var i = 0; i < entities.length; i++) {
    for (var j = i + 1; j < entities.length; j++) {
      final (entityA, posA, colA) = entities[i];
      final (entityB, posB, colB) = entities[j];

      if (checkCollision(posA, colA, posB, colB)) {
        commands.insert(entityA, CollisionEvent(entityB));
        commands.insert(entityB, CollisionEvent(entityA));
      }
    }
  }

  commands.apply(world);
}
```

### Singleton Query

Find a specific entity:

```dart-tabs
// @tab Annotations
@system
void playerFollowCamera(World world) {
  final playerQuery = world.query1<Position>(filter: const With<Player>());
  final cameraQuery = world.query1<Position>(filter: const With<Camera>());

  Position? playerPos;
  for (final (_, pos) in playerQuery.iter()) {
    playerPos = pos;
    break;
  }

  if (playerPos == null) return;

  for (final (_, cameraPos) in cameraQuery.iter()) {
    cameraPos.x = playerPos.x;
    cameraPos.y = playerPos.y;
  }
}
// @tab Inheritance
class PlayerFollowCameraSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'playerFollowCamera',
        writes: {ComponentId.of<Position>()},
      );

  @override
  Future<void> run(World world) async {
    final playerQuery = world.query1<Position>(filter: const With<Player>());
    final cameraQuery = world.query1<Position>(filter: const With<Camera>());

    Position? playerPos;
    for (final (_, pos) in playerQuery.iter()) {
      playerPos = pos;
      break;
    }

    if (playerPos == null) return;

    for (final (_, cameraPos) in cameraQuery.iter()) {
      cameraPos.x = playerPos.x;
      cameraPos.y = playerPos.y;
    }
  }
}
```

### State Machine

Use marker components for states:

```dart-tabs
// @tab Annotations
@component class Idle {}
@component class Walking {}
@component class Attacking {}
@component class Dead {}

@system
void idleToWalkTransition(World world) {
  final commands = Commands();

  for (final (entity, _) in world.query1<Idle>(filter: const With<HasInput>()).iter()) {
    commands.remove<Idle>(entity);
    commands.insert(entity, Walking());
  }

  commands.apply(world);
}
// @tab Inheritance
class Idle {}
class Walking {}
class Attacking {}
class Dead {}

class IdleToWalkTransitionSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'idleToWalkTransition',
        reads: {ComponentId.of<Idle>()},
      );

  @override
  Future<void> run(World world) async {
    final commands = Commands();

    for (final (entity, _) in world.query1<Idle>(filter: const With<HasInput>()).iter()) {
      commands.remove<Idle>(entity);
      commands.insert(entity, Walking());
    }

    commands.apply(world);
  }
}
```

## Async Systems

For systems that need async operations, use `AsyncFunctionSystem`:

```dart
final loadAssetsSystem = AsyncFunctionSystem(
  'loadAssets',
  run: (world) async {
    // Async file loading, network requests, etc.
    await loadTextures();
    await loadSounds();
  },
);
```

Or implement the `System` interface directly:

```dart
class LoadAssetsSystem implements System {
  @override
  SystemMeta get meta => const SystemMeta(name: 'loadAssets');

  @override
  Future<void> run(World world) async {
    await loadTextures();
    await loadSounds();
  }
}
```

## Performance Tips

### Minimize Queries

Create queries once per system, not per entity:

```dart-tabs
// @tab Annotations
// Good
@system
void goodSystem(World world) {
  final query = world.query1<Position>();
  for (final entry in query.iter()) { }
}

// Bad
@system
void badSystem(World world) {
  for (var i = 0; i < 100; i++) {
    final query = world.query1<Position>(); // Created 100 times!
  }
}
// @tab Inheritance
// Good
class GoodSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'good',
        reads: {ComponentId.of<Position>()},
      );

  @override
  Future<void> run(World world) async {
    final query = world.query1<Position>();
    for (final entry in query.iter()) { }
  }
}

// Bad
class BadSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'bad',
        reads: {ComponentId.of<Position>()},
      );

  @override
  Future<void> run(World world) async {
    for (var i = 0; i < 100; i++) {
      final query = world.query1<Position>(); // Created 100 times!
    }
  }
}
```

### Early Exit

Skip processing when possible:

```dart-tabs
// @tab Annotations
@system
void optionalSystem(World world) {
  final query = world.query1<RareComponent>();
  if (query.isEmpty) return; // Quick check

  for (final entry in query.iter()) {
    // Process
  }
}
// @tab Inheritance
class OptionalSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'optional',
        reads: {ComponentId.of<RareComponent>()},
      );

  @override
  Future<void> run(World world) async {
    final query = world.query1<RareComponent>();
    if (query.isEmpty) return; // Quick check

    for (final entry in query.iter()) {
      // Process
    }
  }
}
```

### Batch Operations

Group related operations:

```dart
void batchSpawner(World world) {
  final commands = Commands();

  // Queue all spawns at once
  for (var i = 0; i < 100; i++) {
    commands.spawn()..insert(Enemy());
  }

  // All commands are applied together
  commands.apply(world);
}
```

## See Also

- [Queries](/docs/guides/queries) - Query patterns
- [Scheduling](/docs/guides/scheduling) - System ordering
- [System API](/docs/api/system) - System reference
