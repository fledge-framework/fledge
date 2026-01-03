# Core Concepts

This page explains the fundamental concepts behind Fledge's ECS architecture.

## Entities

An **Entity** is simply a unique identifier. It has no data or behavior of its own — it's just an ID that components are attached to.

```dart
// Spawn returns EntityCommands for chaining
final commands = world.spawn()
  ..insert(Position(0, 0));
final entity = commands.entity;  // Get the actual Entity

print(entity.id);                // Unique integer ID
print(entity.generation);        // Generation for detecting stale references
```

### Generational Indices

Fledge uses generational indices to safely handle entity references. When an entity is despawned, its ID can be reused, but with an incremented generation. This allows detecting stale references:

```dart
final entity = world.spawn().entity;
world.despawn(entity);

final newEntity = world.spawn().entity; // Might reuse the same ID
// But newEntity.generation > entity.generation
```

## Components

**Components** are plain Dart classes that hold data. They have no logic — just fields.

```dart-tabs
// @tab Annotations
@component
class Position {
  double x;
  double y;
  Position(this.x, this.y);
}

@component
class Health {
  int current;
  int max;
  Health(this.current, this.max);
}

@component
class Enemy {} // Marker component (no data)
// @tab Inheritance
// Components are just plain Dart classes - no annotation needed
class Position {
  double x;
  double y;
  Position(this.x, this.y);
}

class Health {
  int current;
  int max;
  Health(this.current, this.max);
}

class Enemy {} // Marker component (no data)
```

### Component Guidelines

- Keep components **small and focused**
- Prefer **multiple small components** over one large component
- Use **marker components** (empty classes) for tagging entities
- Components should be **mutable** for systems to modify

### Adding and Removing Components

```dart
// Method 1: Chain inserts on spawn (recommended)
world.spawn()
  ..insert(Position(0, 0))
  ..insert(Health(100, 100));

// Method 2: Spawn with components directly (returns Entity)
final entity = world.spawnWith([Position(0, 0), Health(100, 100)]);

// Get components (requires Entity)
final pos = world.get<Position>(entity);

// Remove components
world.remove<Position>(entity);

// To get Entity from spawn(), access .entity property
final commands = world.spawn()..insert(Velocity(1, 1));
final entity2 = commands.entity;
world.get<Velocity>(entity2);
```

## Systems

**Systems** contain game logic. They're functions that process entities based on their components.

```dart-tabs
// @tab Annotations
@system
void healthRegenSystem(World world) {
  for (final (entity, health) in world.query1<Health>().iter()) {
    if (health.current < health.max) {
      health.current += 1;
    }
  }
}
// @tab Inheritance
class HealthRegenSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'healthRegen',
        writes: {ComponentId.of<Health>()},
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => runCondition?.call(world) ?? true;

  @override
  Future<void> run(World world) async {
    for (final (entity, health) in world.query1<Health>().iter()) {
      if (health.current < health.max) {
        health.current += 1;
      }
    }
  }
}
```

### System Guidelines

- Systems should be **pure functions** (no hidden state)
- Use **queries** to access components
- Use **resources** for global state
- Use **commands** for deferred entity mutations

## Queries

**Queries** efficiently iterate over entities that have specific components.

```dart
// Query for entities with both Position and Velocity
final query = world.query2<Position, Velocity>();

for (final (entity, pos, vel) in query.iter()) {
  // Process each matching entity
}
```

### Query Types

| Query | Components |
|-------|------------|
| `Query1<A>` | One component |
| `Query2<A, B>` | Two components |
| `Query3<A, B, C>` | Three components |
| `Query4<A, B, C, D>` | Four components |

### Filters

Filters narrow down which entities a query matches:

```dart
// Only entities that HAVE the Player component
final playerQuery = world.query2<Position, Velocity>(
  filter: const With<Player>(),
);

// Only entities that DON'T have the Static component
final dynamicQuery = world.query1<Position>(
  filter: const Without<Static>(),
);

// Combine filters with And
final activeEnemies = world.query2<Position, Velocity>(
  filter: And([With<Enemy>(), Without<Dead>()]),
);
```

## Archetypes

An **archetype** is a unique combination of component types. Entities with the same components are stored together in the same archetype.

```
Archetype [Position, Velocity]
├── Entity 0: Position(0, 0), Velocity(1, 0)
├── Entity 3: Position(5, 5), Velocity(0, 1)
└── Entity 7: Position(2, 8), Velocity(1, 1)

Archetype [Position, Velocity, Player]
└── Entity 1: Position(0, 0), Velocity(0, 0), Player()

Archetype [Position, Health]
├── Entity 2: Position(10, 0), Health(100)
└── Entity 5: Position(15, 3), Health(50)
```

### Why Archetypes?

1. **Cache Efficiency**: Components of the same type are stored contiguously
2. **Fast Iteration**: No need to check each entity for components
3. **O(1) Component Access**: Direct array indexing within an archetype

## Resources

**Resources** are global singletons accessible by all systems. Unlike components which belong to specific entities, resources are shared world-wide.

```dart
class Time {
  double delta = 0.0;
  double elapsed = 0.0;
}

class GameConfig {
  final int maxEnemies;
  GameConfig({this.maxEnemies = 100});
}
```

### Components vs Resources

| Concept | Storage | Method | Use Case |
|---------|---------|--------|----------|
| Component | Per-entity | `entity.insert(component)` | Entity-specific data (position, health) |
| Resource | Global singleton | `world.insertResource(resource)` | Shared state (time, config, input) |

The different method names reflect their different purposes:
- **`insert`** adds data *to an entity* — the entity is the target
- **`insertResource`** adds data *to the world* — there's no entity involved

```dart
// Components belong to entities
world.spawn()
  ..insert(Position(0, 0))    // Position for THIS entity
  ..insert(Health(100, 100)); // Health for THIS entity

// Resources are global
world.insertResource(Time());       // ONE Time for the whole world
world.insertResource(GameConfig()); // ONE GameConfig for the whole world
```

## World

The **World** is the central container that holds all ECS data:

- Entity storage and lifecycle
- Component storage (archetypes)
- Resources (global singletons)
- Event queues

```dart
// Inside systems and plugins, you interact with World
Future<void> run(World world) async {
  // Entity operations
  world.spawn()..insert(Position(0, 0));           // Chain inserts
  final entity = world.spawnWith([Position(0, 0)]); // Or spawn with components
  world.despawn(entity);

  // Component operations (requires Entity)
  final pos = world.get<Position>(entity);
  world.remove<Position>(entity);

  // Resource operations (global)
  final time = world.getResource<Time>();

  // Query creation
  final query = world.query2<Position, Velocity>();
}
```

> **Note**: Don't create `World` directly in games. Use `App` as your entry point and access `app.world` when needed. Direct `World` usage is mainly for unit tests. See [App & Plugins Guide](/docs/guides/app-plugins) for details.

## Schedule

The **Schedule** organizes systems into stages and manages execution order. When using `App`, the schedule is managed automatically:

```dart
// App handles the schedule for you
App()
  .addSystem(inputSystem, stage: CoreStage.preUpdate)
  .addSystem(movementSystem, stage: CoreStage.update)
  .addSystem(renderSystem, stage: CoreStage.postUpdate)
  .run();  // Runs all systems each frame
```

### Stages

Systems are grouped into stages that run in order:

1. `CoreStage.first` - Run before everything
2. `CoreStage.preUpdate` - Input handling, event processing
3. `CoreStage.update` - Main game logic
4. `CoreStage.postUpdate` - Physics, collision resolution
5. `CoreStage.last` - Cleanup, rendering

### Parallel Execution

Within each stage, systems that don't conflict can run in parallel:

```dart
// These can run in parallel (different component access)
FunctionSystem('systemA', reads: {ComponentId.of<Position>()}, run: (world) { ... })
FunctionSystem('systemB', reads: {ComponentId.of<Health>()}, run: (world) { ... })

// These must run sequentially (same component access)
FunctionSystem('systemC', writes: {ComponentId.of<Position>()}, run: (world) { ... })
FunctionSystem('systemD', writes: {ComponentId.of<Position>()}, run: (world) { ... })
```

## Next Steps

- [Entities & Components](/docs/guides/entities-components) - Advanced patterns
- [Systems](/docs/guides/systems) - System ordering and stages
- [Queries](/docs/guides/queries) - Advanced query techniques
