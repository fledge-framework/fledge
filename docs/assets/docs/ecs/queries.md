# Queries

A query iterates every entity that has a given set of components. It yields
records of the entity plus mutable references to its components.

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

class Player {}

class Enemy {}

class Frozen {}

class Dead {}
-->

## Basics

`world.query1` through `world.query4` take one to four component types:

```dart
final world = World()
  ..spawnWith([Position(0, 0), Velocity(1, 2)])
  ..spawnWith([Position(5, 5)]); // no Velocity: not matched below

for (final (entity, pos, vel) in world.query2<Position, Velocity>().iter()) {
  pos.x += vel.dx;
  pos.y += vel.dy;
}
```

Components come back by reference, so writes go straight into storage. Ignore
the entity with `_` when you don't need it: `for (final (_, pos) in ...)`.

For more than four components, query the four you iterate on and read the rest
with `world.get<T>(entity)`, or split the data differently.

## Filters

Every query method takes an optional `filter:`.

| Filter | Matches entities that... |
|---|---|
| `With<T>()` | also have `T` (not fetched) |
| `Without<T>()` | don't have `T` |
| `Added<T>()` | had `T` added since the last check |
| `Changed<T>()` | had `T` added or changed since the last check |
| `And([...])` | pass every filter in the list |

```dart
final world = World();

// Players only.
final players = world.query1<Position>(filter: const With<Player>());

// Moving things that aren't frozen.
final movers = world.query2<Position, Velocity>(
  filter: const Without<Frozen>(),
);

// Living enemies.
final enemies = world.query2<Position, Health>(
  filter: const And([With<Enemy>(), Without<Dead>()]),
);
```

There is no `Or` filter. Run two queries, or use a shared marker component.
`Added` and `Changed` are covered on [Change Detection](/docs/ecs/change-detection).

## Optional components

Queries only match entities that have every listed type. For a component that
may be missing, fetch it per entity:

```dart
final world = World();

for (final (entity, pos) in world.query1<Position>().iter()) {
  final vel = world.get<Velocity>(entity); // null if absent
  if (vel != null) {
    pos.x += vel.dx;
  }
}
```

Queries have no optional components: the exported `Option<T>` type is
deprecated and matches nothing. Query the required components and read the
optional one with `world.get`.

## Utilities

```dart
final world = World()..spawnWith([Position(0, 0), Player()]);
final query = world.query1<Position>(filter: const With<Player>());

if (query.isEmpty) return;
print(query.count()); // number of matches
print(query.isNotEmpty); // true

// First match, or null. Handy for singletons such as the player.
final player = query.single();
if (player != null) {
  final (entity, pos) = player;
  pos.x = 100;
}

// Materialise when you need a list.
final all = query.iter().toList();
```

`single()` returns the *first* match; it doesn't check that there is exactly
one.

## Read and write intent: `queryMut`

`queryMut1`..`queryMut4` behave exactly like `query1`..`query4` at runtime. The
separate `QueryMutN` type exists so the code generator can tell a write from a
read on a `@system` parameter (see [Code Generation](/docs/app/codegen)).
In hand-written systems, declare access in `SystemMeta` instead and use the
plain `queryN` methods. Both share the cached state described below, and
both follow the per-system change baseline.

## Caching: creating queries is cheap

The world caches query state by *shape* (component types plus filter). The
first `world.query2<Position, Velocity>()` works out which archetypes match;
every later call with the same shape reuses that result, and it's only
refreshed when a new archetype appears. So calling `world.query...` inside a
system every frame is the normal pattern, not a waste. There's no need to
store queries in fields.

Queries with `Added` or `Changed` filters are the exception: each call gets a
fresh state, because the "since when" baseline is per query (inside a system,
the world sets it for you).

## Changing the world while iterating

`iter()` takes a snapshot of the matching entities when it starts. Spawning,
despawning, inserting or removing components inside the loop doesn't break
the iteration:

- an entity despawned mid-loop is skipped,
- one that moved archetype is read where it is now,
- one that no longer matches the query is skipped,
- entities spawned during the loop aren't visited.

```dart
final world = World()
  ..spawnWith([Health(0)])
  ..spawnWith([Health(10)]);

for (final (entity, health) in world.query1<Health>().iter()) {
  if (health.current <= 0) world.despawn(entity); // safe
}
```

It's still cleaner to queue structural changes with
[Commands](/docs/ecs/commands) in a system: the system then reads a stable
world for its whole run, and the changes land at one known point.

## Patterns

**Two queries in one system.** Look up the player once, then use it for
every enemy:

```dart
final world = World();

final player = world.query1<Position>(filter: const With<Player>()).single();
if (player == null) return;
final (_, playerPos) = player;

for (final (_, pos, vel) in world.query2<Position, Velocity>(
  filter: const With<Enemy>(),
).iter()) {
  vel.dx = (playerPos.x - pos.x).sign;
  vel.dy = (playerPos.y - pos.y).sign;
}
```

**Pairs.** Materialise once, then compare each pair once:

```dart
final world = World();
final items = world.query1<Position>().iter().toList();

for (var i = 0; i < items.length; i++) {
  for (var j = i + 1; j < items.length; j++) {
    final (a, pa) = items[i];
    final (b, pb) = items[j];
    final dx = pa.x - pb.x, dy = pa.y - pb.y;
    if (dx * dx + dy * dy < 16) print('$a touches $b');
  }
}
```

## See also

- [Entities & Components](/docs/ecs/entities-components)
- [Systems](/docs/ecs/systems): declaring what a query reads and writes
- [Change Detection](/docs/ecs/change-detection): `Added` and `Changed`
