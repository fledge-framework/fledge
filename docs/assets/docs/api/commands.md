# Commands API Reference

`Commands` provides deferred mutations to the world, allowing safe entity spawning and despawning during system execution.

## Import

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
```

## Why Commands?

Modifying the world while iterating over entities can cause issues:

```dart
// Dangerous - modifying while iterating
void badSystem(World world) {
  for (final (entity, spawner) in world.query1<Spawner>().iter()) {
    world.spawn(); // Can invalidate iterators!
    world.despawn(entity); // Dangerous during iteration!
  }
}
```

Commands queue these operations to be applied safely after iteration:

```dart
// Safe - mutations are deferred
void goodSystem(World world) {
  final commands = Commands();

  for (final (entity, spawner) in world.query1<Spawner>().iter()) {
    commands.spawn()..insert(NewEntity()); // Queued for later
    commands.despawn(entity); // Queued for later
  }

  // Apply all commands after iteration
  commands.apply(world);
}
```

## Constructor

```dart
Commands()
```

Creates a new empty command buffer.

## Methods

### spawn()

```dart
SpawnCommand spawn()
```

Queues a new entity to be spawned. Use cascade syntax to add components. Returns a `SpawnCommand` that will contain the spawned entity after `apply()` is called.

```dart
commands.spawn()
  ..insert(Position(0, 0))
  ..insert(Velocity(1, 0))
  ..insert(Enemy());
```

### despawn(entity)

```dart
void despawn(Entity entity)
```

Queues an entity to be removed from the world:

```dart
void deathSystem(World world) {
  final commands = Commands();

  for (final (entity, health) in world.query1<Health>().iter()) {
    if (health.current <= 0) {
      commands.despawn(entity);
    }
  }

  commands.apply(world);
}
```

### despawnRecursive(entity)

```dart
void despawnRecursive(Entity entity)
```

Queues an entity and all its descendants to be removed:

```dart
commands.despawnRecursive(parentEntity);
```

### spawnChild(parent)

```dart
SpawnChildCommand spawnChild(Entity parent)
```

Queues a new entity as a child of an existing parent. Use cascade syntax to add components:

```dart
// Parent must already exist
final parent = world.spawnWith([ParentMarker()]);
commands.spawnChild(parent)
  ..insert(ChildComponent());
```

### insert<T>(entity, component)

```dart
void insert<T>(Entity entity, T component)
```

Queues a component to be added to an existing entity:

```dart
commands.insert(entity, Poisoned(duration: 5.0));
```

### remove<T>(entity)

```dart
void remove<T>(Entity entity)
```

Queues a component to be removed from an entity:

```dart
commands.remove<Invulnerable>(entity);
```

### custom(action)

```dart
void custom(void Function(World world) action)
```

Queues a custom function to run on the world:

```dart
commands.custom((world) {
  // Any world operation
  world.insertResource(NewResource());
});
```

### apply(world)

```dart
void apply(World world)
```

Executes all queued commands in order and clears the queue:

```dart
commands.apply(world);
```

## Properties

### isEmpty / isNotEmpty

```dart
bool get isEmpty
bool get isNotEmpty
```

Check if there are queued commands.

### length

```dart
int get length
```

The number of queued commands.

### clear()

```dart
void clear()
```

Clears all queued commands without executing them.

## SpawnCommand

Returned by `spawn()`, provides access to the spawned entity after `apply()`:

```dart
final spawnCmd = commands.spawn()..insert(Position(0, 0));
commands.apply(world);
final entity = spawnCmd.entity; // Available after apply()
```

## Example Patterns

### Spawning on Events

```dart
void bulletSpawner(World world) {
  final commands = Commands();

  for (final (entity, pos, shooter) in world.query2<Position, Shooter>().iter()) {
    if (shooter.shouldShoot) {
      commands.spawn()
        ..insert(Position(pos.x, pos.y))
        ..insert(Velocity(shooter.aimX * 10, shooter.aimY * 10))
        ..insert(Bullet(damage: 10));
      shooter.shouldShoot = false;
    }
  }

  commands.apply(world);
}
```

### Cleanup System

```dart
void cleanupSystem(World world) {
  final commands = Commands();

  for (final (entity, _) in world.query1<Dead>().iter()) {
    commands.despawn(entity);
  }

  commands.apply(world);
}
```

### State Transitions

```dart
void damageSystem(World world) {
  final commands = Commands();

  for (final (entity, health, damage) in world.query2<Health, DamageReceived>().iter()) {
    health.current -= damage.amount;

    // Remove the damage event component
    commands.remove<DamageReceived>(entity);

    // Add death marker if dead
    if (health.current <= 0) {
      commands.insert(entity, Dead());
    }
  }

  commands.apply(world);
}
```

### Spawning Particles

```dart
void explosionSystem(World world) {
  final commands = Commands();

  for (final (entity, pos, _) in world.query2<Position, Exploding>().iter()) {
    // Spawn explosion particles
    for (var i = 0; i < 10; i++) {
      final angle = i * (3.14159 * 2 / 10);
      commands.spawn()
        ..insert(Position(pos.x, pos.y))
        ..insert(Velocity(cos(angle) * 5, sin(angle) * 5))
        ..insert(Particle(lifetime: 1.0));
    }

    // Remove the exploding entity
    commands.despawn(entity);
  }

  commands.apply(world);
}
```

## Commands vs World

| Method | Commands (deferred) | World (immediate) |
|--------|---------------------|-------------------|
| Spawn | `commands.spawn()..insert(A())..insert(B())` | `world.spawn()..insert(A())..insert(B())` |
| Despawn | `commands.despawn(e)` | `world.despawn(e)` |
| Insert | `commands.insert(e, C())` | `world.insert(e, C())` |
| Remove | `commands.remove<C>(e)` | `world.remove<C>(e)` |
| Execution | After `apply(world)` | Immediately |
| Safe in loops | Yes | No (can invalidate iterators) |

## Best Practices

### Use Commands During Iteration

```dart
// Good - safe during iteration
void goodSystem(World world) {
  final commands = Commands();
  for (final (entity, _) in world.query1<SomeComponent>().iter()) {
    commands.spawn()..insert(NewEntity());
    commands.despawn(entity);
  }
  commands.apply(world);
}

// Bad - can invalidate iterators
void badSystem(World world) {
  for (final (entity, _) in world.query1<SomeComponent>().iter()) {
    world.spawn(); // Dangerous!
  }
}
```

### Batch Related Operations

```dart
final commands = Commands();

// Queue all spawns together
for (final enemy in enemiesToSpawn) {
  commands.spawn()
    ..insert(Position(enemy.x, enemy.y))
    ..insert(Enemy(type: enemy.type));
}

// Apply once at the end
commands.apply(world);
```

### Entity References After Spawn

```dart
// SpawnCommand gives access to entity after apply()
final cmd1 = commands.spawn()..insert(Player());
final cmd2 = commands.spawn()..insert(Enemy());

commands.apply(world);

// Now entities are available
final player = cmd1.entity!;
final enemy = cmd2.entity!;
```

## See Also

- [System](/docs/api/system) - Writing systems
- [World](/docs/api/world) - Direct world mutations
- [Entity](/docs/api/entity) - Entity lifecycle
