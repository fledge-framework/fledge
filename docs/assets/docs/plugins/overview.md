# Plugins Overview

Fledge provides a plugin system for extending the framework with additional functionality. First-party plugins offer seamless integration with the core ECS and rendering systems.

## What are Plugins?

Plugins are modular packages that add features to your Fledge application. They typically provide:

- **Components** - New data types for entities
- **Systems** - Logic that operates on components
- **Resources** - Shared state and configuration
- **Extractors** - Render pipeline integration

## Using Plugins

Add plugins to your app using the fluent builder API:

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_tiled/fledge_tiled.dart';

void main() async {
  await App()
    .addPlugin(TimePlugin())      // Core plugin for delta time
    .addPlugin(TiledPlugin())     // Tiled tilemap support
    .run();
}
```

Plugins are initialized in the order they are added, so dependencies should be added first.

## Available Plugins

### Core Plugins

Core plugins are bundled with `fledge_ecs` and provide foundational functionality that most games need.

#### TimePlugin

Provides time tracking with delta time, elapsed time, and frame count.

```dart
App().addPlugin(TimePlugin());

// Access in systems
final time = world.getResource<Time>()!;
print('Delta: ${time.delta}s, Elapsed: ${time.elapsed}s, Frame: ${time.frameCount}');
```

**Provides:**
- `Time` resource with `delta`, `elapsed`, and `frameCount`
- `TimeUpdateSystem` that runs at `CoreStage.first`

#### FrameLimiterPlugin

Limits frame rate by sleeping at the end of each frame.

```dart
App().addPlugin(FrameLimiterPlugin(targetFps: 60));

// Access frame timing info
final frameTime = world.getResource<FrameTime>()!;
print('FPS: ${frameTime.fps}, Frame time: ${frameTime.frameTime}s');
```

**Provides:**
- `FrameLimiterConfig` resource with target FPS settings
- `FrameTime` resource with frame timing metrics
- `FrameStartSystem` at `CoreStage.first` and `FrameLimiterSystem` at `CoreStage.last`

### First-Party Plugins

First-party plugins are distributed as separate packages and extend Fledge with significant additional functionality:

| Plugin | Package | Description |
|--------|---------|-------------|
| [2D Rendering](/docs/plugins/render) | `fledge_render`, `fledge_render_2d`, `fledge_render_flutter` | Sprites, cameras, transforms, and GPU rendering |
| [Audio](/docs/plugins/audio) | `fledge_audio` | Music, sound effects, and 2D spatial audio |
| [Input Handling](/docs/plugins/input) | `fledge_input` | Action-based input with keyboard, mouse, and gamepad |
| [Window Management](/docs/plugins/window) | `fledge_window` | Fullscreen, borderless, and windowed modes |
| [Tiled Tilemaps](/docs/plugins/tiled) | `fledge_tiled` | Load and render Tiled TMX/TSX tilemaps |

## Creating Custom Plugins

Plugins implement the `Plugin` interface:

```dart
class MyPlugin implements Plugin {
  @override
  void build(App app) {
    // Add resources
    app.insertResource(MyResource());

    // Register events
    app.addEvent<MyEvent>();

    // Add systems
    app.addSystem(MySystem(), stage: CoreStage.update);
  }

  @override
  void cleanup() {
    // Optional cleanup when app stops
  }
}
```

## See Also

- [App & Plugins Guide](/docs/guides/app-plugins) - Plugin architecture details
- [Plugin API](/docs/api/plugin) - Plugin interface reference
- [Tiled Tilemaps](/docs/plugins/tiled) - Tiled integration guide
