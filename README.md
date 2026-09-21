# Fledge

A Bevy-inspired Entity Component System (ECS) framework for Dart and Flutter game development.

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

## Overview

Fledge brings the power of modern ECS architecture to Flutter, enabling you to build performant 2D games with clean, composable code. Inspired by [Bevy](https://bevyengine.org/), Fledge separates data (components) from logic (systems) for maximum flexibility and testability.

## Features

- **Entity Component System** — Compose game objects from reusable components
- **System Scheduling** — Automatic parallel execution with dependency resolution, fixed-timestep support, and an ordering-ambiguity checker
- **Two-World Architecture** — Separate game logic from rendering via extractors and a dedicated render world
- **Real Canvas Rendering** — Sprite pipeline built on `Canvas.drawRawAtlas` with layer-sorted draws
- **Ref-counted Assets** — Shared `Handle<T>` + `Assets<T>` store used by render, audio, tiled
- **2.5D Primitives** — Orthographic, isometric, and oblique projections; camera follow, shake, letterbox, parallax
- **Dynamic Lighting** — Point / directional / spot lights and ambient illumination
- **Retained-mode HUD/UI** — Anchor-based layout, containers, text, images, panels
- **Debug Tooling** — Runtime overlay (FPS, entity count, ordering ambiguities) plus AABB / collider / camera-frustum gizmos
- **Plugin System** — Modular, reusable game features
- **Action-Based Input** — Map physical inputs to semantic actions
- **Spatial Audio** — 2D positional audio with volume channels
- **Tiled Integration** — Load and render TMX/TSX tilemaps
- **Yarn Dialogue** — Branching dialogue with variables and commands
- **Physics & Collision** — Layer-based collision detection and resolution
- **Save System** — File-based save/load with versioning
- **Game Calendar** — Day/night cycles, seasons, curfew
- **Multiplayer Networking** — Encrypted host/client transport with state sync and input prediction

## Packages

### Core

| Package | Description | pub.dev |
|---------|-------------|---------|
| [fledge_ecs](packages/fledge_ecs) | Core ECS framework | [![pub](https://img.shields.io/pub/v/fledge_ecs.svg)](https://pub.dev/packages/fledge_ecs) |
| [fledge_ecs_annotations](packages/fledge_ecs_annotations) | Annotations for code generation | [![pub](https://img.shields.io/pub/v/fledge_ecs_annotations.svg)](https://pub.dev/packages/fledge_ecs_annotations) |
| [fledge_ecs_generator](packages/fledge_ecs_generator) | Code generator for components/systems | [![pub](https://img.shields.io/pub/v/fledge_ecs_generator.svg)](https://pub.dev/packages/fledge_ecs_generator) |
| [fledge_assets](packages/fledge_assets) | Ref-counted asset store | [![pub](https://img.shields.io/pub/v/fledge_assets.svg)](https://pub.dev/packages/fledge_assets) |

### Render

| Package | Description | pub.dev |
|---------|-------------|---------|
| [fledge_render_2d](packages/fledge_render_2d) | 2D rendering + core render infrastructure | [![pub](https://img.shields.io/pub/v/fledge_render_2d.svg)](https://pub.dev/packages/fledge_render_2d) |
| [fledge_camera_2d](packages/fledge_camera_2d) | Cameras, follow, shake, letterbox, parallax | [![pub](https://img.shields.io/pub/v/fledge_camera_2d.svg)](https://pub.dev/packages/fledge_camera_2d) |
| [fledge_particles](packages/fledge_particles) | CPU-driven particle system | [![pub](https://img.shields.io/pub/v/fledge_particles.svg)](https://pub.dev/packages/fledge_particles) |
| [fledge_lighting_2d](packages/fledge_lighting_2d) | Dynamic 2D lighting | [![pub](https://img.shields.io/pub/v/fledge_lighting_2d.svg)](https://pub.dev/packages/fledge_lighting_2d) |
| [fledge_tween](packages/fledge_tween) | Easing curves and value tweens | [![pub](https://img.shields.io/pub/v/fledge_tween.svg)](https://pub.dev/packages/fledge_tween) |
| [fledge_ui](packages/fledge_ui) | Retained-mode HUD/UI | [![pub](https://img.shields.io/pub/v/fledge_ui.svg)](https://pub.dev/packages/fledge_ui) |
| [fledge_debug](packages/fledge_debug) | Overlay + gizmos | [![pub](https://img.shields.io/pub/v/fledge_debug.svg)](https://pub.dev/packages/fledge_debug) |

### Plugins

| Package | Description | pub.dev |
|---------|-------------|---------|
| [fledge_input](packages/fledge_input) | Action-based input handling | [![pub](https://img.shields.io/pub/v/fledge_input.svg)](https://pub.dev/packages/fledge_input) |
| [fledge_audio](packages/fledge_audio) | Music and sound effects | [![pub](https://img.shields.io/pub/v/fledge_audio.svg)](https://pub.dev/packages/fledge_audio) |
| [fledge_window](packages/fledge_window) | Window management | [![pub](https://img.shields.io/pub/v/fledge_window.svg)](https://pub.dev/packages/fledge_window) |
| [fledge_tiled](packages/fledge_tiled) | Tiled tilemap support | [![pub](https://img.shields.io/pub/v/fledge_tiled.svg)](https://pub.dev/packages/fledge_tiled) |
| [fledge_yarn](packages/fledge_yarn) | Yarn Spinner dialogue system | [![pub](https://img.shields.io/pub/v/fledge_yarn.svg)](https://pub.dev/packages/fledge_yarn) |
| [fledge_physics](packages/fledge_physics) | Physics and collision detection | [![pub](https://img.shields.io/pub/v/fledge_physics.svg)](https://pub.dev/packages/fledge_physics) |
| [fledge_save](packages/fledge_save) | Save/load system with versioning | [![pub](https://img.shields.io/pub/v/fledge_save.svg)](https://pub.dev/packages/fledge_save) |
| [fledge_calendar](packages/fledge_calendar) | Game calendar and day/night cycles | [![pub](https://img.shields.io/pub/v/fledge_calendar.svg)](https://pub.dev/packages/fledge_calendar) |
| [fledge_net](packages/fledge_net) | Multiplayer networking | [![pub](https://img.shields.io/pub/v/fledge_net.svg)](https://pub.dev/packages/fledge_net) |

### Deprecated shims

| Package | Successor |
|---------|-----------|
| [fledge_render](packages/fledge_render) | Merged into [fledge_render_2d](packages/fledge_render_2d) |
| [fledge_time](packages/fledge_time) | Renamed to [fledge_calendar](packages/fledge_calendar) |

## Quick Start

Add Fledge to your project:

```yaml
dependencies:
  fledge_ecs: ^0.2.0
```

Create your first ECS app:

```dart
import 'package:fledge_ecs/fledge_ecs.dart';

// Components are plain Dart classes
class Position {
  double x, y;
  Position(this.x, this.y);
}

class Velocity {
  double x, y;
  Velocity(this.x, this.y);
}

// Systems operate on component queries
class MovementSystem extends System {
  @override
  SystemMeta get meta => SystemMeta(
    name: 'movement',
    writes: {ComponentId.of<Position>()},
    reads: {ComponentId.of<Velocity>()},
    resourceReads: {WallTime},
  );

  @override
  Future<void> run(World world) async {
    final time = world.getResource<WallTime>()!;
    for (final (_, pos, vel) in world.query2<Position, Velocity>().iter()) {
      pos.x += vel.x * time.delta;
      pos.y += vel.y * time.delta;
    }
  }
}

void main() async {
  final app = App()
    ..addPlugin(WallTimePlugin())
    ..addSystem(MovementSystem());

  // Spawn an entity
  app.world.spawn()
    ..insert(Position(0, 0))
    ..insert(Velocity(10, 5));

  // Run the game loop
  await app.run();
}
```

## Documentation

Visit [fledge-framework.dev](https://fledge-framework.dev) for:

- [Getting Started Guide](https://fledge-framework.dev/docs/getting-started)
- [Core Concepts](https://fledge-framework.dev/docs/getting-started/core-concepts)
- [Plugins](https://fledge-framework.dev/docs/plugins/overview)
- [API Reference](https://fledge-framework.dev/docs/api)
- [Examples](https://fledge-framework.dev/docs/examples)

## Examples

See the [examples](examples/) directory for complete sample projects.

## Development

This monorepo uses [Melos](https://melos.invertase.dev/) for package management:

```bash
# Install melos
dart pub global activate melos

# Bootstrap all packages
melos bootstrap

# Run tests across all packages
melos run test

# Analyze all packages
melos run analyze
```

## Contributing

Contributions are welcome! Please read our [contributing guidelines](CONTRIBUTING.md) before submitting PRs.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
