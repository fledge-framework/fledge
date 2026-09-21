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
    .addPlugin(WallTimePlugin())      // Core plugin for delta time
    .addPlugin(TiledPlugin())     // Tiled tilemap support
    .run();
}
```

Plugins are initialized in the order they are added, so dependencies should be added first.

## Available Plugins

### Core Plugins

Core plugins are bundled with `fledge_ecs` and provide foundational functionality that most games need.

#### WallTimePlugin

Provides real-time delta tracking with delta time, elapsed time, and frame count.

```dart
App().addPlugin(WallTimePlugin());

// Access in systems
final time = world.getResource<WallTime>()!;
print('Delta: ${time.delta}s, Elapsed: ${time.elapsed}s, Frame: ${time.frameCount}');
```

**Provides:**
- `WallTime` resource with `delta`, `elapsed`, and `frameCount`
- `WallTimeSystem` that runs at `Schedules.first`

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
- `FrameStartSystem` at `Schedules.first` and `FrameLimiterSystem` at `Schedules.last`

### First-Party Plugins

First-party plugins are distributed as separate packages and extend Fledge with significant additional functionality:

| Plugin | Package | Description |
|--------|---------|-------------|
| [Assets](/docs/plugins/assets) | `fledge_assets` | Ref-counted asset store (`Handle<T>` + `Assets<T>`) shared by render, audio, tiled |
| [Render (2D)](/docs/plugins/render) | `fledge_render_2d` | Sprites, cameras, transforms, animation, materials — plus the RenderPlugin / Extractors / RenderWorld infrastructure |
| [Camera (2D)](/docs/plugins/camera_2d) | `fledge_camera_2d` | 2D cameras, follow, shake, letterbox, parallax, projections, transitions |
| [Particles](/docs/plugins/particles) | `fledge_particles` | CPU-driven particle system with emitters, pooling, and presets |
| [Lighting (2D)](/docs/plugins/lighting_2d) | `fledge_lighting_2d` | Point / directional / spot lights, ambient, additive Canvas pass |
| [Tween](/docs/plugins/tween) | `fledge_tween` | Easing curves and value tweens for any interpolatable type |
| [UI](/docs/plugins/ui) | `fledge_ui` | Retained-mode HUD/UI — anchor layout, containers, text, images, panels |
| [Debug](/docs/plugins/debug) | `fledge_debug` | FPS / entity / ordering overlay plus AABB / collider / frustum gizmos |
| [Audio](/docs/plugins/audio) | `fledge_audio` | Music, sound effects, and 2D spatial audio |
| [Input Handling](/docs/plugins/input) | `fledge_input` | Action-based input with keyboard, mouse, and gamepad |
| [Physics & Collision](/docs/plugins/physics) | `fledge_physics` | Collision detection, resolution, and layer filtering |
| [Window Management](/docs/plugins/window) | `fledge_window` | Fullscreen, borderless, and windowed modes |
| [Tiled Tilemaps](/docs/plugins/tiled) | `fledge_tiled` | Load and render Tiled TMX/TSX tilemaps |
| [Yarn Dialogue](/docs/plugins/yarn) | `fledge_yarn` | Yarn Spinner dialogue system for branching narratives |
| [Save System](/docs/plugins/save) | `fledge_save` | Save/load with resource serialization via Saveable mixin |
| [Calendar](/docs/plugins/calendar) | `fledge_calendar` | In-game calendar, day/night, seasons, and time events |
| [Networking](/docs/plugins/net) | `fledge_net` | Multiplayer networking with host/client, state sync, and input prediction |

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
    app.addSystem(MySystem(), schedule: Schedules.update);
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
