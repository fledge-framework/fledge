# Resources

A **resource** is a global singleton stored in the world by type: the score,
game settings, an RNG, a spatial index. Use a resource for data there's exactly
one of, and a component for data that belongs to an entity.

<!-- snippet-setup
class Score {
  int points = 0;
  int best = 0;
}

class GameSettings {
  double musicVolume;
  bool showFps;
  GameSettings({this.musicVolume = 0.8, this.showFps = false});
}

class Coin {}
-->

## Defining and inserting

A resource is any class:

```dart
import 'package:fledge_ecs/fledge_ecs.dart';

class Score {
  int points = 0;
  int best = 0;
}

class GameSettings {
  double musicVolume;
  bool showFps;
  GameSettings({this.musicVolume = 0.8, this.showFps = false});
}
```

Insert it while building the app, or on the world at any time. Inserting a
second value of the same type replaces the first:

```dart
final app = App()
  ..insertResource(Score())
  ..insertResource(GameSettings(showFps: true));

// Later, from anywhere with the world:
app.world.insertResource(Score()); // replaces the old Score
```

Resources are keyed by the **static type** you insert them as. That's usually
the class itself; if you insert through a variable typed as an interface, the
interface is the key.

`App` inserts one resource itself: a default
[`FixedTimestep`](/docs/scheduling/time#fixed-timestep). Plugins insert their
own (for example, `WallTimePlugin` adds `WallTime`).

## Using resources in systems

Read a resource with `getResource<T>()`, which returns null if it's missing,
and declare the access in `SystemMeta` so the scheduler can order systems that
share it:

```dart
class CollectCoinsSystem extends System {
  static const String systemName = 'collectCoins';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    reads: {ComponentId.of<Coin>()},
    resourceWrites: {Score},
  );

  @override
  void run(World world) {
    final score = world.getResource<Score>();
    if (score == null) return;
    final commands = Commands();
    for (final (entity, _) in world.query1<Coin>().iter()) {
      score.points += 10;
      commands.despawn(entity);
    }
    commands.apply(world);
    if (score.points > score.best) score.best = score.points;
  }
}
```

Two systems that write the same resource, or where one writes and the other
reads it, conflict: give them an explicit order (see
[Ordering & Sets](/docs/scheduling/ordering-and-sets)).

Use `!` only for resources your own plugin guarantees. For optional ones,
handle null:

```dart
final world = World();

final settings = world.getResource<GameSettings>();
final volume = settings?.musicVolume ?? 1.0;
```

## Other world methods

```dart
final world = World()..insertResource(Score());

world.hasResource<Score>(); // true
final removed = world.removeResource<Score>(); // the Score, or null

// Get, inserting a default the first time.
final score = world.resources.getOrInsert<Score>(Score.new);
```

### Finding resources by interface

`getResource<T>` looks up by exact key. `resourcesOfType<T>()` scans every
resource and returns those that are instances of `T`, which lets a plugin find
resources by a mixin or interface without knowing their concrete types
(`fledge_save` finds `Saveable` resources this way):

```dart
abstract interface class Resettable {
  void reset();
}

class Combo implements Resettable {
  int count = 0;
  @override
  void reset() => count = 0;
}

void resetAll(World world) {
  for (final r in world.resourcesOfType<Resettable>()) {
    r.reset();
  }
}
```

## Generated systems: `Res`, `ResMut`, `ResOption`

With code generation, an `@system` function asks for resources by parameter
type, and the generator declares the access for you: `Res<T>` is a read,
`ResMut<T>` a write, and `ResOption<T>` an optional read (`.value` may be
null). Read the value with `.value` or by calling the wrapper (`score()`):

```dart fragment
@system
void scoreDisplay(Res<Score> score, ResOption<GameSettings> settings) {
  if (settings.value?.showFps ?? false) print('score ${score.value.points}');
}
```

See [Code Generation](/docs/app/codegen).

## Per-frame helpers

Two small utilities help resources that track "what happened this frame".
Neither is called automatically, so add a system that calls them.

**`ChangeTracking`** is a mixin with a `changedThisFrame` flag:

```dart
class Inventory with ChangeTracking {
  final List<String> items = [];

  void add(String item) {
    items.add(item);
    markChanged();
  }
}

final resetInventoryFlags = FunctionSystem(
  'resetInventoryFlags',
  resourceWrites: {Inventory},
  run: (world) => world.getResource<Inventory>()?.resetChangeTracking(),
);
```

A UI system can then rebuild only when `inventory.changedThisFrame` is true.

**`FrameAware`** is an interface with `beginFrame()`. Call it only on resources
that implement it:

```dart
class HitStop implements FrameAware {
  bool triggeredThisFrame = false;

  @override
  void beginFrame() => triggeredThisFrame = false;
}

final beginFrames = FunctionSystem(
  'beginFrames',
  sets: [FirstSets.frameStart],
  resourceWrites: {HitStop},
  run: (world) {
    for (final r in world.resourcesOfType<FrameAware>()) {
      r.beginFrame();
    }
  },
);
```

Registered in `Schedules.first`, that system runs in the frame-start phase.

## Time

Don't define your own time resource: `WallTimePlugin` provides `WallTime`
(`delta`, `elapsed`, `frameCount`), and every `App` has a `FixedTimestep`. Both
are covered on [Time & Fixed Timestep](/docs/scheduling/time).

## Resource or component?

| Use a resource for | Use a component for |
|---|---|
| One of it per game: score, settings, RNG | One per entity: position, health |
| Data many systems share | Data you query across many entities |
| Services: an asset cache, a spatial grid | Tags that filter queries |

If you find yourself adding a marker so you can `single()` an entity that
only ever exists once and has no other components, it's probably a resource.

## See also

- [Systems](/docs/ecs/systems)
- [Events](/docs/ecs/events)
- [Time & Fixed Timestep](/docs/scheduling/time)
