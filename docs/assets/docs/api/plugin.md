# Plugin API Reference

Plugins encapsulate reusable ECS functionality that can be added to an App.

## Import

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
```

## Plugin Interface

```dart
abstract class Plugin {
  void build(App app);
  void cleanup() {}
}
```

### build(app)

Called when the plugin is added via `App.addPlugin()`. Configure resources, events, and systems here.

```dart
class MyPlugin implements Plugin {
  @override
  void build(App app) {
    app.insertResource(MyResource());
    app.addEvent<MyEvent>();
    app.addSystem(MySystemWrapper());
  }

  @override
  void cleanup() {}
}
```

### cleanup()

Called when the app stops. Override to perform cleanup.

```dart
class ResourcePlugin implements Plugin {
  Handle? _handle;

  @override
  void build(App app) {
    _handle = acquireResource();
    app.insertResource(_handle!);
  }

  @override
  void cleanup() {
    _handle?.release();
  }
}
```

## PluginGroup

Groups multiple plugins together.

```dart
abstract class PluginGroup implements Plugin {
  List<Plugin> get plugins;
}
```

### Example

```dart
class DefaultPlugins extends PluginGroup {
  @override
  List<Plugin> get plugins => [
    TimePlugin(),
    FrameLimiterPlugin(targetFps: 60),
    InputPlugin(),
    RenderPlugin(),
  ];
}

// Usage
App().addPlugin(DefaultPlugins());
```

## FunctionPlugin

Create a plugin from a function.

```dart
FunctionPlugin(
  void Function(App app) build,
  {void Function()? cleanup}
)
```

### Example

```dart
final debugPlugin = FunctionPlugin(
  (app) {
    app.insertResource(DebugConfig(showFps: true));
    app.addSystem(DebugOverlaySystemWrapper());
  },
  cleanup: () => print('Debug plugin cleaned up'),
);
```

## Core Plugins

Core plugins are bundled with `fledge_ecs` and provide foundational functionality.

### TimePlugin

Provides `Time` resource with delta and elapsed time.

```dart
App().addPlugin(TimePlugin());

@system
Future<void> mySystem(World world) async {
  final time = world.getResource<Time>()!;
  print('Delta: ${time.delta}');
  print('Elapsed: ${time.elapsed}');
  print('Frame: ${time.frameCount}');
}
```

**Provides:**
- `Time` resource with `delta`, `elapsed`, and `frameCount`
- `TimeUpdateSystem` that runs at `CoreStage.first`

### FrameLimiterPlugin

Limits frame rate with sleep-based timing.

```dart
App().addPlugin(FrameLimiterPlugin(targetFps: 60));

@system
Future<void> debugSystem(World world) async {
  final ft = world.getResource<FrameTime>()!;
  print('FPS: ${ft.fps}');
}
```

**Provides:**
- `FrameLimiterConfig` resource with target FPS settings
- `FrameTime` resource with frame timing metrics
- `FrameStartSystem` at `CoreStage.first` and `FrameLimiterSystem` at `CoreStage.last`

## Creating Custom Plugins

### Simple Plugin

```dart
class ScorePlugin implements Plugin {
  @override
  void build(App app) {
    app.insertResource(Score());
    app.addEvent<ScoreEvent>();
    app.addSystem(ScoreSystemWrapper());
  }

  @override
  void cleanup() {}
}
```

### Configurable Plugin

```dart
class PhysicsPlugin implements Plugin {
  final double gravity;
  final int iterations;

  PhysicsPlugin({
    this.gravity = 9.8,
    this.iterations = 4,
  });

  @override
  void build(App app) {
    app.insertResource(PhysicsConfig(
      gravity: gravity,
      iterations: iterations,
    ));
    app.addSystem(GravitySystemWrapper());
    app.addSystem(CollisionSystemWrapper());
  }

  @override
  void cleanup() {}
}
```

### Plugin with Initial Entities

```dart
class GamePlugin implements Plugin {
  @override
  void build(App app) {
    // Spawn initial entities
    app.world.spawn()
      ..insert(Position(0, 0))
      ..insert(Player());

    for (var i = 0; i < 10; i++) {
      app.world.spawn()
        ..insert(Position(i * 50.0, 100))
        ..insert(Enemy());
    }

    // Add systems
    app.addSystem(PlayerControlSystemWrapper());
    app.addSystem(EnemyAISystemWrapper());
  }

  @override
  void cleanup() {}
}
```

## Plugin Dependencies

Handle dependencies between plugins:

```dart
class RenderPlugin implements Plugin {
  @override
  void build(App app) {
    // Ensure TimePlugin is added first
    if (!app.world.hasResource<Time>()) {
      throw StateError('RenderPlugin requires TimePlugin');
    }

    app.addSystem(RenderSystemWrapper(), stage: CoreStage.last);
  }

  @override
  void cleanup() {}
}
```

## See Also

- [App](/docs/api/app) - App builder
- [App & Plugins Guide](/docs/guides/app-plugins) - Plugin patterns
