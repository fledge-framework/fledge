# World API Reference

The `World` class is the central container for all ECS data in Fledge.

## Import

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
```

## Constructor

```dart
World()
```

Creates a new empty world.

## Entity Methods

### spawn()

```dart
EntityCommands spawn()
```

Creates a new entity and returns `EntityCommands` for chaining component inserts.

```dart
// Chain inserts (recommended)
world.spawn()
  ..insert(Position(0, 0))
  ..insert(Velocity(1, 0));

// Get the Entity for later use
final commands = world.spawn()..insert(Position(0, 0));
final entity = commands.entity;
```

### spawnWith(components)

```dart
Entity spawnWith(List<dynamic> components)
```

Creates a new entity with components and returns the `Entity` directly.

```dart
final entity = world.spawnWith([Position(0, 0), Velocity(1, 0)]);
```

### despawn(entity)

```dart
void despawn(Entity entity)
```

Removes an entity and all its components from the world.

```dart
world.despawn(entity);
```

### isAlive(entity)

```dart
bool isAlive(Entity entity)
```

Returns `true` if the entity exists and hasn't been despawned.

```dart
if (world.isAlive(entity)) {
  // Entity is still valid
}
```

## Component Methods

### insert<T>(entity, component)

```dart
void insert<T>(Entity entity, T component)
```

Adds a component to an entity. If the entity already has a component of this type, it will be replaced.

```dart
world.insert(entity, Position(0, 0));
world.insert(entity, Velocity(1, 0));
```

### get<T>(entity)

```dart
T? get<T>(Entity entity)
```

Returns the component of type `T` for the entity, or `null` if not found.

```dart
final pos = world.get<Position>(entity);
if (pos != null) {
  print('Position: ${pos.x}, ${pos.y}');
}
```

### has<T>(entity)

```dart
bool has<T>(Entity entity)
```

Returns `true` if the entity has a component of type `T`.

```dart
if (world.has<Player>(entity)) {
  // This is a player entity
}
```

### remove<T>(entity)

```dart
void remove<T>(Entity entity)
```

Removes a component of type `T` from the entity.

```dart
world.remove<Velocity>(entity);
```

## Query Methods

### query1<A>()

```dart
Query1<A> query1<A>()
```

Creates a query for entities with one component type.

```dart
final query = world.query1<Position>();
for (final (entity, pos) in query.iter()) {
  // Process entities with Position
}
```

### query2<A, B>()

```dart
Query2<A, B> query2<A, B>()
```

Creates a query for entities with two component types.

```dart
final query = world.query2<Position, Velocity>();
for (final (entity, pos, vel) in query.iter()) {
  pos.x += vel.dx;
}
```

### query3<A, B, C>() and query4<A, B, C, D>()

Similar patterns for 3 and 4 component queries.

## Resource Methods

### insertResource<T>(resource)

```dart
void insertResource<T>(T resource)
```

Inserts a global resource. Replaces if already exists.

```dart
world.insertResource(Time());
world.insertResource(GameConfig(difficulty: 'hard'));
```

### getResource<T>()

```dart
T? getResource<T>()
```

Gets a resource by type, or `null` if not found.

```dart
final time = world.getResource<Time>();
if (time != null) {
  print('Delta: ${time.delta}');
}
```

### hasResource<T>()

```dart
bool hasResource<T>()
```

Returns `true` if a resource of type `T` exists.

```dart
if (world.hasResource<DebugConfig>()) {
  // Debug mode is enabled
}
```

### removeResource<T>()

```dart
T? removeResource<T>()
```

Removes and returns a resource.

```dart
final removed = world.removeResource<TempData>();
```

## Event Methods

### registerEvent<T>()

```dart
void registerEvent<T>()
```

Registers an event type. Must be called before using readers/writers.

```dart
world.registerEvent<CollisionEvent>();
world.registerEvent<DamageEvent>();
```

### eventReader<T>()

```dart
EventReader<T> eventReader<T>()
```

Gets a reader for events of type `T`.

```dart
final reader = world.eventReader<CollisionEvent>();
for (final event in reader.read()) {
  // Handle collision
}
```

### eventWriter<T>()

```dart
EventWriter<T> eventWriter<T>()
```

Gets a writer for events of type `T`.

```dart
final writer = world.eventWriter<DamageEvent>();
writer.send(DamageEvent(target, 10));
```

### updateEvents()

```dart
void updateEvents()
```

Swaps event buffers. Call once per frame (done automatically by App).

```dart
world.updateEvents();
```

## Example Usage

```dart
void main() {
  final world = World();

  // Spawn entities - option 1: chain inserts, then get entity
  final playerCommands = world.spawn()
    ..insert(Position(0, 0))
    ..insert(Velocity(0, 0))
    ..insert(Player());
  final player = playerCommands.entity;

  // Spawn entities - option 2: spawnWith returns Entity directly
  for (var i = 0; i < 10; i++) {
    world.spawnWith([
      Position(i * 10.0, 0),
      Velocity(-1, 0),
      Enemy(),
    ]);
  }

  // Query and process
  final query = world.query2<Position, Velocity>();
  for (final (entity, pos, vel) in query.iter()) {
    pos.x += vel.dx;
    pos.y += vel.dy;
  }

  // Check entity state
  print('Player alive: ${world.isAlive(player)}');
  print('Has velocity: ${world.has<Velocity>(player)}');

  // Despawn
  world.despawn(player);
  print('Player alive after despawn: ${world.isAlive(player)}');
}
```

## See Also

- [Entity](/docs/api/entity) - Entity type reference
- [Query](/docs/api/query) - Query types and iteration
- [Commands](/docs/api/commands) - Deferred world mutations
- [Resources](/docs/guides/resources) - Resource patterns
- [Events](/docs/guides/events) - Event patterns
- [App](/docs/api/app) - App builder
