# Schedule API Reference

The `Schedule` organizes systems into stages and manages their execution.

## Import

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_ecs_annotations/fledge_ecs_annotations.dart';
```

## Constructor

```dart
Schedule()
```

Creates a new empty schedule.

## Methods

### addSystem(system, {stage})

```dart
void addSystem(System system, {CoreStage stage = CoreStage.update})
```

Adds a system to the schedule at the specified stage.

```dart
final schedule = Schedule();

schedule.addSystem(InputSystemWrapper(), stage: CoreStage.preUpdate);
schedule.addSystem(MovementSystemWrapper());  // Default: CoreStage.update
schedule.addSystem(RenderSystemWrapper(), stage: CoreStage.last);
```

### run(world)

```dart
Future<void> run(World world)
```

Executes all systems in stage order. Systems within the same stage may run in parallel if they don't conflict.

```dart
await schedule.run(world);
```

## Core Stages

Systems are organized into stages that execute in order:

```dart
enum CoreStage {
  first,      // Run before everything else
  preUpdate,  // Input handling, event processing
  update,     // Main game logic (default)
  postUpdate, // Physics, collision resolution
  last,       // Rendering, cleanup
}
```

### Stage Execution Order

```
┌─────────────────────┐
│     CoreStage.first │  ← Initialization, time updates
├─────────────────────┤
│   CoreStage.preUpdate│  ← Input, events
├─────────────────────┤
│    CoreStage.update │  ← Game logic (default)
├─────────────────────┤
│  CoreStage.postUpdate│  ← Physics, collision
├─────────────────────┤
│     CoreStage.last  │  ← Rendering, cleanup
└─────────────────────┘
```

## Parallel Execution

Within each stage, non-conflicting systems run in parallel:

```dart
// These can run in parallel (no conflicts)
@system
void systemA(World world) {  // Writes Position
  for (final (_, pos) in world.query1<Position>().iter()) { }
}

@system
void systemB(World world) {  // Writes Health
  for (final (_, health) in world.query1<Health>().iter()) { }
}

// These must run sequentially (both write Position)
@system
void systemC(World world) {  // Writes Position
  for (final (_, pos) in world.query1<Position>().iter()) { }
}

@system
void systemD(World world) {  // Writes Position
  for (final (_, pos, vel) in world.query2<Position, Velocity>().iter()) { }
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
  final world = World();
  final schedule = Schedule();

  // Stage: first
  schedule.addSystem(TimeSystemWrapper(), stage: CoreStage.first);

  // Stage: preUpdate
  schedule.addSystem(InputSystemWrapper(), stage: CoreStage.preUpdate);
  schedule.addSystem(EventProcessorWrapper(), stage: CoreStage.preUpdate);

  // Stage: update (default)
  schedule.addSystem(AISystemWrapper());
  schedule.addSystem(MovementSystemWrapper());
  schedule.addSystem(ShootingSystemWrapper());

  // Stage: postUpdate
  schedule.addSystem(PhysicsSystemWrapper(), stage: CoreStage.postUpdate);
  schedule.addSystem(CollisionSystemWrapper(), stage: CoreStage.postUpdate);

  // Stage: last
  schedule.addSystem(RenderSystemWrapper(), stage: CoreStage.last);
  schedule.addSystem(CleanupSystemWrapper(), stage: CoreStage.last);

  // Game loop
  while (gameRunning) {
    await schedule.run(world);
    await Future.delayed(Duration(milliseconds: 16)); // ~60 FPS
  }
}
```

## System Dependencies

The schedule automatically determines dependencies based on `SystemMeta`:

```dart
class SystemMeta {
  final String name;
  final Set<ComponentId> reads;      // Components read
  final Set<ComponentId> writes;     // Components written
  final Set<Type> resourceReads;     // Resources read
  final Set<Type> resourceWrites;    // Resources written
}
```

## Manual Ordering

For explicit ordering within a stage, add systems in the desired order:

```dart
// These run sequentially in the order added
schedule.addSystem(FirstSystemWrapper());
schedule.addSystem(SecondSystemWrapper());
schedule.addSystem(ThirdSystemWrapper());
```

## Game Loop Integration

```dart
class Game {
  final World world = World();
  final Schedule schedule = Schedule();
  bool running = true;

  void setup() {
    // Add systems...
  }

  Future<void> run() async {
    final stopwatch = Stopwatch()..start();
    var lastTime = 0.0;

    while (running) {
      final currentTime = stopwatch.elapsedMilliseconds / 1000.0;
      final deltaTime = currentTime - lastTime;
      lastTime = currentTime;

      // Update time resource
      world.getResource<Time>()?.delta = deltaTime;

      // Run all systems
      await schedule.run(world);

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
