# Scheduling Guide

Learn how to organize and order systems for optimal execution.

## System Stages

Fledge provides five built-in stages that run in order:

```dart
enum CoreStage {
  first,      // Initialization, time
  preUpdate,  // Input, events
  update,     // Game logic
  postUpdate, // Physics, collision
  last,       // Rendering, cleanup
}
```

## Adding Systems to Stages

```dart
final schedule = Schedule();

schedule.addSystem(TimeSystemWrapper(), stage: CoreStage.first);
schedule.addSystem(InputSystemWrapper(), stage: CoreStage.preUpdate);
schedule.addSystem(AISystemWrapper());  // Default: update
schedule.addSystem(PhysicsSystemWrapper(), stage: CoreStage.postUpdate);
schedule.addSystem(RenderSystemWrapper(), stage: CoreStage.last);
```

## Parallel Execution

Systems in the same stage run in parallel when they don't conflict:

- **No conflict**: Different component access
- **Conflict**: Same component, at least one writes

```dart-tabs
// @tab Annotations
// Can run in parallel (different components)
@system
void systemA(World world) {
  for (final (_, pos) in world.query1<Position>().iter()) { }
}

@system
void systemB(World world) {
  for (final (_, health) in world.query1<Health>().iter()) { }
}

// Must run sequentially (same component)
@system
void systemC(World world) {
  for (final (_, pos) in world.query1<Position>().iter()) { }
}

@system
void systemD(World world) {
  for (final (_, pos) in world.query1<Position>().iter()) { }
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
