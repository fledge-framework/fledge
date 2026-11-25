# Time & Fixed Timestep

Fledge has two clocks:

- **`WallTime`**: real seconds between frames, for anything that runs once
  per frame (animation, UI, camera smoothing).
- **`FixedTimestep`**: a fixed-size step that the fixed schedules run on, zero
  or more times per frame, for physics and anything that must be
  deterministic.

For in-game dates and seasons, see [Calendar](/docs/gameplay/calendar).

<!-- snippet-setup
class Position {
  double x, y;
  Position(this.x, this.y);
}

class PreviousPosition {
  double x, y;
  PreviousPosition(this.x, this.y);
}

class Velocity {
  double dx, dy;
  Velocity(this.dx, this.dy);
}

class Spin {
  double angle = 0;
  double speed = 1;
}

class DrawPosition {
  double x = 0, y = 0;
}
-->

## WallTime

Add `WallTimePlugin` to get a `WallTime` resource, updated at the start of
every frame:

```dart
final app = App()..addPlugin(WallTimePlugin());

final spin = FunctionSystem(
  'spin',
  writes: {ComponentId.of<Spin>()},
  resourceReads: {WallTime},
  run: (world) {
    final dt = world.getResource<WallTime>()!.delta;
    for (final (_, s) in world.query1<Spin>().iter()) {
      s.angle += s.speed * dt;
    }
  },
);
app.addSystem(spin);
```

| Member | Meaning |
|---|---|
| `delta` | Seconds since the previous frame |
| `elapsed` | Total seconds of game time: the sum of every `delta`, so time before the first reading isn't counted |
| `frameCount` | Frames since start |
| `useClock(now, frameInterval:)` | Read time from an external clock (below) |
| `frameInterval` | The refresh interval `delta` is counted in, when using a clock with one |
| `reset()` | Back to zero |

The plugin registers `WallTimeUpdateSystem` in `Schedules.first`, in the
`FirstSets.frameStart` phase, so every later system in the frame sees the
updated values. Its name is `WallTimeUpdateSystem.systemName`
(`'wallTimeUpdate'`), for systems in `first` that need to order against it.

The first reading after the plugin starts, after `useClock`, or after `reset()`
sets time zero and adds no time: `delta` is 0 on that frame. That stops a
clock which was already running (or a slow first frame) from producing one
huge step.

### Smooth frame times in Flutter

By default `WallTime` reads a stopwatch when its system runs, which wanders by
a few milliseconds from frame to frame. Anything moved by `delta` then judders,
which is most visible in scrolling pixel art. When a Flutter ticker drives the
app, hand `WallTime` the vsync timestamp and the display's refresh interval
instead:

```dart
import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:flutter/scheduler.dart';

void useVsyncClock(App app) {
  final hz = PlatformDispatcher.instance.views.first.display.refreshRate;
  app.world.getResource<WallTime>()!.useClock(
    () => SchedulerBinding.instance.currentSystemFrameTimeStamp,
    frameInterval: WallTime.frameIntervalFor(hz),
  );
}
```

With a `frameInterval`, `delta` is always a whole number of refreshes:

- `frameIntervalFor(hz)` snaps a reported rate within 1.5 Hz of a standard one
  (`WallTime.standardRefreshRates`: 24, 30, 48, 50, 60, 72, 75, 90, 100, 120,
  144, 165, 180, 240, 360) to that rate, so a 59.94 Hz display reporting 59
  counts as 60. Zero or less counts as 60 Hz.
- The reported rate is only a first guess. `WallTime` measures the real
  interval from the clock (the median of recent frame gaps) and switches to
  it, so a wrong report or a move to another monitor sorts itself out.
- Every frame on which the clock advanced counts at least one refresh, even
  one that arrives early, because that frame is shown for a refresh of its
  own. A frame on which the clock didn't move adds no time.

### Migrating from `Time`

`WallTime` was previously called `Time`. The old names still compile, with
deprecation warnings, and will be removed:

| Deprecated | Use |
|---|---|
| `Time` | `WallTime` |
| `TimePlugin` | `WallTimePlugin` |
| `TimeUpdateSystem` | `WallTimeUpdateSystem` |

## Fixed timestep

The fixed schedules (`fixedFirst`, `fixedPreUpdate`, `fixedUpdate`,
`fixedPostUpdate`, `fixedLast`) run as a chain between `preUpdate` and
`update` (see [Schedules & the Frame](/docs/scheduling/schedules)). Each frame:

1. The frame's real delta is added to an accumulator. It comes from `WallTime`
   if the resource exists, otherwise from a stopwatch inside `App`, so the fixed
   chain works without `WallTimePlugin`.
2. While the accumulator holds at least one step, the whole chain runs once and
   one step is subtracted.
3. After `maxCatchupSteps` steps, any time still owed is dropped, so a long
   frame can't cause an ever-growing backlog (the "spiral of death").

So at 60 Hz steps on a 120 Hz display, about every other frame runs one step;
on a 30 Hz display, each frame runs two.

### Configuring it

Every `App` inserts a default `FixedTimestep`: `stepDuration` of 16667 µs (about
60 Hz) and `maxCatchupSteps` of 5. Replace it before the first tick:

```dart
final app = App()
  ..insertResource(
    FixedTimestep(
      stepDuration: const Duration(microseconds: 8333), // ~120 Hz
      maxCatchupSteps: 3,
    ),
  );
```

### Writing fixed-step systems

Step by `stepSeconds`, not `WallTime.delta`:

```dart
final integrate = FunctionSystem(
  'integrate',
  reads: {ComponentId.of<Velocity>()},
  writes: {ComponentId.of<Position>(), ComponentId.of<PreviousPosition>()},
  resourceReads: {FixedTimestep},
  run: (world) {
    final dt = world.getResource<FixedTimestep>()!.stepSeconds;
    for (final (entity, pos, vel) in world.query2<Position, Velocity>().iter()) {
      final prev = world.get<PreviousPosition>(entity);
      if (prev != null) {
        prev.x = pos.x;
        prev.y = pos.y;
      }
      pos.x += vel.dx * dt;
      pos.y += vel.dy * dt;
    }
  },
);

final app = App()..addSystem(integrate, schedule: Schedules.fixedUpdate);
```

### Smoothing with `alpha`

A frame usually lands between two fixed steps. `alpha` (0..1) says how far
into the next step the leftover time reaches. A per-frame system can blend the
previous and current positions with it, so motion looks smooth even when the
display rate and the step rate differ:

```dart
final interpolate = FunctionSystem(
  'interpolate',
  reads: {ComponentId.of<Position>(), ComponentId.of<PreviousPosition>()},
  writes: {ComponentId.of<DrawPosition>()},
  resourceReads: {FixedTimestep},
  run: (world) {
    final a = world.getResource<FixedTimestep>()!.alpha;
    for (final (_, pos, prev, draw)
        in world.query3<Position, PreviousPosition, DrawPosition>().iter()) {
      draw.x = prev.x + (pos.x - prev.x) * a;
      draw.y = prev.y + (pos.y - prev.y) * a;
    }
  },
);

final app = App()..addSystem(interpolate, schedule: Schedules.postUpdate);
```

### Other members

| Member | Meaning |
|---|---|
| `stepSeconds` | One step, in seconds |
| `alpha` | Leftover time as a fraction of a step, clamped to 0..1 |
| `accumulatorSeconds` | Leftover time, in seconds (read-only) |
| `stepsThisFrame` | Steps run in the most recent frame, for a debug overlay |
| `nudge(seconds)` | Shifts the cadence: positive brings the next step forward, negative delays it. Each call is clamped to ±one step. Returns the shift applied |

`nudge` is for keeping a simulation in step with an external clock, such as a
network client staying a steady lead ahead of its host. Most games never need
it.

### What a fixed step means for other features

- **Ticks**: each fixed step advances the world tick (`world.currentTick`) and
  the change clock, just as a frame does.
- **[Change detection](/docs/ecs/change-detection)**: a fixed-step system sees
  changes since its own previous run, whichever step or frame that was.
- **[Run conditions](/docs/ecs/states-run-conditions)** are checked on every
  step. State enter/exit flags last a whole frame, so an `OnEnterState`
  system in a fixed schedule could run several times, or not at all. Keep
  those in per-frame schedules.
- **[Events](/docs/ecs/events#events-and-the-fixed-timestep)** swap once per
  frame, so a fixed-step reader may see the same events twice, or miss them on
  a frame with no steps.

### Known limitation: long pauses

When the app is suspended (laptop sleep, a debugger breakpoint, a minimised
window that stops ticking), the next frame's `WallTime.delta` covers the
whole pause, and per-frame systems that scale by it take one huge step. The
fixed chain runs at most `maxCatchupSteps` steps and drops the rest. If that
matters for your game, clamp `delta` in your own per-frame systems, or pause
the game when the window loses focus.

## Frame limiter

`App.run()` calls `tick()` in a loop as fast as it can. For a **standalone,
non-Flutter** loop (a console game, a headless server or simulation),
`FrameLimiterPlugin` caps the rate:

```dart
final app = App()
  ..addPlugin(WallTimePlugin())
  ..addPlugin(const FrameLimiterPlugin(targetFps: 30));

// await app.run();
```

It adds `FrameStartSystem` (in `first`, frame-start phase) and
`FrameLimiterSystem` (in `last`), whose names are
`FrameStartSystem.systemName` and `FrameLimiterSystem.systemName`. The limiter
system is asynchronous: it awaits short delays until the next frame is due,
then `extract`, `render` and the next tick follow.

Don't use it in a Flutter app. There, the display's vsync paces the ticker
that calls `tick()`, and a limiter would only add waits inside the frame.

It also inserts a `FrameTime` resource. All its durations are in **seconds**:

| Member | Meaning |
|---|---|
| `frameTime` | Time from frame start to the limiter (the work) |
| `sleepTime` | Time spent waiting |
| `totalTime` | `frameTime + sleepTime` |
| `fps` | `1 / totalTime` |

and a `FrameLimiterConfig` (`targetFps`, `targetFrameTime`, `targetDuration`).

## See also

- [Schedules & the Frame](/docs/scheduling/schedules)
- [Physics](/docs/gameplay/physics)
- [Calendar](/docs/gameplay/calendar)
