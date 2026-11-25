# Change Detection

The `Added<T>` and `Changed<T>` query filters match only entities whose `T`
component was added or changed recently. Use them to do work only when
something actually changed: rebuild a health bar when `Health` changes, index
a collider when it's added.

<!-- snippet-setup
class Health {
  int current;
  final int max;
  Health(this.max) : current = max;
}

class Poisoned {}

class HealthBar {
  double fill = 1;
}
-->

## In a system

```dart
class HealthBarSystem extends System {
  static const String systemName = 'healthBar';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    reads: {ComponentId.of<Health>()},
    writes: {ComponentId.of<HealthBar>()},
  );

  @override
  void run(World world) {
    for (final (_, health, bar) in world.query2<Health, HealthBar>(
      filter: const Changed<Health>(),
    ).iter()) {
      bar.fill = health.current / health.max;
    }
  }
}
```

Inside a system run by the scheduler, "recently" means **since this system
last ran**:

- On its **first run**, a system sees everything that already exists: every
  `T` counts as added and changed.
- After that, it sees changes made since its previous run finished, including
  changes made later in the previous frame by systems ordered after it.
- It doesn't see changes it made itself on earlier runs.
- If it's skipped (a run condition returned false), nothing is lost: on its
  next run it sees everything since the last time it actually ran.

You don't manage any of this; `world.query1`..`query4` set the baseline
automatically while a system runs.

## What counts as a change

| Operation | `Added<T>` | `Changed<T>` |
|---|---|---|
| Spawning with `T`, or inserting a new `T` | yes | yes |
| `world.insert(e, T(...))` replacing an existing `T` | no | yes |
| `world.markChanged<T>(e)` / `commands.markChanged<T>(e)` | no | yes |
| Mutating in place: `health.current -= 1` | no | **no** |
| Inserting or removing a *different* component | no | no |

In-place mutation is invisible: Fledge hands out references and can't tell
when you write through them. After mutating, mark the component:

```dart
final poison = FunctionSystem(
  'poison',
  writes: {ComponentId.of<Health>()},
  run: (world) {
    for (final (entity, health) in world.query1<Health>(
      filter: const With<Poisoned>(),
    ).iter()) {
      health.current -= 1;
      world.markChanged<Health>(entity);
    }
  },
);
```

`markChanged` returns false if the entity is dead or has no `T`. In a
`Commands`-based system, `commands.markChanged<T>(entity)` queues the same
thing.

Removals don't show up in either filter. To react to a component being
removed or an entity despawned, use an
[`onRemove` observer](/docs/ecs/observers).

## Combining filters

`Added` and `Changed` combine with the other filters through `And`:

```dart
final world = World();

final newlyPoisoned = world.query1<Health>(
  filter: const And([Added<Poisoned>(), Changed<Health>()]),
);
```

## Outside a system

Outside the scheduler (a test, a tool, a Flutter widget polling the world)
there's no "last run" to compare against, so you keep the query and record
what you've seen yourself. `world.changeTick` is the change clock; pass it to
`query.state.updateLastSeenTick` after each pass:

```dart
final world = World();
final changedHealth = world.query1<Health>(filter: const Changed<Health>());

void pollHealth() {
  for (final (entity, health) in changedHealth.iter()) {
    print('$entity now has ${health.current} HP');
  }
  changedHealth.state.updateLastSeenTick(world.changeTick);
}

world.advanceTick(); // a new frame
final hero = world.spawnWith([Health(10)]);
pollHealth(); // prints the hero

world.advanceTick();
world.get<Health>(hero)!.current = 7;
world.markChanged<Health>(hero);
pollHealth(); // prints the hero again

world.advanceTick();
pollHealth(); // prints nothing
```

Two details:

- The change clock moves on `world.advanceTick()` (once per frame and once per
  fixed step in an `App`) and before every system run. Changes stamped at the
  same tick you record as seen are treated as seen, so advance the tick
  between "record" and the next change, as a frame loop naturally does.
- A kept query starts from tick 0, so on a fresh `World` it misses changes made
  before the first `advanceTick()`.

Calling `world.query1(filter: Changed<T>())` afresh outside a system, rather
than keeping one, matches every `T` changed since tick 0.

`world.changeTick` is distinct from `world.currentTick`, the frame tick, which
advances once per frame and once per fixed step and nothing else.

## Fixed timestep

A system in a fixed schedule follows the same rule: it sees changes since its
own previous run, whether that was the previous step in this frame or a step in
an earlier frame. On a frame with no fixed steps it doesn't run, and it
catches up on the next one.

## Resources

Change detection covers components only. For resources, use the
`ChangeTracking` mixin or your own flag (see
[Resources](/docs/ecs/resources#per-frame-helpers)).

## See also

- [Queries](/docs/ecs/queries)
- [Observers](/docs/ecs/observers)
- [Commands](/docs/ecs/commands)
