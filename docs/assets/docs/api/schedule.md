# Schedule API Reference

`Scheduler` is the runtime container that owns per-frame schedules and dispatches them. `Schedule` is the label value type identifying a schedule; `Schedules` is a container of standard labels (`first`, `preUpdate`, `update`, `postUpdate`, `last`, plus reserved fixed-timestep and render pipeline labels).

## Import

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_ecs_annotations/fledge_ecs_annotations.dart';
```

## Constructor

```dart
Scheduler()
```

Creates a new empty scheduler. Games rarely construct one directly — `App` owns one and exposes it as `app.scheduler`.

> The runtime container was renamed from `Schedule` to `Scheduler` in v0.2 so the `Schedule` name could be reused for the label value type. The old getter (`app.schedule`) is kept as a deprecated alias for one release.

## Methods

### addSystem(system, {schedule})

```dart
void addSystem(System system, {Schedule schedule = Schedules.update})
```

Adds a system to the given schedule.

```dart
final scheduler = app.scheduler;

scheduler.addSystem(InputSystemWrapper(), schedule: Schedules.preUpdate);
scheduler.addSystem(MovementSystemWrapper());  // Default: Schedules.update
scheduler.addSystem(RenderSystemWrapper(), schedule: Schedules.last);
```

> `stage: CoreStage.foo` is aliased to `schedule: Schedules.foo` for one release. New code should use the `schedule:` parameter.

### run(world)

```dart
Future<void> run(World world)
```

Executes all systems in schedule order. Systems within the same schedule may run in parallel if they don't conflict.

```dart
await scheduler.run(world);
```

## Standard Schedules

Systems are organized into schedules that execute in order. `Schedules` is the container of standard labels:

```dart
class Schedules {
  // Runs once, before the frame loop.
  static const startup       = Schedule('startup');

  // Per-frame, in order:
  static const first         = Schedule('first');       // Initialization, time
  static const preUpdate     = Schedule('preUpdate');   // Input, events
  static const update        = Schedule('update');      // Game logic (default)
  static const postUpdate    = Schedule('postUpdate');  // Physics, collision
  static const last          = Schedule('last');        // Rendering, cleanup

  // Reserved fixed-timestep chain (v0.2):
  static const fixedFirst      = Schedule('fixedFirst');
  static const fixedPreUpdate  = Schedule('fixedPreUpdate');
  static const fixedUpdate     = Schedule('fixedUpdate');
  static const fixedPostUpdate = Schedule('fixedPostUpdate');
  static const fixedLast       = Schedule('fixedLast');

  // Reserved render pipeline (v0.2):
  static const extract         = Schedule('extract');
  static const render          = Schedule('render');
}
```

### Per-Frame Execution Order

```
┌───────────────────────┐
│  Schedules.first      │  ← Initialization, time updates
├───────────────────────┤
│  Schedules.preUpdate  │  ← Input, events
├───────────────────────┤
│  Schedules.update     │  ← Game logic (default)
├───────────────────────┤
│  Schedules.postUpdate │  ← Physics, collision
├───────────────────────┤
│  Schedules.last       │  ← Rendering, cleanup
└───────────────────────┘
```

Fixed-timestep schedules (`Schedules.fixedFirst`…`Schedules.fixedLast`) run 0..N times per frame driven by the `FixedTimestep` resource. Render pipeline schedules (`Schedules.extract` → `Schedules.render`) are for the render-world extract/dispatch phase.

## Parallel Execution

Within each schedule, non-conflicting systems run in parallel:

```dart
// These can run in parallel (no conflicts)
@system
void systemA(QueryMut1<Position> query) {  // Writes Position
  for (final (_, pos) in query.iter()) { }
}

@system
void systemB(QueryMut1<Health> query) {  // Writes Health
  for (final (_, health) in query.iter()) { }
}

// These must run sequentially (both write Position)
@system
void systemC(QueryMut1<Position> query) {  // Writes Position
  for (final (_, pos) in query.iter()) { }
}

@system
void systemD(QueryMut2<Position, Velocity> query) {  // Writes Position
  for (final (_, pos, vel) in query.iter()) { }
}
```

### Conflict Detection

Systems conflict when they both access the same component type and at least one is writing:

| System A | System B | Conflict? |
|----------|----------|-----------|
| Reads X | Reads X | No |
| Reads X | Writes X | Yes |
| Writes X | Reads X | Yes |
| Writes X | Writes X | Yes |

## Example Setup

```dart
void main() async {
  final app = App();
  final scheduler = app.scheduler;

  // Schedule: first
  scheduler.addSystem(WallTimeUpdateSystem(), schedule: Schedules.first);

  // Schedule: preUpdate
  scheduler.addSystem(InputSystemWrapper(),       schedule: Schedules.preUpdate);
  scheduler.addSystem(EventProcessorWrapper(),    schedule: Schedules.preUpdate);

  // Schedule: update (default)
  scheduler.addSystem(AISystemWrapper());
  scheduler.addSystem(MovementSystemWrapper());
  scheduler.addSystem(ShootingSystemWrapper());

  // Schedule: postUpdate
  scheduler.addSystem(PhysicsSystemWrapper(),    schedule: Schedules.postUpdate);
  scheduler.addSystem(CollisionSystemWrapper(), schedule: Schedules.postUpdate);

  // Schedule: last
  scheduler.addSystem(RenderSystemWrapper(),  schedule: Schedules.last);
  scheduler.addSystem(CleanupSystemWrapper(), schedule: Schedules.last);

  await app.run();
}
```

## System Dependencies

The scheduler automatically determines dependencies based on `SystemMeta`:

```dart
class SystemMeta {
  final String name;
  final Set<ComponentId> reads;      // Components read
  final Set<ComponentId> writes;     // Components written
  final Set<Type> resourceReads;     // Resources read
  final Set<Type> resourceWrites;    // Resources written
  final List<String> before;         // Explicit ordering
  final List<String> after;          // Explicit ordering
}
```

## Manual Ordering

Within a schedule the scheduler falls back to registration order to break ties on conflicts, but this is fragile — declare explicit ordering via `before:` / `after:` on `SystemMeta`, or split systems into different schedules.

```dart
// These run sequentially in the order added — but prefer explicit
// before:/after: on SystemMeta.
scheduler.addSystem(FirstSystemWrapper());
scheduler.addSystem(SecondSystemWrapper());
scheduler.addSystem(ThirdSystemWrapper());
```

Use `App.checkScheduleOrdering()` to catch implicit ordering.

## Game Loop Integration

Most games just call `app.run()`. If you need a bespoke driver, iterate the scheduler yourself:

```dart
class Game {
  final App app = App()..addPlugin(WallTimePlugin());
  bool running = true;

  Future<void> run() async {
    final stopwatch = Stopwatch()..start();
    var lastTime = 0.0;

    while (running) {
      final currentTime = stopwatch.elapsedMilliseconds / 1000.0;
      final deltaTime = currentTime - lastTime;
      lastTime = currentTime;

      // WallTimePlugin's WallTimeUpdateSystem in Schedules.first will
      // pick up the delta from the frame clock — you rarely need to
      // touch WallTime by hand.

      await app.tick();

      // Frame limiting
      final frameTime = stopwatch.elapsedMilliseconds / 1000.0 - currentTime;
      if (frameTime < 1 / 60) {
        await Future.delayed(
          Duration(milliseconds: ((1 / 60 - frameTime) * 1000).round()),
        );
      }
    }
  }
}
```

## See Also

- [System](/docs/api/system) - Defining systems
- [World](/docs/api/world) - World that systems operate on
- [Commands](/docs/api/commands) - Deferred mutations
