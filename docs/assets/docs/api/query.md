# Query API Reference

Queries efficiently iterate over entities that have specific combinations of components.

## Import

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
```

## Query Types

### Query1<A>

Query for entities with one component:

```dart
final query = world.query1<Position>();

for (final (entity, pos) in query.iter()) {
  print('Entity ${entity.id} at (${pos.x}, ${pos.y})');
}
```

### Query2<A, B>

Query for entities with two components:

```dart
final query = world.query2<Position, Velocity>();

for (final (entity, pos, vel) in query.iter()) {
  pos.x += vel.dx;
  pos.y += vel.dy;
}
```

### Query3<A, B, C>

```dart
final query = world.query3<Position, Velocity, Mass>();

for (final (entity, pos, vel, mass) in query.iter()) {
  // Apply physics with mass
}
```

### Query4<A, B, C, D>

```dart
final query = world.query4<Position, Velocity, Health, Enemy>();

for (final (entity, pos, vel, health, enemy) in query.iter()) {
  // Process enemy entities
}
```

## Filters

Filters narrow down which entities match a query.

### With<T>

Include only entities that have the specified component:

```dart
// Only entities with both Position AND Player
final players = world.query1<Position>(filter: const With<Player>());

for (final (entity, pos) in players.iter()) {
  // Only player entities
}
```

### Without<T>

Exclude entities that have the specified component:

```dart
// Entities with Position but NOT Static
final dynamic = world.query1<Position>(filter: const Without<Static>());

for (final (entity, pos) in dynamic.iter()) {
  // Only dynamic (non-static) entities
}
```

### Combining Filters

```dart
// Entities with Position and Velocity,
// that have Enemy but not Dead
final activeEnemies = world.query2<Position, Velocity>(
  filter: And([With<Enemy>(), Without<Dead>()]),
);
```

## Query Methods

### iter()

Returns an iterator over matching entities:

```dart
for (final (entity, pos, vel) in query.iter()) {
  // Process each entity
}
```

### isEmpty

Check if any entities match:

```dart
final enemies = world.query1<Enemy>();
if (enemies.isEmpty) {
  print('No enemies left!');
}
```

### count()

Count matching entities:

```dart
final enemies = world.query1<Enemy>();
print('Enemy count: ${enemies.count()}');
```

## Query Iteration

The iterator returns a Dart record containing the entity and its components:

```dart
// Query1 returns (Entity, A)
for (final (entity, position) in query1.iter()) { ... }

// Query2 returns (Entity, A, B)
for (final (entity, position, velocity) in query2.iter()) { ... }

// Query3 returns (Entity, A, B, C)
for (final (entity, pos, vel, health) in query3.iter()) { ... }
```

### Destructuring

Use Dart's record destructuring for clean code:

```dart
for (final (entity, pos, vel) in query.iter()) {
  pos.x += vel.dx;
  pos.y += vel.dy;
}
```

### Ignoring Values

Use `_` to ignore values you don't need:

```dart
// Only care about position, not the entity
for (final (_, pos) in query.iter()) {
  print('${pos.x}, ${pos.y}');
}

// Only care about entity and velocity
for (final (entity, _, vel) in query2.iter()) {
  // ...
}
```

## Query Caching

Queries cache their archetype matches for performance:

```dart
// First call: finds matching archetypes
final query = world.query2<Position, Velocity>();

// Subsequent iterations use cached archetypes
for (final entry in query.iter()) { ... }
for (final entry in query.iter()) { ... } // Fast!
```

The cache is automatically invalidated when:
- New archetypes are created
- Entities move between archetypes

## Example Patterns

### Find Single Entity

```dart
Position? findPlayerPosition(World world) {
  final query = world.query1<Position>(filter: const With<Player>());
  for (final (_, pos) in query.iter()) {
    return pos; // Return first match
  }
  return null;
}
```

### Collect Entities

```dart
List<Entity> getAllEnemies(World world) {
  final query = world.query1<Enemy>();
  return [for (final (entity, _) in query.iter()) entity];
}
```

### Conditional Processing

```dart
@system
void damageSystem(World world) {
  for (final (entity, health) in world.query1<Health>().iter()) {
    if (health.current <= 0) {
      // Mark for cleanup
    }
  }
}
```

## Performance Tips

### Query Once Per System

```dart
// Good - create query once
@system
void goodSystem(World world) {
  final query = world.query2<Position, Velocity>();
  for (final entry in query.iter()) { ... }
}

// Bad - creating query each iteration
@system
void badSystem(World world) {
  for (var i = 0; i < 100; i++) {
    final query = world.query2<Position, Velocity>(); // Wasteful!
  }
}
```

### Use Specific Queries

```dart
// Bad - queries all entities then filters manually
for (final (entity, pos) in query.iter()) {
  if (world.has<Player>(entity)) { // Extra lookup
    // ...
  }
}

// Good - use With filter
for (final (entity, pos) in playerQuery.iter()) {
  // Only player entities
}
```

## See Also

- [Component](/docs/api/component) - Component types in queries
- [System](/docs/api/system) - Using queries in systems
- [World](/docs/api/world) - Creating queries
