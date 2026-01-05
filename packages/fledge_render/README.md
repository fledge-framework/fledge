# fledge_render

Core render infrastructure for [Fledge](https://fledge-framework.dev) - render graph, two-world architecture, and render scheduling.

[![pub package](https://img.shields.io/pub/v/fledge_render.svg)](https://pub.dev/packages/fledge_render)

## Features

- **Two-World Architecture**: Separate game logic from rendering
- **Render World**: GPU-optimized data structures rebuilt each frame
- **Extractors**: Transform game data to render data
- **Render Layers**: Organize rendering into composable layers
- **Render Graph**: Modular render pipeline definition
- **RenderPlugin**: Automatic extraction system setup

## Installation

```yaml
dependencies:
  fledge_render: ^0.1.0
```

## Quick Start

Use `RenderPlugin` to set up the extraction system automatically:

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render/fledge_render.dart';

void main() {
  final app = App()
    .addPlugin(TimePlugin())
    .addPlugin(RenderPlugin());  // Sets up Extractors, RenderWorld, and extraction system

  // Register your extractors
  final extractors = app.world.getResource<Extractors>()!;
  extractors.register(SpriteExtractor());
  extractors.register(TilemapExtractor());

  app.run();
}
```

The `RenderPlugin` provides:
- `Extractors` resource for registering component extractors
- `RenderWorld` resource for storing extracted render data
- `RenderExtractionSystem` that runs at `CoreStage.last`

## Two-World Architecture

Fledge separates game logic (Main World) from rendering (Render World):

```dart
// Main World: Game entities with components
world.spawn()
  ..insert(Position(100, 200))
  ..insert(Sprite(texture: heroTexture));

// Extractors copy data to Render World each frame
class SpriteExtractor extends Extractor {
  @override
  void extract(World mainWorld, RenderWorld renderWorld) {
    for (final (_, sprite, transform) in
        mainWorld.query2<Sprite, GlobalTransform2D>().iter()) {
      renderWorld.spawn().insert(ExtractedSprite(
        texture: sprite.texture,
        transform: transform.matrix,
      ));
    }
  }
}
```

## Documentation

See the [Two-World Architecture Guide](https://fledge-framework.dev/docs/guides/two-world-architecture) for detailed documentation.

## Related Packages

- [fledge_ecs](https://pub.dev/packages/fledge_ecs) - Core ECS framework
- [fledge_render_2d](https://pub.dev/packages/fledge_render_2d) - 2D rendering components

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
