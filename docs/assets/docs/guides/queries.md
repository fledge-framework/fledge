# Queries Guide

This guide covers advanced query patterns and optimization techniques.

## Query Basics

Queries iterate over entities that have specific components:

```dart
final query = world.query2<Position, Velocity>();

for (final (entity, pos, vel) in query.iter()) {
  pos.x += vel.dx;
  pos.y += vel.dy;
}
```

## Filter Patterns

### Include Filter (With)

Match entities that have an additional component:

```dart
// Entities with Position AND Player
final playerPositions = world.query1<Position>(filter: const With<Player>());

// Entities with Position, Velocity, AND Enemy
final enemyMovement = world.query2<Position, Velocity>(filter: const With<Enemy>());
```

### Exclude Filter (Without)

Match entities that don't have a component:

```dart
// Entities with Position but NOT Static
final dynamicEntities = world.query1<Position>(filter: const Without<Static>());

// Alive enemies (have Health, don't have Dead)
final aliveEnemies = world.query1<Health>(filter: And([With<Enemy>(), Without<Dead>()]));
```

### Combining Filters

```dart
// Player entities that are alive and can move
final activePlayer = world.query2<Position, Velocity>(
  filter: And([With<Player>(), Without<Dead>(), Without<Stunned>()]),
);
```

## Query Utilities

### Check Empty

```dart
final enemies = world.query1<Enemy>();
if (enemies.isEmpty) {
  // Level complete!
}
```

### Count Entities

```dart
final count = world.query1<Enemy>().count();
print('Enemies remaining: $count');
```

### Find First

```dart
Position? findPlayer(World world) {
  for (final (_, pos) in world.query1<Position>(filter: const With<Player>()).iter()) {
    return pos;
  }
  return null;
}
```

### Collect All

```dart
List<Entity> getAllEnemies(World world) {
  return [
    for (final (entity, _) in world.query1<Enemy>().iter())
      entity
  ];
}
```

## Performance Optimization

### Query Caching

Queries cache their archetype matches. Reuse queries when possible:

```dart-tabs
// @tab Annotations
// Good - query created once
@system
void goodSystem(World world) {
  final query = world.query2<Position, Velocity>();
  for (final entry in query.iter()) { }
  // Can iterate again with cached archetype info
  for (final entry in query.iter()) { }
}
// @tab FunctionSystem
// Good - query created once
final goodSystem = FunctionSystem(
  'good',
  reads: {ComponentId.of<Position>(), ComponentId.of<Velocity>()},
  run: (world) {
    final query = world.query2<Position, Velocity>();
    for (final entry in query.iter()) { }
    // Can iterate again with cached archetype info
    for (final entry in query.iter()) { }
  },
);
```

### Specific Filters

Use filters to reduce iteration:

```dart-tabs
// @tab Annotations
// Less efficient - checks every entity
@system
void lessEfficient(World world) {
  for (final (entity, pos) in world.query1<Position>().iter()) {
    if (world.has<Player>(entity)) {
      // Only 1 player among thousands of entities
    }
  }
}

// More efficient - only iterates player entities
@system
void moreEfficient(World world) {
  for (final (entity, pos) in world.query1<Position>(filter: const With<Player>()).iter()) {
    // Directly iterates players only
  }
}
// @tab FunctionSystem
// Less efficient - checks every entity
final lessEfficient = FunctionSystem(
  'lessEfficient',
  reads: {ComponentId.of<Position>()},
  run: (world) {
    for (final (entity, pos) in world.query1<Position>().iter()) {
      if (world.has<Player>(entity)) {
        // Only 1 player among thousands of entities
      }
    }
  },
);

// More efficient - only iterates player entities
final moreEfficient = FunctionSystem(
  'moreEfficient',
  reads: {ComponentId.of<Position>()},
  run: (world) {
    for (final (entity, pos) in world.query1<Position>(filter: const With<Player>()).iter()) {
      // Directly iterates players only
    }
  },
);
```

## Common Patterns

### Multi-Query Systems

```dart-tabs
// @tab Annotations
@system
void interactionSystem(World world) {
  final players = world.query2<Position, Player>();
  final items = world.query2<Position, Item>();

  for (final (playerEntity, playerPos, _) in players.iter()) {
    for (final (itemEntity, itemPos, _) in items.iter()) {
      if (distance(playerPos, itemPos) < 32) {
        // Player can pick up item
      }
    }
  }
}
// @tab FunctionSystem
final interactionSystem = FunctionSystem(
  'interaction',
  reads: {ComponentId.of<Position>(), ComponentId.of<Player>(), ComponentId.of<Item>()},
  run: (world) {
    final players = world.query2<Position, Player>();
    final items = world.query2<Position, Item>();

    for (final (playerEntity, playerPos, _) in players.iter()) {
      for (final (itemEntity, itemPos, _) in items.iter()) {
        if (distance(playerPos, itemPos) < 32) {
          // Player can pick up item
        }
      }
    }
  },
);
```

### Conditional Processing

```dart
void healthSystem(World world) {
  final commands = Commands();

  for (final (entity, health) in world.query1<Health>().iter()) {
    if (health.current <= 0) {
      commands.insert(entity, Dead());
    } else if (health.current < health.max * 0.2) {
      commands.insert(entity, LowHealth());
    }
  }

  commands.apply(world);
}
```

## See Also

- [Query API](/docs/api/query) - Query reference
- [Component](/docs/api/component) - Component types
- [Systems](/docs/guides/systems) - Using queries in systems
