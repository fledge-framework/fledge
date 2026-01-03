# Entities & Components Guide

This guide covers advanced patterns for working with entities and components in Fledge.

## Entity Lifecycle

### Creating Entities

Entities are created using `world.spawn()` which returns `EntityCommands`:

```dart
// Spawn with chained inserts (recommended)
world.spawn()
  ..insert(Position(0, 0))
  ..insert(Velocity(1, 0));

// Get the Entity for later use
final commands = world.spawn()..insert(Position(0, 0));
final entity = commands.entity;

// Or use spawnWith() to get Entity directly
final entity2 = world.spawnWith([Position(0, 0), Velocity(1, 0)]);
```

### Adding Components

Use the cascade operator for clean entity setup:

```dart
world.spawn()
  ..insert(Position(0, 0))
  ..insert(Velocity(1, 0))
  ..insert(Health(100, 100))
  ..insert(Player());
```

Or use `spawnWith()` for bulk component addition:

```dart
final entity = world.spawnWith([
  Position(0, 0),
  Velocity(1, 0),
]);
```

> **Note:** The method `insert` is for adding components to entities. For global singletons, use `insertResource` instead. See [Core Concepts](/docs/getting-started/core-concepts) for the distinction.

### Removing Entities

```dart
world.despawn(entity);
```

This removes the entity and all its components.

## Component Design Patterns

### Marker Components

Use empty components to tag entities for filtering:

```dart-tabs
// @tab Annotations
@component
class Player {}

@component
class Enemy {}

@component
class Static {}

@component
class Dead {}
// @tab Classes
class Player {}

class Enemy {}

class Static {}

class Dead {}
```

Query with filters:

```dart
// Only player entities
final players = world.query1<Position>(filter: const With<Player>());

// All moving entities except static ones
final dynamic = world.query2<Position, Velocity>(filter: const Without<Static>());
```

### Data Components

Keep data components focused on a single concern:

```dart-tabs
// @tab Annotations
// Good - focused components
@component
class Position {
  double x, y;
  Position(this.x, this.y);
}

@component
class Velocity {
  double dx, dy;
  Velocity(this.dx, this.dy);
}

@component
class Health {
  int current;
  int max;
  Health(this.current, this.max);
}
// @tab Classes
// Good - focused components
class Position {
  double x, y;
  Position(this.x, this.y);
}

class Velocity {
  double dx, dy;
  Velocity(this.dx, this.dy);
}

class Health {
  int current;
  int max;
  Health(this.current, this.max);
}
```

### Relationship Components

For entity relationships, store Entity references:

```dart-tabs
// @tab Annotations
@component
class Parent {
  final Entity entity;
  Parent(this.entity);
}

@component
class Target {
  Entity? entity;
  Target([this.entity]);
}

@component
class Children {
  final List<Entity> entities;
  Children([List<Entity>? entities]) : entities = entities ?? [];
}
// @tab Classes
class Parent {
  final Entity entity;
  Parent(this.entity);
}

class Target {
  Entity? entity;
  Target([this.entity]);
}

class Children {
  final List<Entity> entities;
  Children([List<Entity>? entities]) : entities = entities ?? [];
}
```

**Important**: Always check if referenced entities are still alive:

```dart-tabs
// @tab Annotations
@system
void followTargetSystem(World world) {
  for (final (entity, pos, target) in world.query2<Position, Target>().iter()) {
    if (target.entity == null) continue;
    if (!world.isAlive(target.entity!)) {
      target.entity = null;
      continue;
    }

    final targetPos = world.get<Position>(target.entity!);
    if (targetPos != null) {
      // Move toward target
      pos.x += (targetPos.x - pos.x) * 0.1;
      pos.y += (targetPos.y - pos.y) * 0.1;
    }
  }
}
// @tab FunctionSystem
final followTargetSystem = FunctionSystem(
  'followTarget',
  writes: {ComponentId.of<Position>(), ComponentId.of<Target>()},
  run: (world) {
    for (final (entity, pos, target) in world.query2<Position, Target>().iter()) {
      if (target.entity == null) continue;
      if (!world.isAlive(target.entity!)) {
        target.entity = null;
        continue;
      }

      final targetPos = world.get<Position>(target.entity!);
      if (targetPos != null) {
        // Move toward target
        pos.x += (targetPos.x - pos.x) * 0.1;
        pos.y += (targetPos.y - pos.y) * 0.1;
      }
    }
  },
);
```

### Event Components

Use components as one-frame events:

```dart-tabs
// @tab Annotations
@component
class DamageEvent {
  final int amount;
  final Entity source;
  DamageEvent(this.amount, this.source);
}

@component
class CollisionEvent {
  final Entity other;
  CollisionEvent(this.other);
}
// @tab Classes
class DamageEvent {
  final int amount;
  final Entity source;
  DamageEvent(this.amount, this.source);
}

class CollisionEvent {
  final Entity other;
  CollisionEvent(this.other);
}
```

Process and remove in the same frame:

```dart
void processDamage(World world) {
  final commands = Commands();

  for (final (entity, health, damage) in world.query2<Health, DamageEvent>().iter()) {
    health.current -= damage.amount;
    commands.remove<DamageEvent>(entity);
  }

  commands.apply(world);
}
```

## Archetype Considerations

### Minimize Archetype Changes

Adding/removing components moves entities between archetypes. This is O(1) but still has overhead:

```dart
// Avoid frequent component changes
for (var i = 0; i < 100; i++) {
  world.insert(entity, Buff());
  world.remove<Buff>(entity);  // Lots of archetype moves!
}

// Better - use a flag in the component
class Buff {
  bool active;
  Buff({this.active = true});
}
```

### Group Related Components

Entities with similar behavior should have similar component sets:

```dart
// All enemies have the same components
void spawnEnemy(World world, double x, double y) {
  world.spawn()
    ..insert(Position(x, y))
    ..insert(Velocity(0, 0))
    ..insert(Health(50, 50))
    ..insert(Collider(radius: 16))
    ..insert(Sprite('enemy.png'))
    ..insert(Enemy());
}
```

## Component Composition

### Building Entity Types

Create helper functions for common entity types:

```dart
Entity spawnPlayer(World world) {
  return world.spawnWith([
    Position(0, 0),
    Velocity(0, 0),
    Health(100, 100),
    InputReceiver(),
    Sprite('player.png'),
    Player(),
  ]);
}

Entity spawnBullet(World world, Position origin, Velocity vel) {
  return world.spawnWith([
    Position(origin.x, origin.y),
    Velocity(vel.dx, vel.dy),
    Collider(radius: 4),
    Damage(10),
    Bullet(),
  ]);
}
```

### Prefabs

Store entity templates as data:

```dart
class EntityTemplate {
  final List<dynamic> components;

  const EntityTemplate(this.components);

  Entity spawn(World world) {
    return world.spawnWith(components);
  }
}

final enemyTemplate = EntityTemplate([
  Position(0, 0),
  Velocity(0, 0),
  Health(50, 50),
  Enemy(),
]);

// Usage
final enemy = enemyTemplate.spawn(world);
```

## Best Practices

1. **Keep components small** - One responsibility per component
2. **Use marker components** - For tagging and filtering
3. **Validate entity references** - Check `isAlive()` before use
4. **Minimize archetype changes** - Group related behaviors together
5. **Use events as components** - For one-frame notifications

## See Also

- [Systems](/docs/guides/systems) - Processing entities
- [Queries](/docs/guides/queries) - Finding entities
- [Component API](/docs/api/component) - Component reference
