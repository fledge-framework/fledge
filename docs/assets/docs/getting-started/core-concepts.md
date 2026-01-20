# Core Concepts

Now that you've seen Fledge in action with the bouncing square, let's understand the concepts more deeply. This page serves as a reference you can return to as you build more complex games.

## The ECS Pattern

ECS stands for **Entity Component System**. It's a design pattern that separates:

- **What exists** (entities)
- **What they have** (components)
- **What they do** (systems)

This separation makes games easier to build, test, and extend.

## Entities

An **Entity** is just a unique identifier - think of it as a name tag. It has no data or behavior on its own.

```dart
// Spawn returns EntityCommands for chaining
final commands = world.spawn()
  ..insert(Position(0, 0));
final entity = commands.entity;

print(entity.id);          // Unique integer ID
print(entity.generation);  // Detects stale references
```

### Why Generational IDs?

When an entity is despawned, its ID slot can be reused. The generation number tracks this:

```dart
final entity = world.spawn().entity;  // id: 5, generation: 0
world.despawn(entity);

// Later, id 5 might be reused
final newEntity = world.spawn().entity;  // id: 5, generation: 1

// Old references can be detected
world.contains(entity);     // false - generation mismatch
world.contains(newEntity);  // true
```

## Components

**Components** are plain Dart classes that hold data. They have no logic.

```dart
// Position component - where something is
class Position {
  double x;
  double y;
  Position(this.x, this.y);
}

// Health component - can take damage
class Health {
  int current;
  int max;
  Health(this.current, this.max);

  bool get isDead => current <= 0;
}

// Marker component - no data, just tags the entity
class Player {}
class Enemy {}
```

### Component Guidelines

| Guideline | Example |
|-----------|---------|
| Keep them small | `Position` not `PositionAndVelocityAndHealth` |
| Make them mutable | Systems need to update them |
| Use markers for tags | `class Player {}` with no fields |
| Avoid methods | Logic belongs in systems |

### Working with Components

```dart
// Adding components when spawning
world.spawn()
  ..insert(Position(0, 0))
  ..insert(Health(100, 100))
  ..insert(Player());

// Or spawn with a list
final entity = world.spawnWith([
  Position(0, 0),
  Health(100, 100),
  Player(),
]);

// Reading components
final pos = world.get<Position>(entity);
final health = world.get<Health>(entity);

// Removing components
world.remove<Player>(entity);
```

## Systems

**Systems** contain game logic. They query for entities with specific components and process them.

```dart
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
      pos.x += vel.dx;
      pos.y += vel.dy;
    }
  }
}
```

### SystemMeta

The `SystemMeta` declares dependencies:

| Property | Purpose |
|----------|---------|
| `name` | Human-readable identifier |
| `reads` | Components this system reads |
| `writes` | Components this system modifies |
| `resourceReads` | Resources this system reads |
| `resourceWrites` | Resources this system modifies |

Fledge uses this information to:
1. **Run systems in parallel** when they don't conflict
2. **Detect data races** at runtime
3. **Order systems** within stages

### System Guidelines

- Keep systems **focused** - one responsibility each
- Declare **all** component and resource access
- Use **queries** to find entities
- Use **commands** for deferred spawn/despawn

## Queries

**Queries** efficiently find entities with specific component combinations.

```dart
// Find entities with Position and Velocity
for (final (entity, pos, vel) in world.query2<Position, Velocity>().iter()) {
  pos.x += vel.dx;
}

// Query types: query1, query2, query3, query4
final health = world.query1<Health>();
final moving = world.query2<Position, Velocity>();
final enemies = world.query3<Position, Health, Enemy>();
```

### Filters

Narrow down queries with filters:

```dart
// Only entities WITH Player component
final players = world.query2<Position, Velocity>(
  filter: const With<Player>(),
);

// Only entities WITHOUT Dead component
final alive = world.query1<Health>(
  filter: const Without<Dead>(),
);

// Combine filters
final activeEnemies = world.query2<Position, Health>(
  filter: And([With<Enemy>(), Without<Dead>()]),
);
```

## Resources

**Resources** are global singletons accessible by all systems.

```dart
// Define a resource
class GameConfig {
  final int maxEnemies;
  final double spawnRate;
  GameConfig({this.maxEnemies = 10, this.spawnRate = 2.0});
}

// Insert a resource
world.insertResource(GameConfig());

// Access in systems
final config = world.getResource<GameConfig>();
```

### Components vs Resources

| Concept | Storage | Use Case |
|---------|---------|----------|
| Component | Per-entity | Entity-specific data (position, health) |
| Resource | Global singleton | Shared state (time, config, input) |

```dart
// Components belong to entities
world.spawn()
  ..insert(Position(0, 0));    // This entity's position

// Resources are global
world.insertResource(Time());  // One Time for everyone
```

### Built-in Resources

Fledge provides these via plugins:

| Resource | Plugin | Purpose |
|----------|--------|---------|
| `Time` | `TimePlugin` | Delta time, elapsed time |

## Archetypes

An **archetype** is a unique combination of component types. Entities with the same components live together.

```
Archetype [Position, Velocity]
├── Entity 0: Position(0, 0), Velocity(1, 0)
├── Entity 3: Position(5, 5), Velocity(0, 1)
└── Entity 7: Position(2, 8), Velocity(1, 1)

Archetype [Position, Velocity, Player]
└── Entity 1: Position(0, 0), Velocity(0, 0), Player()
```

Why does this matter?
- **Cache efficiency**: Same components are stored contiguously in memory
- **Fast queries**: Query iteration skips irrelevant archetypes
- **O(1) access**: Components within an archetype use direct array indexing

You don't manage archetypes directly - Fledge handles it automatically.

## World

The **World** is the container for all ECS data:

```dart
final world = World();

// Entity operations
world.spawn()..insert(Position(0, 0));
world.despawn(entity);

// Component operations
world.get<Position>(entity);
world.remove<Position>(entity);

// Resource operations
world.insertResource(GameConfig());
world.getResource<GameConfig>();

// Query creation
world.query2<Position, Velocity>();
```

> In games, don't create World directly. Use `App` and access `app.world`.

## Schedule and Stages

Systems run in **stages**. Stages run in order; systems within a stage can run in parallel.

```dart
app.addSystem(inputSystem, stage: CoreStage.preUpdate);
app.addSystem(movementSystem, stage: CoreStage.update);
app.addSystem(collisionSystem, stage: CoreStage.postUpdate);
```

### Default Stages

| Stage | Purpose | Examples |
|-------|---------|----------|
| `first` | Very first | Debug logging |
| `preUpdate` | Before main logic | Input handling |
| `update` | Main game logic | Movement, AI |
| `postUpdate` | After main logic | Physics, collision |
| `last` | Very last | Rendering prep |

## Commands

When iterating over queries, you can't directly spawn or despawn entities (it would invalidate the iteration). Use **Commands** for deferred mutations:

```dart
void spawnBulletSystem(World world) {
  final commands = Commands();

  for (final (_, pos, gun) in world.query2<Position, Gun>().iter()) {
    if (gun.shouldFire) {
      commands.spawn()
        ..insert(Position(pos.x, pos.y))
        ..insert(Velocity(gun.direction.x * 500, gun.direction.y * 500))
        ..insert(Bullet());
      gun.shouldFire = false;
    }
  }

  // Apply after iteration completes
  commands.apply(world);
}
```

## Plugins

**Plugins** bundle related functionality:

```dart
class CombatPlugin implements Plugin {
  @override
  void build(App app) {
    // Add resources
    app.world.insertResource(DamageMultiplier(1.0));

    // Add systems
    app.addSystem(DamageSystem());
    app.addSystem(DeathSystem());

    // Spawn initial entities
    app.world.spawn()..insert(Player());
  }

  @override
  void cleanup() {
    // Called when plugin is removed
  }
}

// Use plugins
final app = App()
  ..addPlugin(TimePlugin())
  ..addPlugin(CombatPlugin());
```

## What's Next?

You now understand all the core concepts! Let's put them together and build a complete game in [Building Snake](/docs/getting-started/building-snake).
