# Two-World Architecture

Fledge separates game logic from rendering using a **two-world architecture**. This design decouples your game code from rendering details, enabling efficient GPU-optimized data flow.

## Overview

The two-world architecture consists of:

| World | Purpose | Lifecycle |
|-------|---------|-----------|
| **Main World** | Game entities, components, and logic | Persistent across frames |
| **Render World** | GPU-optimized render data | Rebuilt each frame |

```
Main World (Game Logic)
├── Entities with Position, Velocity, Health...
├── Resources like Time, Input, GameConfig...
└── Systems that update game state
         │
         │ Each frame: Extract
         ↓
Render World (GPU Data)
├── ExtractedSprite, ExtractedTile...
├── Pre-computed transforms (matrices)
└── Sort keys, batching data
         │
         │ Render pipeline
         ↓
     GPU Rendering
```

## Why Two Worlds?

**Decoupling**: Game systems don't need to know about rendering. A `Position` component stays simple; the rendering system handles transformation to screen coordinates.

**Performance**: The render world contains GPU-optimized data structures. Transforms are pre-computed as matrices, sort keys are pre-calculated, and data is organized for efficient batching.

**Clean Architecture**: Game code remains focused on gameplay. Rendering code can change without affecting game logic.

**Flexibility**: Different render backends can consume the same extracted data without changing game code.

## The Extraction Process

Each frame, **Extractors** copy relevant data from the main world to the render world. The extraction infrastructure is provided by `fledge_render`:

```dart
import 'package:fledge_render/fledge_render.dart';

// Extractor, Extractors, RenderWorld, and ExtractSystem
// are all provided by fledge_render
```

The base `Extractor` class defines the extraction interface:

```dart
abstract class Extractor {
  void extract(World mainWorld, RenderWorld renderWorld);
}
```

### Example: Sprite Extraction

```dart
class SpriteExtractor extends Extractor {
  @override
  void extract(World mainWorld, RenderWorld renderWorld) {
    // Query main world for sprites
    for (final (entity, sprite, transform) in
        mainWorld.query2<Sprite, GlobalTransform2D>().iter()) {

      // Skip invisible entities
      final visibility = mainWorld.get<Visibility>(entity);
      if (visibility != null && !visibility.isVisible) continue;

      // Create GPU-optimized data in render world
      renderWorld.spawn().insert(ExtractedSprite(
        texture: sprite.texture,
        sourceRect: sprite.effectiveSourceRect,
        transform: transform.matrix,  // Pre-computed matrix
        color: sprite.color,
        sortKey: (transform.y * 1000).toInt(),  // Pre-calculated
      ));
    }
  }
}
```

The extractor:
1. Queries the main world for entities with relevant components
2. Transforms data into GPU-friendly format
3. Spawns new entities in the render world with optimized components

### Registering Extractors

Use `RenderPlugin` to set up the extraction infrastructure, then register your extractors via the `Extractors` resource:

```dart
// Add RenderPlugin to set up Extractors, RenderWorld, and extraction system
app.addPlugin(RenderPlugin());

// Register extractors
final extractors = app.world.getResource<Extractors>()!;
extractors.register(SpriteExtractor());
extractors.register(TilemapExtractor());
extractors.register(ParticleExtractor());
```

The `RenderPlugin` provides:
- `Extractors` resource for registering component extractors
- `RenderWorld` resource for storing extracted render data
- `RenderExtractionSystem` that runs at `CoreStage.last`

## RenderWorld

`RenderWorld` is a separate ECS world optimized for rendering:

```dart
class RenderWorld {
  // Clear all entities (called each frame)
  void clear();

  // Spawn extracted entities
  EntityCommands spawn();

  // Query extracted data
  Query1<T> query1<T>({QueryFilter? filter});
  Query2<T1, T2> query2<T1, T2>({QueryFilter? filter});

  // Resources persist across clears
  T? getResource<T>();
  void insertResource<T>(T resource);
}
```

Key characteristics:
- **Cleared each frame**: Entities are removed, but resources persist
- **Same query API**: Query extracted components just like the main world
- **Lightweight**: No change detection or observers needed

## Render Pipeline Stages

The render system processes frames in five stages:

### 1. Extract Stage

```dart
RenderStage.extract
```

- Clears the render world
- Runs all registered extractors
- Copies data from main world to render world

### 2. Prepare Stage

```dart
RenderStage.prepare
```

- Creates or updates GPU resources
- Uploads textures and buffers
- Prepares materials and shaders

### 3. Queue Stage

```dart
RenderStage.queue
```

- Collects draw calls
- Sorts by material, depth, or custom criteria
- Batches sprites for efficient rendering

### 4. Render Stage

```dart
RenderStage.render
```

- Executes the render graph
- GPU rendering happens here
- Uses prepared resources and queued commands

### 5. Cleanup Stage

```dart
RenderStage.cleanup
```

- Releases temporary resources
- Resets state for next frame

## Data Flow Example

Here's the complete flow for rendering sprites:

```
Main World                          Render World
───────────────────────────────────────────────────────
Entity A:
  Position(100, 200)
  Sprite(texture: hero.png)
  Visibility(true)

Entity B:
  Position(300, 150)
  Sprite(texture: enemy.png)
  Visibility(true)

         │
         │ SpriteExtractor.extract()
         ↓
                                    Entity X:
                                      ExtractedSprite(
                                        texture: hero.png,
                                        transform: Matrix4(...),
                                        sortKey: 200000,
                                      )

                                    Entity Y:
                                      ExtractedSprite(
                                        texture: enemy.png,
                                        transform: Matrix4(...),
                                        sortKey: 150000,
                                      )
```

## Writing Custom Extractors

### Basic Extractor

```dart
class HealthBarExtractor extends Extractor {
  @override
  void extract(World mainWorld, RenderWorld renderWorld) {
    for (final (entity, health, transform) in
        mainWorld.query2<Health, GlobalTransform2D>().iter()) {

      // Only show health bars for damaged entities
      if (health.current >= health.max) continue;

      renderWorld.spawn().insert(ExtractedHealthBar(
        position: transform.translation,
        percentage: health.current / health.max,
        width: 32.0,
        height: 4.0,
      ));
    }
  }
}
```

### Component Extractor (Convenience)

For simple 1:1 extraction:

```dart
final myExtractor = ComponentExtractor<MyComponent, ExtractedMyComponent>(
  (world, entity, component) => ExtractedMyComponent(
    data: component.data,
    // transform as needed
  ),
  filter: const With<Visible>(),  // Optional filter
);
```

### Extractor with Resources

```dart
class CameraExtractor extends Extractor {
  @override
  void extract(World mainWorld, RenderWorld renderWorld) {
    // Access main world resources
    final windowSize = mainWorld.getResource<WindowSize>();

    for (final (_, camera, transform) in
        mainWorld.query2<Camera2D, GlobalTransform2D>().iter()) {

      renderWorld.spawn().insert(ExtractedCamera(
        viewMatrix: camera.computeViewMatrix(transform),
        projectionMatrix: camera.computeProjectionMatrix(windowSize),
        viewport: camera.viewport,
      ));
    }
  }
}
```

## Defining Extracted Components

Extracted components are the data classes that live in the render world. Fledge provides two mixins in `fledge_render` to help define them:

| Mixin | Purpose |
|-------|---------|
| `ExtractedData` | Marker mixin for any extracted data |
| `SortableExtractedData` | For entities that need draw ordering via `sortKey` |

### Basic Extracted Component

Use the `ExtractedData` mixin for simple extracted data:

```dart
import 'package:fledge_render/fledge_render.dart';

/// Extracted data for a particle effect.
class ExtractedParticle with ExtractedData {
  /// Pre-computed screen position.
  final double x;
  final double y;

  /// Particle radius in pixels.
  final double radius;

  /// Render color with alpha.
  final Color color;

  const ExtractedParticle({
    required this.x,
    required this.y,
    required this.radius,
    required this.color,
  });
}
```

### Sortable Extracted Component

Use `SortableExtractedData` when entities need draw ordering:

```dart
import 'package:fledge_render/fledge_render.dart';

/// Extracted character data with Y-sorting.
class ExtractedCharacter with ExtractedData, SortableExtractedData {
  final double x;
  final double y;
  final int spriteIndex;
  final Color tint;

  /// Sort key for draw ordering (higher Y = drawn later = in front).
  @override
  final int sortKey;

  ExtractedCharacter({
    required this.x,
    required this.y,
    required this.spriteIndex,
    required this.tint,
  }) : sortKey = (y * 1000).toInt();  // Multiply for precision
}
```

### Sort Key Strategies

Sort keys determine draw order. Lower values are drawn first (behind), higher values last (in front).

**Y-sorting** (top-down games):

```dart
sortKey = (position.y * 1000).toInt()
```

**Layer-based sorting** (platformers, tilemaps):

```dart
import 'package:fledge_render/fledge_render.dart';

// Using the DrawLayer enum for semantic layer names
sortKey = DrawLayer.characters.sortKey(subOrder: (position.y * 1000).toInt())

// Or for dynamic layer indices (e.g., tilemaps with many layers)
sortKey = DrawLayerExtension.sortKeyFromIndex(
  layerIndex: layer,
  subOrder: (position.y * 100).toInt(),
)
```

**Explicit Z-index** (UI elements):

```dart
sortKey = zIndex * 1000
```

### Design Guidelines

**Immutability**: Use `const` constructors and `final` fields. Extracted data should never be mutated after creation.

```dart
// Good: Immutable
const ExtractedEnemy({
  required this.x,
  required this.y,
  required this.spriteIndex,
});

// Avoid: Mutable fields
class ExtractedEnemy {
  double x;  // Mutable - can cause issues
}
```

**Pre-computed values**: Transform data during extraction:

```dart
// Good: Matrix ready to use
ExtractedSprite(
  transform: globalTransform.matrix,
  sortKey: computeSortKey(transform, layer),
)

// Avoid: Raw values needing later computation
ExtractedSprite(
  position: position,
  rotation: rotation,
  scale: scale,
)
```

**Render-only data**: Don't copy game logic state:

```dart
// Good: Only render fields
ExtractedEnemy(
  position: transform.translation,
  spriteIndex: enemy.currentFrame,
  tint: enemy.isDamaged ? Colors.red : Colors.white,
)

// Avoid: Game logic data
ExtractedEnemy(
  health: enemy.health,      // Not needed for rendering
  aiState: enemy.aiState,    // Not needed for rendering
)
```

## Plugin Integration

Plugins that need rendering should register their extractors. Ensure `RenderPlugin` is added before your plugin so that the `Extractors` resource is available:

```dart
// In your app setup
app
  .addPlugin(RenderPlugin())      // Must come first
  .addPlugin(MyGamePlugin());     // Can now access Extractors

// In your game plugin
class MyGamePlugin implements Plugin {
  @override
  void build(App app) {
    // RenderPlugin has already set up Extractors
    final extractors = app.world.getResource<Extractors>()!;
    extractors.register(MyComponentExtractor());
  }

  @override
  void cleanup() {}
}
```

## Querying Extracted Data

In render systems, query the render world:

```dart
class SpriteBatchSystem implements RenderSystem {
  @override
  void run(World mainWorld, RenderWorld renderWorld) {
    // Query extracted sprites from render world
    final sprites = renderWorld.query1<ExtractedSprite>()
      .iter()
      .toList()
      ..sort((a, b) => a.$2.sortKey.compareTo(b.$2.sortKey));

    // Batch by texture for efficient rendering
    final batches = <TextureHandle, List<ExtractedSprite>>{};
    for (final (_, sprite) in sprites) {
      batches.putIfAbsent(sprite.texture, () => []).add(sprite);
    }

    // Render each batch
    for (final entry in batches.entries) {
      renderBatch(entry.key, entry.value);
    }
  }
}
```

## Best Practices

### Extract Only What You Need

Don't copy entire components if you only need a few fields:

```dart
// Good: Extract only render-relevant data
ExtractedEnemy(
  position: transform.translation,
  spriteIndex: enemy.currentFrame,
  tint: enemy.isDamaged ? Colors.red : Colors.white,
)

// Avoid: Copying game logic data
ExtractedEnemy(
  health: enemy.health,      // Not needed for rendering
  aiState: enemy.aiState,    // Not needed for rendering
  inventory: enemy.items,    // Not needed for rendering
)
```

### Pre-compute in Extractors

Do expensive calculations during extraction, not during rendering:

```dart
// Good: Pre-compute in extractor
ExtractedSprite(
  transform: globalTransform.matrix,  // Matrix already computed
  sortKey: computeSortKey(transform, layer),  // Sort key ready
)

// Avoid: Deferring computation to render time
ExtractedSprite(
  position: transform.translation,  // Will need matrix later
  rotation: transform.rotation,     // Will need to combine
  scale: transform.scale,           // Inefficient
)
```

### Use Filters for Efficiency

Skip entities early with query filters:

```dart
// Efficient: Filter at query level
for (final (_, sprite, transform) in
    mainWorld.query2<Sprite, GlobalTransform2D>(
      filter: const With<Visible>(),  // Skip invisible entities
    ).iter()) {
  // Only processes visible entities
}
```

## See Also

- [App & Plugins](/docs/guides/app-plugins) - Plugin system overview
- [Systems](/docs/guides/systems) - System definition
- [Queries](/docs/guides/queries) - Querying entities
- [Tiled Tilemaps](/docs/plugins/tiled) - Example of extraction with tilemaps
