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
// @tab Classes
import 'package:fledge_ecs/fledge_ecs.dart';

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
```

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
// @tab FunctionSystem
final combatSystem = FunctionSystem(
  'combat',
  writes: {ComponentId.of<Health>()},
  reads: {ComponentId.of<Position>(), ComponentId.of<Damage>()},
  run: (world) {
    final players = world.query2<Position, Health>(filter: const With<Player>());
    final enemies = world.query2<Position, Damage>(filter: const With<Enemy>());

    for (final (playerEntity, playerPos, playerHealth) in players.iter()) {
      for (final (enemyEntity, enemyPos, damage) in enemies.iter()) {
        if (distance(playerPos, enemyPos) < 20) {
          playerHealth.current -= damage.amount;
        }
      }
    }
  },
);
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
// @tab FunctionSystem
final mySystem = FunctionSystem(
  'mySystem',
  reads: {ComponentId.of<Position>()},
  run: (world) {
    for (final (entity, pos) in world.query1<Position>().iter()) {
      // Check for additional components
      if (world.has<Special>(entity)) {
        // Handle special case
      }
    }
  },
);
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
// @tab FunctionSystem
// Input stage - CoreStage.preUpdate
final inputSystem = FunctionSystem(
  'input',
  reads: {ComponentId.of<InputReceiver>()},
  run: (world) {
    for (final (_, input) in world.query1<InputReceiver>(filter: const With<Player>()).iter()) {
      // Process player input
    }
  },
);

// Update stage - CoreStage.update (default)
final movementSystem = FunctionSystem(
  'movement',
  writes: {ComponentId.of<Position>()},
  reads: {ComponentId.of<Velocity>()},
  run: (world) {
    for (final (_, pos, vel) in world.query2<Position, Velocity>().iter()) {
      // Apply movement
    }
  },
);

// Physics stage - CoreStage.postUpdate
final collisionSystem = FunctionSystem(
  'collision',
  reads: {ComponentId.of<Position>(), ComponentId.of<Collider>()},
  run: (world) {
    for (final (_, pos, collider) in world.query2<Position, Collider>().iter()) {
      // Detect and resolve collisions
    }
  },
);

// Render stage - CoreStage.last
final renderSystem = FunctionSystem(
  'render',
  reads: {ComponentId.of<Position>(), ComponentId.of<Sprite>()},
  run: (world) {
    for (final (_, pos, sprite) in world.query2<Position, Sprite>().iter()) {
      // Draw sprites
    }
  },
);
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
// @tab FunctionSystem
// combat_systems.dart
final damageSystem = FunctionSystem('damage', run: (world) { /* ... */ });
final deathSystem = FunctionSystem('death', run: (world) { /* ... */ });
final healthRegenSystem = FunctionSystem('healthRegen', run: (world) { /* ... */ });

// movement_systems.dart
final velocitySystem = FunctionSystem('velocity', run: (world) { /* ... */ });
final frictionSystem = FunctionSystem('friction', run: (world) { /* ... */ });
final boundarySystem = FunctionSystem('boundary', run: (world) { /* ... */ });
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
// @tab FunctionSystem
final countEnemiesSystem = FunctionSystem(
  'countEnemies',
  resourceWrites: {GameStats},
  run: (world) {
    final stats = world.getResource<GameStats>()!;
    var count = 0;
    for (final _ in world.query1<Enemy>().iter()) {
      count++;
    }
    stats.enemyCount = count;
  },
);
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
// @tab FunctionSystem
final playerFollowCamera = FunctionSystem(
  'playerFollowCamera',
  writes: {ComponentId.of<Position>()},
  run: (world) {
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
  },
);
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
// @tab Plain Classes / FunctionSystem
class Idle {}
class Walking {}
class Attacking {}
class Dead {}

final idleToWalkTransition = FunctionSystem(
  'idleToWalkTransition',
  reads: {ComponentId.of<Idle>()},
  run: (world) {
    final commands = Commands();

    for (final (entity, _) in world.query1<Idle>(filter: const With<HasInput>()).iter()) {
      commands.remove<Idle>(entity);
      commands.insert(entity, Walking());
    }

    commands.apply(world);
  },
);
```

## Async Systems

For systems that need async operations:

```dart
final loadAssetsSystem = AsyncFunctionSystem(
  (World world) async {
    // Async file loading, network requests, etc.
    await loadTextures();
    await loadSounds();
  },
  meta: SystemMeta(name: 'loadAssets'),
);
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
// @tab FunctionSystem
// Good
final goodSystem = FunctionSystem(
  'good',
  reads: {ComponentId.of<Position>()},
  run: (world) {
    final query = world.query1<Position>();
    for (final entry in query.iter()) { }
  },
);

// Bad
final badSystem = FunctionSystem(
  'bad',
  reads: {ComponentId.of<Position>()},
  run: (world) {
    for (var i = 0; i < 100; i++) {
      final query = world.query1<Position>(); // Created 100 times!
    }
  },
);
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
// @tab FunctionSystem
final optionalSystem = FunctionSystem(
  'optional',
  reads: {ComponentId.of<RareComponent>()},
  run: (world) {
    final query = world.query1<RareComponent>();
    if (query.isEmpty) return; // Quick check

    for (final entry in query.iter()) {
      // Process
    }
  },
);
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
