# Scheduling Guide

Learn how to organize and order systems for optimal execution.

## Standard Schedules

Fledge provides five per-frame schedules that run in order, plus a `startup` schedule that runs once before the frame loop:

```dart
// From fledge_ecs — Schedules is a container of standard schedule labels.
Schedules.first;      // Initialization, time
Schedules.preUpdate;  // Input, events
Schedules.update;     // Game logic
Schedules.postUpdate; // Physics, collision
Schedules.last;       // Rendering, cleanup

// Reserved for the fixed-timestep and render pipeline (v0.2):
Schedules.fixedFirst; // fixed → fixedPreUpdate → fixedUpdate → fixedPostUpdate → fixedLast
Schedules.extract;    // Extract state into the RenderWorld
Schedules.render;     // Run render systems on the RenderWorld
```

> The `CoreStage` enum and the `stage:` parameter to `addSystem` remain as deprecated aliases for one release. Prefer `schedule: Schedules.foo` in new code.

## Adding Systems to Schedules

```dart
app
  .addSystem(TimeSystemWrapper(), schedule: Schedules.first)
  .addSystem(InputSystemWrapper(), schedule: Schedules.preUpdate)
  .addSystem(AISystemWrapper())  // Default: Schedules.update
  .addSystem(PhysicsSystemWrapper(), schedule: Schedules.postUpdate)
  .addSystem(RenderSystemWrapper(), schedule: Schedules.last);
```

The runtime container that dispatches schedules is the `Scheduler` (previously called `Schedule`). Games rarely construct one directly — `App` owns one and wires it up.

## Parallel Execution

Systems in the same schedule run in parallel when they don't conflict:

- **No conflict**: Different component access
- **Conflict**: Same component, at least one writes

```dart-tabs
// @tab Annotations
// Can run in parallel (different components)
@system
void systemA(Query1<Position> query) {
  for (final (_, pos) in query.iter()) { }
}

@system
void systemB(Query1<Health> query) {
  for (final (_, health) in query.iter()) { }
}

// Must run sequentially (same component)
@system
void systemC(Query1<Position> query) {
  for (final (_, pos) in query.iter()) { }
}

@system
void systemD(QueryMut1<Position> query) {
  for (final (_, pos) in query.iter()) { }
}
// @tab Inheritance
// Can run in parallel (different components)
class SystemA implements System {
  @override
  SystemMeta get meta => SystemMeta(name: 'systemA', reads: {ComponentId.of<Position>()});

  @override
  Future<void> run(World world) async {
    for (final (_, pos) in world.query1<Position>().iter()) { }
  }
}

class SystemB implements System {
  @override
  SystemMeta get meta => SystemMeta(name: 'systemB', reads: {ComponentId.of<Health>()});

  @override
  Future<void> run(World world) async {
    for (final (_, health) in world.query1<Health>().iter()) { }
  }
}

// Must run sequentially (same component)
class SystemC implements System {
  @override
  SystemMeta get meta => SystemMeta(name: 'systemC', reads: {ComponentId.of<Position>()});

  @override
  Future<void> run(World world) async {
    for (final (_, pos) in world.query1<Position>().iter()) { }
  }
}

class SystemD implements System {
  @override
  SystemMeta get meta => SystemMeta(name: 'systemD', reads: {ComponentId.of<Position>()});

  @override
  Future<void> run(World world) async {
    for (final (_, pos) in world.query1<Position>().iter()) { }
  }
}
```

## See Also

- [Schedule API](/docs/api/schedule) - Schedule reference
- [System API](/docs/api/system) - System metadata
