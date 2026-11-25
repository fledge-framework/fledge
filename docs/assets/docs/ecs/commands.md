# Commands

`Commands` is a queue of structural changes (spawn, despawn, insert, remove)
that you record now and apply later in one go. Systems use it so they can
decide what to change while iterating, then change it at a single, known
point.

<!-- snippet-setup
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
  Health(this.current);
}

class Gun {
  bool fire = false;
  double speed = 300;
}

class Bullet {}

class Dead {}

class Sprite {
  final String name;
  Sprite(this.name);
}
-->

## Basic use

Create a `Commands`, queue changes, then `apply(world)`:

```dart
class ShootSystem extends System {
  static const String systemName = 'shoot';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    reads: {ComponentId.of<Position>()},
    writes: {ComponentId.of<Gun>()},
  );

  @override
  void run(World world) {
    final commands = Commands();
    for (final (_, gun, pos) in world.query2<Gun, Position>().iter()) {
      if (!gun.fire) continue;
      gun.fire = false;
      commands.spawn()
        ..insert(Bullet())
        ..insert(Position(pos.x, pos.y))
        ..insert(Velocity(gun.speed, 0));
    }
    commands.apply(world);
  }
}
```

Nothing happens to the world until `apply`. Commands run in the order they were
queued, and the queue is empty afterwards, so the same `Commands` can be
reused.

Queries snapshot their matches, so changing the world mid-loop doesn't break
iteration (see [Queries](/docs/ecs/queries#changing-the-world-while-iterating)).
Commands are still the clean pattern: the loop reads a world that doesn't
shift under it, and the changes land together.

## What you can queue

| Method | Effect when applied |
|---|---|
| `spawn()` | Spawns an entity with every component added via `..insert(...)`, fires `onAdd` observers |
| `despawn(entity)` | `world.despawn(entity)`, fires `onRemove` for each component |
| `despawnRecursive(entity)` | Despawns the entity and all its descendants |
| `spawnChild(parent)` | Spawns an entity (with its inserts) as a child of `parent`; does nothing if `parent` is dead by then |
| `insert<T>(entity, component)` | Adds or replaces a component; skipped if the entity is dead |
| `remove<T>(entity)` | Removes a component; skipped if the entity is dead |
| `markChanged<T>(entity)` | Flags an in-place mutation for `Changed<T>` filters |
| `custom((world) { ... })` | Runs any function on the world |

Plus `isEmpty`, `isNotEmpty`, `length` and `clear()` (drop without applying).

Commands that target an entity tolerate it being gone by the time they apply,
which happens when two systems both decide to despawn the same entity.

```dart
final world = World();
final enemy = world.spawnWith([Health(0)]);

final commands = Commands()
  ..insert(enemy, Dead())
  ..remove<Health>(enemy)
  ..custom((world) => print('${world.entityCount} entities'));
commands.apply(world);
```

## Getting the spawned entity

`spawn()` and `spawnChild()` return the queued command. Its `entity` getter is
**null until `apply` runs**:

```dart
final world = World();
final commands = Commands();

final pending = commands.spawn()..insert(Position(0, 0));
print(pending.entity); // null: not spawned yet

commands.apply(world);
final bullet = pending.entity!; // now set
```

If you need the ID right away, to store it in another component in the same
pass for example, spawn directly with `world.spawnWith`, or do the follow-up
work inside a `custom` command, which runs after the earlier commands:

```dart
final world = World();
final owner = world.spawnWith([Position(0, 0)]);
final commands = Commands();

final pending = commands.spawn()..insert(Sprite('shield'));
commands.custom((world) => world.setParent(pending.entity!, owner));
commands.apply(world);
```

## Hierarchy commands

The hierarchy methods are on `Commands` itself:

```dart
final world = World();
final ship = world.spawnWith([Position(0, 0)]);
final commands = Commands();

commands.spawnChild(ship)
  ..insert(Sprite('turret'))
  ..insert(Position(0, 8));

commands.despawnRecursive(ship); // queued after the child spawn
commands.apply(world);
```

See [Hierarchies](/docs/ecs/hierarchies).

## Marking changes

In-place mutation (`health.current -= 1`) isn't seen by `Changed<T>`. Inside a
loop you can call `world.markChanged<T>(entity)` directly (it isn't
structural), or queue it with the rest:

```dart
final world = World();
final commands = Commands();

for (final (entity, health) in world.query1<Health>().iter()) {
  health.current -= 1;
  commands.markChanged<Health>(entity);
}
commands.apply(world);
```

See [Change Detection](/docs/ecs/change-detection).

## Generated systems

An `@system` function can take a `Commands` parameter. The generated wrapper
creates it and applies it after your function returns:

```dart fragment
@system
void cleanup(Query1<Dead> dead, Commands commands) {
  for (final (entity, _) in dead.iter()) {
    commands.despawn(entity);
  }
}
```

See [Code Generation](/docs/app/codegen).

## Commands or the world directly?

| Use `Commands` | Use the `World` directly |
|---|---|
| Structural changes decided inside a query loop | Setup code outside systems |
| Changes several systems might race on | When you need the new entity's ID immediately |
| Batching a system's changes at one point | Tests |

## See also

- [Entities & Components](/docs/ecs/entities-components)
- [Hierarchies](/docs/ecs/hierarchies)
- [Systems](/docs/ecs/systems)
