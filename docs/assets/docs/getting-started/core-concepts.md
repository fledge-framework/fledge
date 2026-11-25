# Core Concepts

A tour of the ideas Fledge is built on. Each section is a summary; follow the
links for the full story.

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
  int value;
  Health(this.value);
}

class Player {
  const Player();
}

class Enemy {
  const Enemy();
}

class Score {
  int points = 0;
}

class EnemyDefeated {
  final Entity enemy;
  const EnemyDefeated(this.enemy);
}
-->

## Entities

An `Entity` is a lightweight ID: an index plus a **generation**. When an
entity is despawned its index can be reused, and the generation goes up, so an
old `Entity` value never refers to the new occupant by mistake:

```dart
final world = World();

final first = world.spawn().entity;
world.despawn(first);
final second = world.spawn().entity; // may reuse the index

print(world.isAlive(first)); // false: the generation no longer matches
print(world.isAlive(second)); // true
```

Holding an `Entity` in a component or resource is the normal way to refer to
another entity (a target, an owner). Check `world.isAlive` before using one
that might be gone. More in [Entities & Components](/docs/ecs/entities-components).

## Components

Components are plain Dart classes holding data. An entity has at most one
component of each type. Keep them small and focused; a class with no fields
is a **marker** that tags an entity (`Player`, `Enemy`):

```dart
final world = World();

final hero = world.spawnWith([Position(0, 0), Health(100), const Player()]);

world.get<Health>(hero)!.value -= 10; // read and change in place
world.insert(hero, Velocity(5, 0)); // add a component
world.remove<Velocity>(hero); // remove it
print(world.has<Player>(hero)); // true
```

Entities with the same set of component types are stored together (an
**archetype**), so iterating over "everything with `Position` and `Velocity`"
walks dense arrays.

## Queries

A query finds every entity with a given set of components, with optional
filters:

```dart
final world = World()
  ..spawnWith([Position(0, 0), Velocity(1, 0), const Player()])
  ..spawnWith([Position(5, 5), Velocity(0, 1), const Enemy()]);

for (final (entity, pos, vel) in world.query2<Position, Velocity>().iter()) {
  pos.x += vel.dx;
}

// Only enemies.
for (final (_, pos) in world.query1<Position>(filter: const With<Enemy>()).iter()) {
  print('enemy at ${pos.x}, ${pos.y}');
}
```

`query1` to `query4` take one to four component types. Filters include
`With<T>`, `Without<T>`, `Added<T>`, `Changed<T>` and `And`. See
[Queries](/docs/ecs/queries) and [Change Detection](/docs/ecs/change-detection).

## Systems

A system is game logic: an object with a `run(World world)` method and a
`SystemMeta` describing what it reads and writes.

```dart
class DamageOverTime extends System {
  static const String systemName = 'damageOverTime';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    writes: {ComponentId.of<Health>()},
    reads: {ComponentId.of<Enemy>()},
  );

  @override
  void run(World world) {
    for (final (_, health) in world.query1<Health>(filter: const With<Enemy>()).iter()) {
      health.value -= 1;
    }
  }
}
```

The declarations feed the scheduler: two systems **conflict** when one writes
something the other reads or writes, and conflicting systems are kept in a
fixed order. Systems run one at a time; Dart gives your game a single
isolate. For small systems, `FunctionSystem('name', run: (world) {...})`
saves the class. See [Systems](/docs/ecs/systems).

## Resources

A resource is a single value stored on the world, not on an entity: the score,
the game settings, the time.

```dart
final world = World()..insertResource(Score());

world.getResource<Score>()!.points += 10;
```

Systems declare resource access with `resourceReads:` / `resourceWrites:`.
See [Resources](/docs/ecs/resources).

## Events

Events let one system tell others that something happened, without either
knowing about the other. They're double-buffered: an event sent in one frame
is read in the next.

```dart
final app = App()..addEvent<EnemyDefeated>();
final world = app.world;

// In one system:
world.eventWriter<EnemyDefeated>().send(EnemyDefeated(world.spawn().entity));

// In another, on the next frame:
for (final event in world.eventReader<EnemyDefeated>().read()) {
  world.getResource<Score>()?.points += 100;
}
```

See [Events](/docs/ecs/events).

## Commands

A `Commands` buffer queues spawns, despawns and component changes and applies
them together. It's the tidy way to change the world's structure from inside a
system:

```dart
final world = World()..spawnWith([Health(0), const Enemy()]);

final commands = Commands();
for (final (entity, health) in world.query1<Health>().iter()) {
  if (health.value <= 0) commands.despawn(entity);
}
commands.apply(world);
```

See [Commands](/docs/ecs/commands).

## Hierarchies and observers

Entities can have parents and children (`world.spawnChild(parent)`,
`world.despawnRecursive(root)`), used for things like a turret riding a ship.
Observers run a callback when a component is added, removed or replaced. See
[Hierarchies](/docs/ecs/hierarchies) and [Observers](/docs/ecs/observers).

## The App and plugins

`App` owns the world and the scheduler and runs the frame. You configure it
fluently, and a **plugin** packages a feature's resources, events and systems
behind one `addPlugin` call:

```dart
class CombatPlugin extends Plugin {
  @override
  void build(App app) {
    app
      ..insertResource(Score())
      ..addEvent<EnemyDefeated>()
      ..addSystem(
        FunctionSystem(
          'scoreDefeats',
          eventReads: {EnemyDefeated},
          resourceWrites: {Score},
          run: (world) {
            for (final _ in world.eventReader<EnemyDefeated>().read()) {
              world.getResource<Score>()!.points += 100;
            }
          },
        ),
        schedule: Schedules.update,
      );
  }
}

final app = App()
  ..addPlugin(WallTimePlugin())
  ..addPlugin(CombatPlugin());
```

Every Fledge package (input, physics, rendering...) is a plugin you add the
same way. See [App & Plugins](/docs/app/app-and-plugins).

## The frame

Each `app.tick()` runs the schedules in this order:

| Schedule | Use it for |
|---|---|
| `startup` | One-time setup, on the first tick only |
| `first` | Frame-start bookkeeping: time, input polling |
| `preUpdate` | Turning input into intent (movement, steering) |
| `fixedFirst` → `fixedPreUpdate` → `fixedUpdate` → `fixedPostUpdate` → `fixedLast` | Physics and deterministic simulation, run 0..N times per frame at a fixed step |
| `update` | Most game logic. The default when you don't pass `schedule:` |
| `postUpdate` | Reacting to `update`: camera follow, UI layout |
| `last` | End-of-frame cleanup |
| `extract` | Copy what's visible into the render world |
| `render` | Render systems, on the render world |

Then state transitions are applied, ready for the next frame. Physics belongs
in the fixed schedules (usually `fixedUpdate`), where every step has the same
length, not in `update` or `postUpdate`. See
[Schedules & the Frame](/docs/scheduling/schedules) and
[Time & Fixed Timestep](/docs/scheduling/time).

## Ordering

Within a schedule, the order is computed once from explicit
`before:`/`after:` constraints and [system sets](/docs/scheduling/ordering-and-sets#system-sets).
Two conflicting systems with no explicit order between them fall back to
**registration order**, which changes silently when you add or reorder
plugins. `app.checkScheduleOrdering()` lists every such pair; keep it empty
with a test:

```dart
class ApplyDamage extends System {
  static const String systemName = 'applyDamage';

  @override
  SystemMeta get meta =>
      SystemMeta(name: systemName, writes: {ComponentId.of<Health>()});

  @override
  void run(World world) {}
}

class Regenerate extends System {
  static const String systemName = 'regenerate';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    writes: {ComponentId.of<Health>()},
    after: [ApplyDamage.systemName], // remove this and the assert fails
  );

  @override
  void run(World world) {}
}

void main() {
  final app = App()
    ..addSystem(Regenerate())
    ..addSystem(ApplyDamage());

  assert(app.checkScheduleOrdering().isEmpty);
}
```

Always name the other system by its `systemName` constant, never a string
literal. See [Ordering & Sets](/docs/scheduling/ordering-and-sets).

## Two worlds

Rendering with `fledge_render_2d` uses a second world. Each frame, in the
`extract` schedule, **extractors** copy what's needed for drawing from the
main world into a `RenderWorld` that is cleared and rebuilt from scratch. The
widget paints only the render world. Keep game logic in the main world, and
never expect a render-world entity to survive to the next frame. See
[Rendering Overview](/docs/rendering/overview).

## States and run conditions

`app.addState<GameState>(GameState.menu)` adds a state machine;
`addSystemInState(system, GameState.playing)` runs a system only in that
state, and `runIf:` gates any system on a condition. See
[States & Run Conditions](/docs/ecs/states-run-conditions).

Next: [Tutorial: Snake](/docs/getting-started/tutorial-snake).
