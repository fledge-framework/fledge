# Entity API Reference

The `Entity` class represents a unique identifier for a game object.

## Import

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
```

## Properties

### id

```dart
int get id
```

The unique integer identifier for this entity.

```dart
final entity = world.spawnWith([Position(0, 0)]);
print(entity.id); // e.g., 0, 1, 2, ...
```

### generation

```dart
int get generation
```

The generation counter for this entity. Used to detect stale references when entity IDs are reused.

```dart
final entity = world.spawnWith([]);
print(entity.generation); // Starts at 0
```

## Generational Indices

Fledge uses generational indices to safely handle entity references. When an entity is despawned, its ID slot becomes available for reuse. However, the generation is incremented, allowing detection of stale references.

### Why Generations Matter

```dart
final world = World();

// Spawn entity 0
final entity1 = world.spawnWith([]);
print('Entity 1: id=${entity1.id}, gen=${entity1.generation}');
// Output: Entity 1: id=0, gen=0

// Despawn it
world.despawn(entity1);

// Spawn a new entity - might reuse ID 0
final entity2 = world.spawnWith([]);
print('Entity 2: id=${entity2.id}, gen=${entity2.generation}');
// Output: Entity 2: id=0, gen=1 (same ID, higher generation)

// entity1 is now a stale reference
print('Entity 1 alive: ${world.isAlive(entity1)}'); // false
print('Entity 2 alive: ${world.isAlive(entity2)}'); // true
```

### Safe Entity References

Always check if an entity is alive before using it:

```dart
class EntityRef {
  final Entity entity;
  final World world;

  EntityRef(this.entity, this.world);

  Position? get position {
    if (!world.isAlive(entity)) return null;
    return world.get<Position>(entity);
  }
}
```

## Entity Comparison

Entities are compared by both ID and generation:

```dart
final a = world.spawnWith([]);
world.despawn(a);
final b = world.spawnWith([]); // Might have same ID

print(a == b); // false (different generations)
print(a.id == b.id); // might be true
print(a.generation == b.generation); // false
```

## EntityCommands

When spawning entities, you can chain component insertions using `EntityCommands`:

```dart
// Chain inserts - the cascade operator calls methods on EntityCommands
world.spawn()
  ..insert(Position(0, 0))
  ..insert(Velocity(1, 0))
  ..insert(Player());

// If you need the Entity, access .entity property
final commands = world.spawn()..insert(Position(0, 0));
final entity = commands.entity;

// Or use spawnWith() to get Entity directly
final entity2 = world.spawnWith([Position(0, 0), Velocity(1, 0), Player()]);
```

## Best Practices

### Don't Store Entity References Long-Term

```dart
// Bad - entity might be despawned
class GameState {
  Entity? targetEntity; // Stale reference risk!
}

// Better - validate before use
class GameState {
  Entity? targetEntity;
  World world;

  Position? getTargetPosition() {
    if (targetEntity == null) return null;
    if (!world.isAlive(targetEntity!)) {
      targetEntity = null;
      return null;
    }
    return world.get<Position>(targetEntity!);
  }
}
```

### Use Components Instead of Entity References

```dart
// Instead of storing entity references...
@component
class Target {
  Entity enemy; // Risk: enemy might be despawned
}

// Consider using a lookup component
@component
class TargetTag {
  final int priority;
  TargetTag(this.priority);
}

// Then query for targets
final targets = world.query2<Position, TargetTag>();
```

## See Also

- [World](/docs/api/world) - Entity creation and management
- [Component](/docs/api/component) - Attaching data to entities
- [Query](/docs/api/query) - Finding entities by components
