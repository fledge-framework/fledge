# App & Plugins

`App` is the entry point of a Fledge game. It owns the `World` (entities,
components, resources, events) and the `Scheduler` (systems, grouped into
schedules), runs a frame when you call `tick()`, and gives you a fluent API to
configure both. A `Plugin` is a reusable chunk of that configuration: every
Fledge package ships one.

`App` and `Plugin` are in `fledge_ecs` (pure Dart). Full signatures are in the
[fledge_ecs API reference](https://pub.dev/documentation/fledge_ecs/latest/).

<!-- snippet-setup
class Position {
  double x, y;
  Position(this.x, this.y);
}

class Velocity {
  double dx, dy;
  Velocity(this.dx, this.dy);
}

class GameConfig {
  final int difficulty;
  const GameConfig({this.difficulty = 1});
}

class Score {
  int points = 0;
}

class CoinCollected {
  final int value;
  const CoinCollected(this.value);
}

enum GameState { menu, playing, paused }

final movement = FunctionSystem(
  'movement',
  reads: {ComponentId.of<Velocity>()},
  writes: {ComponentId.of<Position>()},
  run: (world) {},
);

final collectCoins = FunctionSystem(
  'collectCoins',
  eventReads: {CoinCollected},
  resourceWrites: {Score},
  run: (world) {},
);

final showMenu = FunctionSystem('showMenu', run: (world) {});
-->

## Building an app

```dart
final app = App()
  ..addPlugin(WallTimePlugin())
  ..insertResource(const GameConfig(difficulty: 2))
  ..insertResource(Score())
  ..addEvent<CoinCollected>()
  ..addState<GameState>(GameState.menu)
  ..addSystem(movement, schedule: Schedules.fixedUpdate)
  ..addSystems([collectCoins], schedule: Schedules.update)
  ..addSystemInState(showMenu, GameState.menu);
```

| Method | Does |
|---|---|
| `addPlugin(p)` / `addPlugins([...])` | Calls `p.build(app)` **immediately**, then remembers the plugin |
| `insertResource(r)` | Inserts (or replaces) a resource |
| `addEvent<T>()` | Registers an event type (see [Events](/docs/ecs/events)) |
| `addState<S>(initial)` | Adds a `State<S>` state machine (see [States & Run Conditions](/docs/ecs/states-run-conditions)) |
| `addSystem(s, schedule:)` | Adds a system; without `schedule:` it goes in `Schedules.update` |
| `addSystems([...], schedule:)` | Several systems into one schedule |
| `addSystemInState(s, state, schedule:)` | A system that only runs in `state` |
| `configureSet(name, (set) => ...)` / `addSystemToSet(s, name, schedule:)` | [System sets](/docs/scheduling/ordering-and-sets#system-sets): shared ordering and run conditions |

The methods return the `App`, so you can chain them with `..` or `.`.

`addSystem(..., stage: CoreStage.x)` still compiles but is deprecated: pass
`schedule: Schedules.x`. Likewise `app.schedule` is a deprecated alias for
`app.scheduler`.

### What every App starts with

`App()` inserts a default `FixedTimestep` resource: a step of 16 667 µs
(about 60 Hz), catching up at most 5 steps per frame. Replace it before the
first tick if your game needs a different rate:

```dart
final app = App()
  ..insertResource(
    FixedTimestep(
      stepDuration: const Duration(microseconds: 33333), // 30 Hz
      maxCatchupSteps: 3,
    ),
  );
```

Nothing else is added for you, not even a clock: add `WallTimePlugin` for the
`WallTime` resource (see [Time & Fixed Timestep](/docs/scheduling/time)).

## Running the frame

`app.tick()` runs one frame: it swaps the event buffers, runs `startup` (first
tick only), then every schedule in order (`first`, `preUpdate`, the fixed
chain 0..N times, `update`, `postUpdate`, `last`, `extract`, `render`), calls
the `onTick` callback, advances the change-detection tick, and applies state
transitions. See [Schedules & the Frame](/docs/scheduling/schedules).

How you call it depends on where the game runs.

### In Flutter

Your game widget calls `app.tick()` from a `Ticker`, once per display frame,
and paints after it completes. [Your First App](/docs/getting-started/first-app#the-frame-loop)
shows the full pattern, including handing `WallTime` the vsync clock. Don't
call `app.run()` in a Flutter app: its loop isn't paced by the display. When
the widget is done with the app, call `app.dispose()` from the widget's
`dispose` so plugins get their `cleanup` (see [When cleanup runs](#when-cleanup-runs)).

### Headless

For a server, a simulation or a console game, `run()` calls `tick()` in a loop
until `stop()`, then calls `onStop` and `dispose()`. After each tick it yields
to the event loop, so timers, I/O and stream events get a turn every frame
even when every system is synchronous:

```dart
Future<void> main() async {
  var frames = 0;
  final app = App()
    ..addPlugin(WallTimePlugin())
    ..addPlugin(const FrameLimiterPlugin(targetFps: 30))
    ..onStart((app) => print('starting'))
    ..onTick((app) {
      if (++frames == 90) app.stop(); // about three seconds
    })
    ..onStop((app) => print('stopped after $frames frames'));

  await app.run();
}
```

On its own, `run()` runs frames as fast as it can. `FrameLimiterPlugin` caps it: a
`FrameStartSystem` in `first` and a `FrameLimiterSystem` in `last` that waits
out the rest of each frame (drift-corrected, yielding to the event loop while
it waits). It's for standalone loops only: in Flutter the display already
paces frames, and the limiter would stall your tick. It inserts a `FrameTime`
resource whose `frameTime`, `sleepTime` and `totalTime` are in seconds, plus
`fps`.

`AppRunner(app, targetFrameTime: ...)` is an older, simpler pacer
(`Future.delayed` between ticks). `AppRunner.runFrames(n)` ticks `n` times.

### In tests

`await app.tick()` as many times as you need. `await app.runStartup()` runs
the `startup` schedule on its own (once; `tick` then skips it), so you can
inspect the world before the first frame. `app.update()` is an alias for
`tick()`.

## Plugins

A plugin is a class with a `build(App app)` method that adds whatever its
feature needs:

```dart
class ScoringPlugin extends Plugin {
  ScoringPlugin({this.startingScore = 0});

  final int startingScore;

  @override
  void build(App app) {
    app
      ..insertResource(Score()..points = startingScore)
      ..addEvent<CoinCollected>()
      ..addSystem(collectCoins, schedule: Schedules.update);
  }

  @override
  void cleanup() {
    // Optional: release anything build() acquired.
  }
}

final app = App()..addPlugin(ScoringPlugin(startingScore: 10));
```

For a one-off, `FunctionPlugin` wraps a function:

```dart
final debugSetup = FunctionPlugin((app) {
  app.insertResource(const GameConfig(difficulty: 0));
});

final app = App()..addPlugin(debugSetup);
```

### Plugin order matters

`build` runs inside `addPlugin`, in the order you add plugins. Two
consequences:

- A plugin that reads another plugin's resource at build time needs that
  plugin added first. For example `RenderPlugin` (from `fledge_render_2d`)
  must come before the lighting, particle and UI plugins, which register
  with its resources.
- Systems from different plugins that conflict but have no explicit
  `before:`/`after:` run in **registration order**, so reordering
  `addPlugin` calls can silently reorder them. Order against built-in
  systems with their `systemName` constants, use the standard phases
  (`FirstSets`, `UpdateSets`), and run `checkScheduleOrdering` in a test.

### When cleanup runs

`app.dispose()` calls every plugin's `cleanup()` once, in reverse order of
addition. `run()` calls it when its loop ends; an app you tick yourself (a
Flutter widget's `Ticker`) needs you to call it, typically from the widget's
`dispose`. It's idempotent, and afterwards `tick()`, `run()` and
`resetToSessionCheckpoint()` throw a `StateError`; `isDisposed` tells you
whether it has happened. `resetToSessionCheckpoint` (below) also calls
`cleanup` on the plugins it removes.

```dart
final app = App()..addPlugin(WallTimePlugin());
await app.tick();
app.dispose(); // WallTimePlugin.cleanup runs once
```

### Plugin groups

`PluginGroup` bundles plugins: override `plugins`, and adding the group builds
each of them, in order.

```dart
class GamePlugins extends PluginGroup {
  @override
  List<Plugin> get plugins => [
    WallTimePlugin(),
    FunctionPlugin((app) => app.insertResource(Score())),
  ];
}

final app = App()..addPlugin(GamePlugins());
```

The group is a single plugin as far as the app is concerned: each child is
built once per build (and once more per `resetToSessionCheckpoint`) and
cleaned up once, in reverse order, when the group is. `plugins` is read on the
first build only, so a getter that creates new instances, as above, is fine:
the instances that were built are the ones cleaned up. Fledge itself ships no
plugin groups.

## Checking the schedule

```dart
final app = App()
  ..addSystem(movement)
  ..addSystem(
    FunctionSystem(
      'clamp',
      writes: {ComponentId.of<Position>()},
      run: (world) {},
    ),
  );

for (final issue in app.checkScheduleOrdering()) {
  // movement runs before clamp by registration order only.
  // Reasons: both write component Position. Add
  // `before: [<clamp's systemName>]` to movement, or ...
  print(issue);
}
```

`checkScheduleOrdering()` returns one `OrderingAmbiguity` per pair of
conflicting systems whose order comes only from registration. Its
`suggestion` names the fix in terms of `systemName` constants: for
class-based systems the class is known, so it reads
`before: [ClampSystem.systemName]`; for function systems it describes the
constant instead. Keep it empty
with a test. See
[Ordering & Sets](/docs/scheduling/ordering-and-sets#checking-with-checkscheduleordering).

## Checkpoints: menus and level changes

`App` has two checkpoints for games that go back to a menu or swap levels
without rebuilding everything.

**Session checkpoint.** Call `markSessionCheckpoint()` after adding the
plugins that should live as long as the program (window, audio, input).
`resetToSessionCheckpoint()` then:

1. calls `cleanup` on every plugin added after the checkpoint, newest first,
   and forgets them,
2. removes **every** system and builds the remaining plugins again (so they
   re-insert their resources and re-add their systems),
3. despawns all entities and clears all events.

Resources are kept unless a plugin's `cleanup` removes them or its `build`
replaces them. `startup` doesn't run again.

**Game checkpoint.** Call `markGameCheckpoint()` after spawning entities that
should survive a level change (the player, the camera).
`resetToGameCheckpoint()` despawns every entity spawned since and clears the
event queues, keeping resources, plugins and systems. It throws a
`StateError` if no checkpoint was marked; `hasGameCheckpoint` and
`clearGameCheckpoint()` go with it.

```dart
final app = App()..addPlugin(WallTimePlugin());

app.world.spawnWith([Position(0, 0)]); // the player
app.markGameCheckpoint();

app.world.spawnWith([Position(5, 5)]); // level 1 scenery
app.resetToGameCheckpoint(); // scenery gone, player kept
```

## Plugins in fledge_ecs

`fledge_ecs` itself has two:

| Plugin | Adds |
|---|---|
| `WallTimePlugin` | The `WallTime` resource and `WallTimeUpdateSystem` (in `first`) |
| `FrameLimiterPlugin({targetFps})` | Frame pacing for headless `run()` loops (above) |

Everything else (rendering, input, physics...) comes from the other packages:
see the [Package Catalog](/docs/app/packages).

## See also

- [Schedules & the Frame](/docs/scheduling/schedules)
- [Ordering & Sets](/docs/scheduling/ordering-and-sets)
- [Systems](/docs/ecs/systems)
- [Package Catalog](/docs/app/packages)
