# Schedules & the Frame

Every system lives in a **schedule**: a named group of systems that runs at a
fixed point in the frame. You pick the schedule when you register the system:

<!-- snippet-setup
class SpawnWorldSystem extends System {
  @override
  SystemMeta get meta => const SystemMeta(name: 'spawnWorld');

  @override
  void run(World world) {}
}

class PlayerIntentSystem extends System {
  @override
  SystemMeta get meta => const SystemMeta(name: 'playerIntent');

  @override
  void run(World world) {}
}

class StepSimulationSystem extends System {
  @override
  SystemMeta get meta => const SystemMeta(name: 'stepSimulation');

  @override
  void run(World world) {}
}

class GameLogicSystem extends System {
  @override
  SystemMeta get meta => const SystemMeta(name: 'gameLogic');

  @override
  void run(World world) {}
}

class CleanupSystem extends System {
  @override
  SystemMeta get meta => const SystemMeta(name: 'cleanup');

  @override
  void run(World world) {}
}
-->

```dart
final app = App()
  ..addSystem(SpawnWorldSystem(), schedule: Schedules.startup)
  ..addSystem(PlayerIntentSystem(), schedule: Schedules.preUpdate)
  ..addSystem(StepSimulationSystem(), schedule: Schedules.fixedUpdate)
  ..addSystem(GameLogicSystem()) // Schedules.update is the default
  ..addSystem(CleanupSystem(), schedule: Schedules.last);
```

## The frame

Each `App.tick()` does this, in order:

| # | Schedule | Use it for |
|---|---|---|
| 0 | *(event buffers swap)* | Last frame's [events](/docs/ecs/events) become readable |
| 1 | `startup` | One-time setup. **First tick only.** |
| 2 | `first` | Frame-start bookkeeping: wall time, window and audio sync, input polling, content spawning (see [phases](#phases-of-first-and-update)) |
| 3 | `preUpdate` | Input-driven writes: movement intent, AI steering |
| 4 | `fixedFirst` → `fixedPreUpdate` → `fixedUpdate` → `fixedPostUpdate` → `fixedLast` | Physics and deterministic simulation. The whole chain runs **0..N times** per frame (see [Time & Fixed Timestep](/docs/scheduling/time)) |
| 5 | `update` | Core game logic that doesn't need a fixed step. The default |
| 6 | `postUpdate` | Reactions to `update`: camera follow, UI layout |
| 7 | `last` | Cleanup, end-of-frame work |
| 8 | `extract` | `fledge_render_2d` copies render data from the main world into the render world |
| 9 | `render` | Render systems on the render world |
| 10 | *(end of tick)* | `onTick` callback, frame tick advances, [state transitions](/docs/ecs/states-run-conditions#when-transitions-happen) apply |

All schedule labels are constants on `Schedules`. `stage: CoreStage.x` on
`addSystem` is deprecated; pass `schedule: Schedules.x`.

### Choosing a schedule

- **Reads input, sets intent?** `preUpdate`. Input is polled in `first`, so it's
  current by then.
- **Moves things by physics, or must be deterministic?** A fixed schedule,
  usually `fixedUpdate`. A fixed step has a constant `dt`, so the result
  doesn't depend on frame rate. Don't put physics in `postUpdate`.
- **Everything else in gameplay?** `update`.
- **Must see the results of `update`?** `postUpdate`.
- **Draws?** You rarely add systems to `extract` or `render` yourself; the
  render plugins do. See [Rendering Overview](/docs/rendering/overview).

`fledge_physics` runs in `update` by default (`PhysicsMode.variable`, scaled
by `WallTime.delta`) and in `fixedUpdate` with `PhysicsMode.fixed`; see
[Physics](/docs/gameplay/physics).

## Phases of `first` and `update`

`first` and `update` are shared by many plugins, so the default scheduler
splits them into ordered phases, defined as
[system set](/docs/scheduling/ordering-and-sets#system-sets) names:

| Phase | Order | Built-in members |
|---|---|---|
| `FirstSets.frameStart` | 1st in `first` | `WallTimeUpdateSystem`, `FrameStartSystem`, the calendar, `fledge_debug` stats |
| `FirstSets.platform` | 2nd | window init/sync/OS events, audio init/events/focus, network pump |
| `FirstSets.input` | 3rd | input polling, context update, action resolution |
| `FirstSets.content` | 4th | asset hot reload, tilemap spawning |
| `UpdateSets.receive` | 1st in `update` | network interpolation of remote entities |
| `UpdateSets.simulate` | 2nd | `fledge_physics` in variable mode |

Every system in an earlier phase runs before every system in a later one,
whatever order the plugins were added in. A system joins a phase with
`sets:`, or orders itself against a whole phase with `before:`/`after:`
(set names work anywhere a system name does):

```dart
// Join the input phase of `first`.
final rumble = FunctionSystem(
  'gamepadRumble',
  sets: [FirstSets.input],
  run: (world) {},
);

// Run after every content system, without joining a phase.
final levelIntro = FunctionSystem(
  'levelIntro',
  after: [FirstSets.content],
  run: (world) {},
);

final app = App()
  ..addSystem(rumble, schedule: Schedules.first)
  ..addSystem(levelIntro, schedule: Schedules.first);
```

A system in `first` or `update` that joins no phase isn't ordered against the
phases, so `App.checkScheduleOrdering()` reports it if it conflicts with a
phased system. Use the phases (rather than another package's system names) to
order against packages yours doesn't depend on.

## Within a schedule

Systems in a schedule run **one at a time**; Dart has one isolate, so there's
no parallel execution. The order is computed from:

1. explicit `before:`/`after:` on systems and sets, then
2. for pairs that **conflict** (one writes what the other reads or writes) and
   aren't ordered explicitly, registration order.

Systems that don't conflict have no guaranteed order between them. The
registration-order fallback is a trap; see
[Ordering & Sets](/docs/scheduling/ordering-and-sets).

`before:`/`after:` only work within one schedule. Across schedules, the frame
order above is the order.

## Custom schedules

A `Schedule` is just a name. Register your own on the scheduler, add systems,
and run it yourself. `App.tick` only runs the standard schedules:

```dart
const spawnWave = Schedule('spawnWave');

final app = App();
app.scheduler.addSchedule(spawnWave);
app.addSystem(
  FunctionSystem('spawnEnemies', run: (world) {}),
  schedule: spawnWave,
);

// Whenever a wave should start, e.g. from an onTick callback or a test:
await app.scheduler.runSchedule(spawnWave, app.world);
```

Adding a system to an unregistered schedule throws a `StateError`.

## The `Scheduler`

`App.scheduler` is the runtime container (`App.schedule` is a deprecated
alias). Useful members:

| Member | Purpose |
|---|---|
| `addSchedule(s)` / `runSchedule(s, world)` | Custom schedules |
| `configureSet(name, (s) => ...)` | Set ordering and run conditions (`App.configureSet` delegates here) |
| `checkOrderingAmbiguities()` | What `App.checkScheduleOrdering()` returns |
| `systemCount`, `getStage(name)` | Introspection |
| `systemTimer` | Callback that times every system run (used by `fledge_debug`) |
| `clear()` | Removes all systems, keeps schedules and set configuration |

`Scheduler()` registers every standard schedule and chains the `FirstSets` and
`UpdateSets` phases. `Scheduler.empty()` registers nothing and configures no
phases, for tools that build their own pipeline.

`Scheduler.run(world)` is a compatibility shim: it runs `first` through
`render` once but **skips `startup` and the fixed-timestep chain**, and
doesn't swap event buffers, apply state transitions or advance ticks. With an
`App`, call `app.tick()`.

## Driving the frame

- **Flutter**: your game widget calls `app.tick()` from a `Ticker` (an
  `AnimationController` listener, for example), once per display frame, and
  calls `app.dispose()` from its own `dispose`. See
  [Rendering Overview](/docs/rendering/overview) and the
  [Drifter example](/docs/examples/drifter).
- **Headless or console**: `await app.run()` calls `tick()` in a loop until
  `app.stop()`, yielding to the event loop after each tick so timers and I/O
  get a turn even when every system is synchronous, then calls `dispose()` to
  clean up the plugins. On its own that loop runs as fast as it can; add
  `FrameLimiterPlugin` to cap it (see
  [Time & Fixed Timestep](/docs/scheduling/time#frame-limiter)).
- **Tests**: `await app.tick()` as many times as you need. `app.runStartup()`
  runs `startup` on its own first, if you want to inspect the world before the
  first frame.

## See also

- [Ordering & Sets](/docs/scheduling/ordering-and-sets)
- [Time & Fixed Timestep](/docs/scheduling/time)
- [App & Plugins](/docs/app/app-and-plugins)
