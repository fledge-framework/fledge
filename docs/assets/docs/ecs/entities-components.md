# Entities & Components

An **entity** is an ID. A **component** is a plain Dart object attached to an
entity. The **`World`** stores both, grouped by archetype (the exact set of
component types an entity has), so a query over `Position` and `Velocity`
walks tightly packed tables instead of every entity.

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
  final int max;
  Health(this.max) : current = max;
}

class Player {}

class Enemy {}

class Target {
  Entity entity;
  Target([this.entity = Entity.placeholder]);
  bool get hasTarget => !entity.isPlaceholder;
}
-->

## Components

Any class can be a component. There is no base class to extend and nothing to
register:

```dart
import 'package:fledge_ecs/fledge_ecs.dart';

class Position {
  double x, y;
  Position(this.x, this.y);
}

class Velocity {
  double dx, dy;
  Velocity(this.dx, this.dy);
}

// A marker (tag) component: no data, used to filter queries.
class Player {}
```

The `@component` annotation is optional. It only matters if you use code
generation (see [Code Generation](/docs/app/codegen)).

Some guidelines that pay off as a game grows:

- **Keep components small and focused.** `Position`, `Velocity` and `Health`
  compose better than one `Character` class, because systems can query exactly
  the data they touch.
- **Use marker components for categories.** `Player`, `Enemy`, `Dead` cost
  nothing to store and make filters such as `With<Player>()` possible.
- **Give every entity its own component instances.** Components are mutable
  references, so spawning two entities from the same `Position` object makes
  them share a position.
- **Store entity references, not objects.** A component that points at another
  entity holds an `Entity` and checks `world.isAlive` before using it.

The component's type is its key. `world.insert(entity, x)` stores `x` under its
static type `T`, and `spawnWith` uses each object's runtime type. If you
insert a subclass through a variable typed as the base class, it is stored
(and queried) as the base class.

## The World

`World` is the container for entities, components, resources and events. An
[`App`](/docs/app/app-and-plugins) owns one as `app.world`; you can also create
one directly, which is handy in tests:

```dart
final world = World();
```

### Spawning

`spawnWith` creates an entity with all its components in one archetype move
and returns the `Entity`:

```dart
final world = World();

final player = world.spawnWith([
  Position(0, 0),
  Velocity(0, 0),
  Health(100),
  Player(),
]);
```

`spawn()` returns an `EntityCommands` builder for chaining `insert` calls. Use
its `.entity` getter for the ID:

```dart
final world = World();

final enemy = world.spawn()
  ..insert(Position(50, 20))
  ..insert(Health(30))
  ..insert(Enemy());

final id = enemy.entity;
```

Each `insert` on the builder is a separate archetype move, so prefer
`spawnWith` when you know all the components up front.

`spawnOne<T>(component)` is the cheapest path: one component, straight into its
table. It exists for many short-lived entities, such as render-world items,
and **does not fire observers** (see [Observers](/docs/ecs/observers)).

### Reading and changing components

```dart
final world = World();
final e = world.spawnWith([Position(0, 0), Health(10)]);

// Read: null if the entity is dead or lacks the component.
final pos = world.get<Position>(e);
if (pos != null) pos.x += 5; // in place: no archetype change

// Check
final hasVel = world.has<Velocity>(e); // false

// Add or replace
world.insert(e, Velocity(1, 0)); // adds: moves to a new archetype
world.insert(e, Position(10, 10)); // replaces: marks Position changed

// Remove: returns the removed component, or null
final Health? old = world.remove<Health>(e);
```

Mutating a component in place is invisible to change detection. Call
`world.markChanged<T>(entity)` if `Changed<T>` filters should see it (see
[Change Detection](/docs/ecs/change-detection)).

`insert` throws a `StateError` on a dead entity; `get`, `has` and `remove`
return null or false.

### Despawning

```dart
final world = World();
final e = world.spawnWith([Position(0, 0)]);

final wasAlive = world.despawn(e); // true
world.despawn(e); // false: already gone
print(world.isAlive(e)); // false
```

`despawn` removes one entity. For a parent and its children use
`despawnRecursive` (see [Hierarchies](/docs/ecs/hierarchies)). Inside a system
that is iterating a query, queue structural changes with
[Commands](/docs/ecs/commands).

## Entities

`Entity` is an immutable `(id, generation)` pair. When an entity is despawned
its `id` can be reused, but with a new generation, so a stale reference never
points at the new entity:

```dart
final world = World();
final a = world.spawnWith([Position(0, 0)]);
world.despawn(a);
final b = world.spawnWith([Position(0, 0)]); // may reuse a.id

print(a == b); // false: different generation
print(world.isAlive(a)); // false
```

`Entity.placeholder` is a sentinel for "no entity yet", and `isPlaceholder`
tests for it. It's never alive, so `get` returns null and `despawn` returns
false (but `insert` throws, as for any dead entity):

```dart
final world = World();
final enemy = world.spawnWith([Enemy()]);

final hunter = world.spawnWith([Target()]);
final target = world.get<Target>(hunter)!;
print(target.hasTarget); // false
target.entity = enemy;
```

## World at a glance

| Member | What it does |
|---|---|
| `spawn()` | New entity; returns `EntityCommands` (`.entity`, `insert`, `remove`) |
| `spawnWith(list)` | New entity with components; returns `Entity`; fires `onAdd` |
| `spawnOne<T>(c)` | New single-component entity; no observers |
| `despawn(e)` | Returns `bool` (was it alive); fires `onRemove` for each component |
| `isAlive(e)` | Whether the entity exists |
| `get<T>` / `has<T>` / `insert<T>` / `remove<T>` | Component access; `remove` returns `T?` |
| `markChanged<T>(e)` | Flags an in-place mutation for `Changed<T>` |
| `query1..4`, `queryMut1..4` | Queries, with an optional `filter:` (see [Queries](/docs/ecs/queries)) |
| `insertResource` / `getResource` / `removeResource` / `hasResource` | [Resources](/docs/ecs/resources) |
| `resourcesOfType<T>()` | Every resource that `is T` (interface lookup) |
| `registerEvent` / `eventReader` / `eventWriter` | [Events](/docs/ecs/events) |
| `entityCount`, `archetypeCount`, `resourceCount` | Counters |
| `getAllEntities()` / `despawnExcept(keep)` | Snapshot and roll back the entity set |
| `clear()` | Removes all entities (keeps resources and events) |
| `resetGameState()` | Removes all entities and clears event queues |

`App.markGameCheckpoint()` and `resetToGameCheckpoint()` build on
`getAllEntities`/`despawnExcept` for level transitions (see
[App & Plugins](/docs/app/app-and-plugins)). The full list is in the
[`World` dartdoc](https://pub.dev/documentation/fledge_ecs/latest/fledge_ecs/World-class.html).

## Archetypes and performance

Adding or removing a component moves the entity to another table. That's cheap
but not free, so:

- Prefer `spawnWith` to a chain of inserts.
- Don't toggle components every frame for state that changes every frame. A
  field (`Movement.isRunning`) is cheaper than adding and removing a `Running`
  marker 60 times a second. Markers suit state that changes occasionally
  (`Dead`, `Frozen`).
- Replacing a component with `insert` when the entity already has that type
  doesn't move it.

## See also

- [Queries](/docs/ecs/queries): finding entities by their components
- [Systems](/docs/ecs/systems): the logic that runs over them
- [Commands](/docs/ecs/commands): deferred spawns and despawns
