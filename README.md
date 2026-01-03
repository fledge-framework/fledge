# Fledge

A Bevy-inspired Entity Component System (ECS) framework for Dart and Flutter game development.

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

## Overview

Fledge brings the power of modern ECS architecture to Flutter, enabling you to build performant 2D games with clean, composable code. Inspired by [Bevy](https://bevyengine.org/), Fledge separates data (components) from logic (systems) for maximum flexibility and testability.

## Features

- **Entity Component System** - Compose game objects from reusable components
- **System Scheduling** - Automatic parallel execution with dependency resolution
- **Two-World Architecture** - Separate game logic from GPU-optimized rendering
- **Plugin System** - Modular, reusable game features
- **Action-Based Input** - Map physical inputs to semantic actions
- **Spatial Audio** - 2D positional audio with volume channels
- **Tiled Integration** - Load and render TMX/TSX tilemaps

## Packages

| Package | Description | pub.dev |
|---------|-------------|---------|
| [fledge_ecs](packages/fledge_ecs) | Core ECS framework | [![pub](https://img.shields.io/pub/v/fledge_ecs.svg)](https://pub.dev/packages/fledge_ecs) |
| [fledge_ecs_annotations](packages/fledge_ecs_annotations) | Annotations for code generation | [![pub](https://img.shields.io/pub/v/fledge_ecs_annotations.svg)](https://pub.dev/packages/fledge_ecs_annotations) |
| [fledge_ecs_generator](packages/fledge_ecs_generator) | Code generator for components/systems | [![pub](https://img.shields.io/pub/v/fledge_ecs_generator.svg)](https://pub.dev/packages/fledge_ecs_generator) |
| [fledge_render](packages/fledge_render) | Render infrastructure | [![pub](https://img.shields.io/pub/v/fledge_render.svg)](https://pub.dev/packages/fledge_render) |
| [fledge_render_2d](packages/fledge_render_2d) | 2D rendering components | [![pub](https://img.shields.io/pub/v/fledge_render_2d.svg)](https://pub.dev/packages/fledge_render_2d) |
| [fledge_render_flutter](packages/fledge_render_flutter) | Flutter render backend | [![pub](https://img.shields.io/pub/v/fledge_render_flutter.svg)](https://pub.dev/packages/fledge_render_flutter) |
| [fledge_input](packages/fledge_input) | Action-based input handling | [![pub](https://img.shields.io/pub/v/fledge_input.svg)](https://pub.dev/packages/fledge_input) |
| [fledge_audio](packages/fledge_audio) | Music and sound effects | [![pub](https://img.shields.io/pub/v/fledge_audio.svg)](https://pub.dev/packages/fledge_audio) |
| [fledge_window](packages/fledge_window) | Window management | [![pub](https://img.shields.io/pub/v/fledge_window.svg)](https://pub.dev/packages/fledge_window) |
| [fledge_tiled](packages/fledge_tiled) | Tiled tilemap support | [![pub](https://img.shields.io/pub/v/fledge_tiled.svg)](https://pub.dev/packages/fledge_tiled) |

## Quick Start

Add Fledge to your project:

```yaml
dependencies:
  fledge_ecs: ^0.1.0
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
    resourceReads: {Time},
  );

  @override
  Future<void> run(World world) async {
    final time = world.getResource<Time>()!;
    for (final (_, pos, vel) in world.query2<Position, Velocity>().iter()) {
      pos.x += vel.x * time.delta;
      pos.y += vel.y * time.delta;
    }
  }
}

void main() async {
  final app = App()
    ..addPlugin(TimePlugin())
    ..addSystem(MovementSystem());

  // Spawn an entity
  app.world.spawn()
    ..insert(Position(0, 0))
    ..insert(Velocity(10, 5));

  // Run the game loop
  while (true) {
    await app.tick();
  }
}
```

## Documentation

Visit [fledge-framework.dev](https://fledge-framework.dev) for:

- [Getting Started Guide](https://fledge-framework.dev/docs/getting-started)
- [Core Concepts](https://fledge-framework.dev/docs/getting-started/core-concepts)
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

Contributions are welcome! Please read our contributing guidelines before submitting PRs.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
