# App & Plugins Guide

The `App` class provides a fluent builder for configuring your game, while plugins encapsulate reusable functionality.

## App vs World

Fledge provides two main classes: `App` and `World`. Understanding when to use each is important:

| Class | Purpose | When to Use |
|-------|---------|-------------|
| `App` | High-level game builder | **Always** for games and applications |
| `World` | Low-level ECS container | Inside systems, for unit tests |

### Always Use App for Games

`App` is the recommended entry point for all Fledge games. It provides:

- **Plugin system** for modular, reusable game features
- **System scheduling** with automatic ordering and stages
- **Lifecycle management** (start, tick, stop, cleanup)
- **Core plugins** like `TimePlugin` for delta time

```dart
// Recommended: Use App
final app = App()
  ..addPlugin(TimePlugin())
  ..addPlugin(MyGamePlugin());

await app.run();
```

### World is for Internal Use

`World` is the low-level container that holds entities, components, and resources. You'll interact with it:

- **Inside systems** - Systems receive `World` to query and modify entities
- **Inside plugins** - Plugins access `app.world` to spawn initial entities
- **In unit tests** - Testing individual components without full app setup

```dart
// Inside a system - World is provided
Future<void> run(World world) async {
  for (final (_, pos) in world.query1<Position>().iter()) {
    // Process entities
  }
}

// In unit tests - direct World usage is fine
test('entity spawning', () {
  final world = World();
  final entity = world.spawnWith([Position(0, 0)]);
  expect(world.has<Position>(entity), isTrue);
});
```

### Don't Use World Directly in Games

Avoid creating `World` directly in your game code:

```dart
// DON'T do this in games
void main() {
  final world = World();
  world.insertResource(MyResource());
  // Manually running systems...
}

// DO this instead
void main() async {
  await App()
    .addPlugin(TimePlugin())
    .addPlugin(MyGamePlugin())
    .run();
}
```

## The App Builder

`App` is the main entry point for Fledge games:

```dart
import 'package:fledge_ecs/fledge_ecs.dart';

void main() async {
  await App()
    .addPlugin(TimePlugin())
    .insertResource(GameConfig())
    .addEvent<CollisionEvent>()
    .addSystem(MovementSystemWrapper())
    .addSystem(RenderSystemWrapper(), stage: CoreStage.last)
    .run();
}
```

## App Methods

### Adding Resources

```dart
App()
  .insertResource(GameConfig(difficulty: 'hard'))
  .insertResource(Score())
```

### Registering Events

```dart
App()
  .addEvent<CollisionEvent>()
  .addEvent<DamageEvent>()
```

### Adding Systems

```dart
App()
  .addSystem(MovementSystemWrapper())
  .addSystem(PhysicsSystemWrapper(), stage: CoreStage.postUpdate)
  .addSystem(RenderSystemWrapper(), stage: CoreStage.last)
```

Add multiple systems at once:

```dart
App()
  .addSystems([
    AISystemWrapper(),
    MovementSystemWrapper(),
    ShootingSystemWrapper(),
  ], stage: CoreStage.update)
```

### Lifecycle Callbacks

```dart
App()
  .onStart((app) {
    print('Game started!');
  })
  .onTick((app) {
    // Called every frame
    if (shouldQuit) {
      app.stop();
    }
  })
  .onStop((app) {
    print('Game stopped!');
  })
```

## Running the App

### Continuous Loop

```dart
await app.run(); // Runs until app.stop() is called
```

### Single Frame

```dart
await app.tick(); // Run one frame
await app.update(); // Alias for tick()
```

### Fixed Frame Count

```dart
final runner = AppRunner(app);
await runner.runFrames(100); // Run exactly 100 frames
```

### With Frame Limiting

```dart
final runner = AppRunner(
  app,
  targetFrameTime: Duration(milliseconds: 16), // ~60 FPS
);
await runner.run();
```

## Creating Plugins

Plugins encapsulate related functionality:

```dart
class PhysicsPlugin implements Plugin {
  @override
  void build(App app) {
    app
      .insertResource(PhysicsConfig())
      .addEvent<CollisionEvent>()
      .addSystem(GravitySystemWrapper(), stage: CoreStage.update)
      .addSystem(CollisionSystemWrapper(), stage: CoreStage.postUpdate);
  }

  @override
  void cleanup() {
    // Optional cleanup when app stops
  }
}
```

### Using Plugins

```dart
App()
  .addPlugin(PhysicsPlugin())
  .addPlugin(RenderPlugin())
  .run();
```

### Function Plugins

For simple cases, use `FunctionPlugin`:

```dart
final debugPlugin = FunctionPlugin((app) {
  app.insertResource(DebugConfig(showFps: true));
  app.addSystem(DebugOverlaySystemWrapper(), stage: CoreStage.last);
});

App().addPlugin(debugPlugin);
```

### Plugin Groups

Bundle related plugins:

```dart
class DefaultPlugins extends PluginGroup {
  @override
  List<Plugin> get plugins => [
    TimePlugin(),
    FrameLimiterPlugin(targetFps: 60),
    InputPlugin(),
  ];
}

App().addPlugin(DefaultPlugins());
```

## Core Plugins

Core plugins are bundled with `fledge_ecs` and provide foundational functionality that most games need.

### TimePlugin

Provides time tracking:

```dart-tabs
// @tab Annotations
App().addPlugin(TimePlugin());

// Access in systems
@system
void mySystem(World world) {
  final time = world.getResource<Time>()!;
  final delta = time.delta;      // Seconds since last frame
  final elapsed = time.elapsed;  // Total seconds
  final frame = time.frameCount; // Frame number
}
// @tab Inheritance
App().addPlugin(TimePlugin());

// Access in systems
class MySystem implements System {
  @override
  SystemMeta get meta => SystemMeta(name: 'mySystem', resourceReads: {Time});

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => runCondition?.call(world) ?? true;

  @override
  Future<void> run(World world) async {
    final time = world.getResource<Time>()!;
    final delta = time.delta;      // Seconds since last frame
    final elapsed = time.elapsed;  // Total seconds
    final frame = time.frameCount; // Frame number
  }
}
```

**Provides:**
- `Time` resource with `delta`, `elapsed`, and `frameCount`
- `TimeUpdateSystem` that runs at `CoreStage.first`

### FrameLimiterPlugin

Limits frame rate:

```dart-tabs
// @tab Annotations
App().addPlugin(FrameLimiterPlugin(targetFps: 60));

// Access timing info
@system
void debugSystem(World world) {
  final ft = world.getResource<FrameTime>()!;
  print('FPS: ${ft.fps}');
  print('Frame time: ${ft.frameTime}ms');
}
// @tab Inheritance
App().addPlugin(FrameLimiterPlugin(targetFps: 60));

// Access timing info
class DebugSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(name: 'debug', resourceReads: {FrameTime});

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => runCondition?.call(world) ?? true;

  @override
  Future<void> run(World world) async {
    final ft = world.getResource<FrameTime>()!;
    print('FPS: ${ft.fps}');
    print('Frame time: ${ft.frameTime}ms');
  }
}
```

**Provides:**
- `FrameLimiterConfig` resource with target FPS settings
- `FrameTime` resource with frame timing metrics
- `FrameStartSystem` at `CoreStage.first` and `FrameLimiterSystem` at `CoreStage.last`

## Accessing World and Schedule

The App exposes its world and schedule:

```dart
final app = App();

// Direct world access
app.world.insertResource(MyResource());
final entity = app.world.spawn();

// Direct schedule access
app.schedule.addSystem(MySystem());
```

## Complete Example

```dart-tabs
// @tab Annotations
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_ecs_annotations/fledge_ecs_annotations.dart';

part 'main.g.dart';

// Components
@component
class Position { double x, y; Position(this.x, this.y); }

@component
class Velocity { double dx, dy; Velocity(this.dx, this.dy); }

// Systems
@system
void movementSystem(World world) {
  final dt = world.getResource<Time>()!.delta;
  for (final (_, pos, vel) in world.query2<Position, Velocity>().iter()) {
    pos.x += vel.dx * dt;
    pos.y += vel.dy * dt;
  }
}

// Game Plugin
class GamePlugin implements Plugin {
  @override
  void build(App app) {
    app.addSystem(MovementSystemWrapper());

    // Spawn initial entities
    app.world.spawn()
      ..insert(Position(0, 0))
      ..insert(Velocity(100, 50));
  }

  @override
  void cleanup() {}
}

void main() async {
  var frameCount = 0;

  await App()
    .addPlugin(TimePlugin())
    .addPlugin(FrameLimiterPlugin(targetFps: 60))
    .addPlugin(GamePlugin())
    .onTick((app) {
      frameCount++;
      if (frameCount >= 300) { // Run for 5 seconds at 60 FPS
        app.stop();
      }
    })
    .run();

  print('Game ran for $frameCount frames');
}
// @tab Inheritance
import 'package:fledge_ecs/fledge_ecs.dart';

// Components (plain classes)
class Position { double x, y; Position(this.x, this.y); }

class Velocity { double dx, dy; Velocity(this.dx, this.dy); }

// Systems
class MovementSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'movement',
        writes: {ComponentId.of<Position>()},
        reads: {ComponentId.of<Velocity>()},
        resourceReads: {Time},
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => runCondition?.call(world) ?? true;

  @override
  Future<void> run(World world) async {
    final dt = world.getResource<Time>()!.delta;
    for (final (_, pos, vel) in world.query2<Position, Velocity>().iter()) {
      pos.x += vel.dx * dt;
      pos.y += vel.dy * dt;
    }
  }
}

// Game Plugin
class GamePlugin implements Plugin {
  @override
  void build(App app) {
    app.addSystem(MovementSystem());

    // Spawn initial entities
    app.world.spawn()
      ..insert(Position(0, 0))
      ..insert(Velocity(100, 50));
  }

  @override
  void cleanup() {}
}

void main() async {
  var frameCount = 0;

  await App()
    .addPlugin(TimePlugin())
    .addPlugin(FrameLimiterPlugin(targetFps: 60))
    .addPlugin(GamePlugin())
    .onTick((app) {
      frameCount++;
      if (frameCount >= 300) { // Run for 5 seconds at 60 FPS
        app.stop();
      }
    })
    .run();

  print('Game ran for $frameCount frames');
}
```

## See Also

- [Systems](/docs/guides/systems) - System definition
- [Resources](/docs/guides/resources) - Global resources
- [Schedule](/docs/api/schedule) - System scheduling
- [Two-World Architecture](/docs/guides/two-world-architecture) - Render extraction and GPU-optimized data flow
