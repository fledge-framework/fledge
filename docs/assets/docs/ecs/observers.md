# Observers

An observer is a callback that runs the moment a component of a given type is
added to, removed from, or replaced on an entity. Use observers for immediate,
per-entity reactions; use systems with
[change detection](/docs/ecs/change-detection) for batch work once per frame.

<!-- snippet-setup
class Health {
  int current;
  Health(this.current);
}

class Position {
  double x, y;
  Position(this.x, this.y);
}

class Collider {
  final double radius;
  Collider(this.radius);
}

class SpatialGrid {
  final Set<Entity> entries = {};
}

class DeathEvent {
  final Entity entity;
  const DeathEvent(this.entity);
}
-->

## Registering

Observers live in `world.observers`. Create one with a named constructor for
the trigger you want; the callback gets the world, the entity and the
component:

```dart
final world = World()..insertResource(SpatialGrid());

world.observers.register(
  Observer<Collider>.onAdd((world, entity, collider) {
    world.getResource<SpatialGrid>()!.entries.add(entity);
  }),
);

world.observers.register(
  Observer<Collider>.onRemove((world, entity, collider) {
    world.getResource<SpatialGrid>()!.entries.remove(entity);
  }),
);

final rock = world.spawnWith([Position(0, 0), Collider(4)]); // onAdd fires
world.despawn(rock); // onRemove fires
```

A plugin typically registers its observers in `build` via
`app.world.observers.register(...)`.

## When each trigger fires

| Operation | Fires |
|---|---|
| `world.insert(e, c)`, component is new | `onAdd` |
| `world.insert(e, c)`, replacing an existing `T` | `onChange` (with the new value) |
| `world.spawnWith([...])`, `Commands.spawn()` | `onAdd` for each component |
| `world.spawn()..insert(...)` | `onAdd` for each insert |
| `world.entityFromJson(json)`, `world.insertDynamic(e, type, c)` | `onAdd` (or `onChange` when `insertDynamic` replaces an existing component) |
| `world.remove<T>(e)` | `onRemove` (with the removed value) |
| `world.despawn(e)`, `despawnRecursive`, `Commands.despawn` | `onRemove` for every component |
| `world.spawnOne<T>(c)` | nothing (by design: the cheap path for throwaway entities) |
| Mutating a component in place, `markChanged` | nothing |

On despawn, the `onRemove` callbacks run *before* the entity is removed, so
the callback can still read the entity's other components:

```dart
final world = World()..registerEvent<DeathEvent>();

world.observers.register(
  Observer<Health>.onRemove((world, entity, health) {
    final pos = world.get<Position>(entity); // still readable here
    print('died at ${pos?.x}, ${pos?.y}');
    world.eventWriter<DeathEvent>().send(DeathEvent(entity));
  }),
);
```

`onChange` only fires when a component is *replaced* with `insert`. Fledge
can't see `health.current -= 1`.

## Multiple observers and unregistering

Any number of observers can watch the same type and trigger; they run in
registration order. Keep a reference to unregister one:

```dart
final world = World();

final logAdds = Observer<Health>.onAdd((world, entity, health) {
  print('$entity spawned with ${health.current} HP');
});
world.observers.register(logAdds);

// later
final removed = world.observers.unregister(logAdds); // true
```

`world.observers` also has `hasObservers`, `hasObserversFor<T>()`, `count` and
`clear()`. An `Observer` exposes `componentType` and `trigger` (a
`TriggerKind`); the callback itself is private.

## Things to keep in mind

- **Observers run synchronously, inside the operation.** A slow callback slows
  every spawn or despawn of that component.
- **They fire outside the scheduler.** Nothing orders them against systems, and
  their reads and writes aren't in any `SystemMeta`.
- **Changes made in a callback happen immediately**, including inserts that
  trigger further observers. Keep chains short, or send an
  [event](/docs/ecs/events) and handle it in a system.

## Observers or change detection?

| Observers | `Added` / `Changed` filters |
|---|---|
| Run the instant the change happens | Run when the system runs |
| See removals and despawns | Can't see removals |
| One callback per entity | One pass over all changed entities |
| Don't see in-place mutation | See it after `markChanged` |

## See also

- [Change Detection](/docs/ecs/change-detection)
- [Events](/docs/ecs/events)
- [Entities & Components](/docs/ecs/entities-components)
