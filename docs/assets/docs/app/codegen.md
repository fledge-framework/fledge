# Code Generation

`fledge_ecs_generator` lets you write a system as an annotated top-level
function. The function's **parameter types** say what it needs (queries,
resources, events, commands), and the generator writes a `System` class around
it with a matching `SystemMeta`. It's optional: a generated system behaves
exactly like a hand-written one, and you can mix both in one game.

Code generation is pure Dart and works in Flutter and non-Flutter projects
alike.

## Setup

```yaml
dependencies:
  fledge_ecs: ^0.7.1

dev_dependencies:
  build_runner: ^2.10.4
  fledge_ecs_generator: ^0.7.1
```

`fledge_ecs` re-exports the annotations, so importing
`package:fledge_ecs/fledge_ecs.dart` is enough; `fledge_ecs_annotations` is
only needed as a direct dependency if you import it yourself.

Each file with annotations declares its generated part, named after the file:

```dart fragment
// lib/game_systems.dart
import 'package:fledge_ecs/fledge_ecs.dart';

part 'game_systems.g.dart';
```

Then generate:

```bash
dart run build_runner build    # once
dart run build_runner watch    # regenerate on every save
```

- The `.g.dart` file is a `part` of your file. Never import it: import
  `game_systems.dart` and the generated classes come with it.
- Until it's generated, the analyzer reports the `part` as missing and the
  wrapper classes as undefined. Run `build_runner` again after changing an
  annotated function.
- If you don't commit generated files, CI must run
  `dart run build_runner build` before `dart analyze` and the tests.
- The generator writes `<file>.g.dart` itself, so it can't share a file with
  another generator that also writes `.g.dart` (`json_serializable`, for
  example). Keep annotated systems in their own files.

## Writing a system

The rest of `lib/game_systems.dart`:

```dart
class Position {
  double x, y;
  Position(this.x, this.y);
}

class Velocity {
  double dx, dy;
  Velocity(this.dx, this.dy);
}

class Enemy {}

class Score {
  int points = 0;
}

class WaveConfig {
  final int size;
  const WaveConfig(this.size);
}

class CoinCollected {
  final int value;
  const CoinCollected(this.value);
}

@system
void movement(QueryMut2<Position, Velocity> query, Res<WallTime> time) {
  final dt = time.value.delta;
  for (final (_, pos, vel) in query.iter()) {
    pos.x += vel.dx * dt;
    pos.y += vel.dy * dt;
  }
}

@system
void scoreCoins(EventReader<CoinCollected> coins, ResMut<Score> score) {
  for (final coin in coins.read()) {
    score.value.points += coin.value;
  }
}

@system
void spawnWave(
  Query1<Enemy> enemies,
  ResOption<WaveConfig> config,
  Commands commands,
) {
  if (enemies.isNotEmpty) return;
  final size = config.value?.size ?? 3;
  for (var i = 0; i < size; i++) {
    commands.spawn()
      ..insert(Enemy())
      ..insert(Position(i * 40.0, 0))
      ..insert(Velocity(0, 30));
  }
}

@system
void clampToScreen(QueryMut1<Position> positions) {
  for (final (_, pos) in positions.iter()) {
    if (pos.y > 600) pos.y = 600;
  }
}
```

Register the generated **wrapper** classes (the function name in PascalCase
plus `Wrapper`), never the functions:

```dart fragment
final app = App()
  ..addPlugin(WallTimePlugin())
  ..insertResource(Score())
  ..addEvent<CoinCollected>()
  ..addSystem(MovementWrapper(), schedule: Schedules.fixedUpdate)
  ..addSystem(ScoreCoinsWrapper(), schedule: Schedules.update)
  ..addSystem(SpawnWaveWrapper(), schedule: Schedules.update);
```

The schedule is chosen here, at registration. Passing a stage to the
annotation (`@SystemAnnotation(stage: CoreStage.postUpdate)`) is accepted for
compatibility and **ignored**.

## Parameter types

Every parameter must be one of these types. The generator reads only the
signature, never the function body.

| Parameter | The wrapper passes | Declared in `SystemMeta` |
|---|---|---|
| `Query1<A>` .. `Query4<A, B, C, D>` | `world.queryN<...>()` | `reads` every type |
| `QueryMut1<A>` .. `QueryMut4<A, B, C, D>` | `world.queryMutN<...>()` | `writes` every type |
| `Res<T>` | the resource (`.value`); throws if it's missing | `resourceReads: {T}` |
| `ResMut<T>` | the resource (`.value`); throws if it's missing | `resourceWrites: {T}` |
| `ResOption<T>` | the resource or `null` (`.value`, `.exists`) | `resourceReads: {T}` |
| `EventReader<T>` | `world.eventReader<T>()` | `eventReads: {T}` |
| `EventWriter<T>` | `world.eventWriter<T>()` | `eventWrites: {T}` |
| `EventReadWriter<T>` | a reader-writer on the same queue | `eventReads` and `eventWrites` |
| `Commands` | a fresh `Commands`, **applied after your function returns** | nothing |
| `World` (any name) | the world itself | nothing, plus a build warning |

`Query` and `QueryMut` behave identically at runtime (both hand out mutable
components); the difference is only the access they declare. Use `Query` when
you only read, so readers don't conflict with each other, and `QueryMut` when
you write.

A `World` parameter works, but the generator can't see what you do through
it, so the system declares no access and is never ordered against systems it
conflicts with. `build_runner` prints a warning for each one. Prefer the typed
parameters, or hand-write the system.

A function returning `Future<void>` (an `async` function) gets an async
wrapper that awaits it, so the scheduler waits too. That costs an event-loop
turn every frame; keep systems synchronous unless they truly wait (see
[Systems](/docs/ecs/systems#keep-systems-synchronous)).

## What gets generated

For `movement` above, `game_systems.g.dart` contains:

```dart fragment
/// Generated system wrapper for [movement].
class MovementWrapper implements System {
  /// Name used in [SystemMeta] and for `before:`/`after:`.
  static const String systemName = 'movement';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    writes: {ComponentId.of<Position>(), ComponentId.of<Velocity>()},
    resourceReads: {WallTime},
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => runCondition?.call(world) ?? true;

  @override
  void run(World world) {
    final query = world.queryMut2<Position, Velocity>();
    final time = Res<WallTime>(world.getResource<WallTime>()!);
    movement(query, time);
  }
}
```

and for `spawnWave`, the `Commands` are applied once the function returns:

```dart fragment
  @override
  void run(World world) {
    final enemies = world.query1<Enemy>();
    final config = ResOption<WaveConfig>(world.getResource<WaveConfig>());
    final commands = Commands();
    spawnWave(enemies, config, commands);
    commands.apply(world);
  }
```

## Ordering and run conditions

The annotation can't declare `before:`, `after:`, sets or a run condition.
Instead:

- **Other systems** can order against a generated one through its
  `systemName` constant: `after: [MovementWrapper.systemName]`.
- **The generated system itself** joins a [system set](/docs/scheduling/ordering-and-sets#system-sets),
  and the set carries the ordering and run conditions:

```dart fragment
final app = App()
  ..configureSet('clamping', (set) => set.after(MovementWrapper.systemName))
  ..addSystem(MovementWrapper(), schedule: Schedules.update)
  ..addSystemToSet(ClampToScreenWrapper(), 'clamping',
      schedule: Schedules.update);
```

- **States**: `app.addSystemInState(MovementWrapper(), GameState.playing)`.

If that gets awkward, write the system by hand.

## Limits

- **No filters.** A query parameter can't carry `With`, `Without`, `Added` or
  `Changed` filters. Read the filtered query from a `World` parameter (and
  lose the access declaration), or hand-write the system.
- **No mixed access in one query.** `QueryMut2<Position, Velocity>` declares
  writes on both, even if you only write `Position`. That's safe (it can only
  add conflicts, never hide one), but it can force ordering you don't need.
  Two parameters (`Query1<Velocity>`, `QueryMut1<Position>`) declare it
  exactly, but they're separate queries: you can't walk them in step for the
  same entity. When that matters, hand-write the system (below).
- **Top-level functions only.** `@system` on a method or local function is a
  build error.
- **Plain, unprefixed types.** Type arguments are written into the generated
  file by class name, so generic component or resource types (`Res<Map<String, int>>`)
  and types imported with a prefix (`import ... as phys`) don't work.
- **Unsupported parameters break the build.** Any other parameter type
  produces a wrapper that doesn't compile.

### The hand-written equivalent

When generation doesn't fit, write the class yourself; it's what the wrapper
would have been, with the access you actually mean (and room for `before:`,
`after:` and `sets:`):

```dart
class Position {
  double x, y;
  Position(this.x, this.y);
}

class Velocity {
  double dx, dy;
  Velocity(this.dx, this.dy);
}

class MovementSystem extends System {
  static const String systemName = 'movement';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    reads: {ComponentId.of<Velocity>()},
    writes: {ComponentId.of<Position>()},
    resourceReads: {WallTime},
  );

  @override
  void run(World world) {
    final dt = world.getResource<WallTime>()!.delta;
    for (final (_, pos, vel) in world.query2<Position, Velocity>().iter()) {
      pos.x += vel.dx * dt;
      pos.y += vel.dy * dt;
    }
  }
}
```

## The other annotations

- **`@component`** generates an extension with a static `componentId`
  (`PositionComponentExtension.componentId`). It's a convenience only: any
  class is a component, and `ComponentId.of<Position>()` works without it.
- **`@resource`** and **`@event`** exist but generate nothing. Any class can
  be a resource or an event without them.

## See also

- [Systems](/docs/ecs/systems)
- [Queries](/docs/ecs/queries)
- [Ordering & Sets](/docs/scheduling/ordering-and-sets)
- The [Basic ECS example](/docs/examples/basic-ecs), whose
  `query_marker_fixtures.dart` shows the generated output for each parameter
  kind
