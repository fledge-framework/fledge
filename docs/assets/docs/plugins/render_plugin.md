# Render Infrastructure

The `fledge_render` package provides core rendering infrastructure for Fledge games, including the two-world architecture, extraction system, and render layers.

## Installation

```yaml
dependencies:
  fledge_render: ^0.1.0
```

## RenderPlugin

`RenderPlugin` sets up the render extraction infrastructure. Add it before any plugins that register extractors.

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render/fledge_render.dart';

void main() async {
  final app = App()
    .addPlugin(TimePlugin())
    .addPlugin(RenderPlugin());  // Sets up extraction automatically

  // Register extractors
  final extractors = app.world.getResource<Extractors>()!;
  extractors.register(MyExtractor());

  await app.run();
}
```

**Provides:**
- `Extractors` resource - Registry for component extractors
- `RenderWorld` resource - Separate world for extracted render data
- `RenderExtractionSystem` - Runs at `CoreStage.last`, clears render world and executes all extractors

## Two-World Architecture

Fledge separates game logic from rendering using two distinct worlds:

| World | Purpose | Contents |
|-------|---------|----------|
| **Main World** | Game logic | Entities with game components (Position, Velocity, Player, etc.) |
| **Render World** | GPU-ready data | Extracted data optimized for rendering |

Each frame:
1. Main world systems run (game logic)
2. `RenderExtractionSystem` clears render world and runs all extractors
3. Painters query only the render world

This decoupling enables:
- Different render backends without changing game code
- GPU-optimized data structures
- Clean separation of concerns

See [Two-World Architecture Guide](/docs/guides/two-world-architecture) for details on writing extractors.

## Extractors

Extractors copy and transform data from the main world to the render world.

### Registering Extractors

```dart
// In your game plugin or setup
final extractors = app.world.getResource<Extractors>()!;
extractors.register(SpriteExtractor());
extractors.register(TilemapExtractor());
extractors.register(ParticleExtractor());
```

### Creating Custom Extractors

```dart
class ParticleExtractor extends Extractor {
  @override
  void extract(World mainWorld, RenderWorld renderWorld) {
    for (final (_, pos, particle) in
        mainWorld.query2<Position, Particle>().iter()) {
      renderWorld.spawn().insert(ExtractedParticle(
        x: pos.x,
        y: pos.y,
        radius: particle.radius,
        color: particle.color,
      ));
    }
  }
}
```

### Extracted Data Types

Use `ExtractedData` mixin for render-world components:

```dart
class ExtractedParticle with ExtractedData {
  final double x;
  final double y;
  final double radius;
  final Color color;

  const ExtractedParticle({
    required this.x,
    required this.y,
    required this.radius,
    required this.color,
  });
}
```

For sortable entities, add `SortableExtractedData`:

```dart
class ExtractedCharacter with ExtractedData, SortableExtractedData {
  final double x;
  final double y;
  final int spriteIndex;

  @override
  final int sortKey;

  ExtractedCharacter({
    required this.x,
    required this.y,
    required this.spriteIndex,
  }) : sortKey = (y * 1000).toInt();
}
```

## RenderLayer

`RenderLayer` is an abstract class for organizing render passes. Each layer encapsulates a specific rendering concern.

### Basic Usage

```dart
import 'package:fledge_render/fledge_render.dart';

class BackgroundLayer extends RenderLayer {
  @override
  void paint(Canvas canvas, Size size, RenderWorld renderWorld) {
    // Draw background elements
    for (final (_, bg) in renderWorld.query1<ExtractedBackground>().iter()) {
      canvas.drawRect(bg.rect, Paint()..color = bg.color);
    }
  }
}

class CharacterLayer extends RenderLayer {
  @override
  void paint(Canvas canvas, Size size, RenderWorld renderWorld) {
    // Draw characters sorted by Y position
    final chars = renderWorld.query1<ExtractedCharacter>()
      .iter()
      .toList()
      ..sort((a, b) => a.$2.sortKey.compareTo(b.$2.sortKey));

    for (final (_, char) in chars) {
      // Draw character...
    }
  }
}
```

### Composing Layers

Use `CompositeRenderLayer` to combine multiple layers:

```dart
final gameLayer = CompositeRenderLayer([
  BackgroundLayer(),
  TilemapLayer(),
  CharacterLayer(),
  ParticleLayer(),
  UILayer(),
]);

// In your CustomPainter
class GamePainter extends CustomPainter {
  final RenderWorld renderWorld;
  final CompositeRenderLayer layers;

  GamePainter(this.renderWorld, this.layers);

  @override
  void paint(Canvas canvas, Size size) {
    layers.paint(canvas, size, renderWorld);
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}
```

### Utility Layers

`fledge_render` provides several utility layers for common patterns:

**TransformedRenderLayer** - Apply camera/viewport transforms:

```dart
final cameraLayer = TransformedRenderLayer(
  transform: cameraMatrix,
  child: gameContentLayer,
);
```

**ClippedRenderLayer** - Clip to a rectangle (viewports, split-screen):

```dart
final viewportLayer = ClippedRenderLayer(
  clipRect: Rect.fromLTWH(0, 0, 400, 300),
  child: gameLayer,
);
```

**ConditionalRenderLayer** - Conditionally render (debug overlays, pause screens):

```dart
final debugLayer = ConditionalRenderLayer(
  condition: () => showDebugOverlay,
  child: DebugInfoLayer(),
);
```

## DrawLayer Sort Keys

For layer-based sorting, use the `DrawLayer` enum:

```dart
import 'package:fledge_render/fledge_render.dart';

// Built-in layers with predefined ranges:
// - background:  0 - 99,999
// - ground:      100,000 - 199,999
// - characters:  200,000 - 299,999
// - foreground:  300,000 - 399,999
// - particles:   400,000 - 499,999
// - ui:          500,000+

class ExtractedSprite with ExtractedData, SortableExtractedData {
  @override
  final int sortKey;
  final DrawLayer layer;

  ExtractedSprite({required this.layer, required double y, ...})
    : sortKey = layer.sortKey(subOrder: (y * 1000).toInt());
}
```

## Flutter Integration

For Flutter apps, rendering is done through `CustomPainter` widgets that query the `RenderWorld`:

```dart
import 'package:fledge_render/fledge_render.dart';
import 'package:flutter/material.dart';

class GamePainter extends CustomPainter {
  final RenderWorld renderWorld;

  GamePainter(this.renderWorld);

  @override
  void paint(Canvas canvas, Size size) {
    // Query extracted data from render world
    for (final (_, sprite) in renderWorld.query1<ExtractedSprite>().iter()) {
      // Draw using Flutter Canvas API
    }
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}

// In your widget
CustomPaint(
  painter: GamePainter(renderWorld),
  size: gameSize,
)
```

## Render Graph (Advanced)

For complex render pipelines, `fledge_render` provides a render graph:

```dart
final graph = RenderGraph();

// Add render nodes
graph.addNode(CameraDriverNode());
graph.addNode(SpriteRenderNode());

// Connect nodes via typed slots
graph.addEdge(
  SlotId('camera_driver', 'view'),
  SlotId('sprite_render', 'view'),
);

// Execute the graph
graph.execute(renderContext);
```

### Render Stages

| Stage | Purpose |
|-------|---------|
| `RenderStage.extract` | Copy main world to render world |
| `RenderStage.prepare` | Create/update GPU resources |
| `RenderStage.queue` | Collect and sort draw calls |
| `RenderStage.render` | Execute GPU commands |
| `RenderStage.cleanup` | Release temporary resources |

## Resources Reference

| Resource | Description |
|----------|-------------|
| `RenderWorld` | Separate world for render data |
| `Extractors` | Registry of data extractors |
| `RenderGraph` | DAG-based render pipeline |

## Layers Reference

| Class | Description |
|-------|-------------|
| `RenderLayer` | Abstract base class for render layers |
| `CompositeRenderLayer` | Combines multiple layers in order |
| `TransformedRenderLayer` | Applies a transform matrix before rendering |
| `ClippedRenderLayer` | Clips rendering to a rectangle |
| `ConditionalRenderLayer` | Conditionally renders based on a predicate |

## See Also

- [Two-World Architecture](/docs/guides/two-world-architecture) - Extraction system details
- [2D Rendering](/docs/plugins/render) - Sprites, cameras, and animations
- [Plugins Overview](/docs/plugins/overview) - Plugin system introduction
