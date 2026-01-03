# 2D Rendering

Fledge's rendering system is built on three packages that work together to provide a flexible, GPU-optimized 2D rendering pipeline:

| Package | Purpose |
|---------|---------|
| `fledge_render` | Core infrastructure (RenderWorld, Extractors, RenderGraph) |
| `fledge_render_2d` | 2D components (Transform2D, Sprite, Camera2D, Animation) |
| `fledge_render_flutter` | Flutter integration (Canvas/GPU backends) |

## Installation

Add the render packages to your `pubspec.yaml`:

```yaml
dependencies:
  fledge_render: ^0.1.0
  fledge_render_2d: ^0.1.0
  fledge_render_flutter: ^0.1.0
```

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render/fledge_render.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';

void main() async {
  final app = App()
    .addPlugin(TimePlugin())
    // Add render systems manually
    .addSystem(TransformPropagateSystem())
    .addSystem(AnimateSystemWithResource());

  // Spawn a camera
  app.world.spawn()
    ..insert(Transform2D.from(0, 0))
    ..insert(GlobalTransform2D())
    ..insert(Camera2D());

  // Spawn a sprite
  app.world.spawn()
    ..insert(Transform2D.from(100, 200))
    ..insert(GlobalTransform2D())
    ..insert(Sprite(texture: playerTexture));

  await app.run();
}
```

## Transform2D

`Transform2D` represents local position, rotation, and scale relative to parent entities.

### Creating Transforms

```dart
// Full constructor
Transform2D(
  translation: Vector2(100, 200),
  rotation: math.pi / 4,  // 45 degrees in radians
  scale: Vector2(2, 2),
)

// Convenience for position-only
Transform2D.from(100, 200)

// Identity (origin, no rotation, scale 1)
Transform2D.identity()
```

### Modifying Transforms

```dart
final transform = entity.get<Transform2D>()!;

// Direct property access
transform.translation.x += 10;
transform.rotation = math.pi;
transform.scale.setValues(2, 2);

// Helper methods
transform.translate(10, 5);           // Add to position
transform.rotate(math.pi / 4);        // Add to rotation
transform.setRotationDegrees(90);     // Set in degrees
transform.setUniformScale(2.0);       // Set scale uniformly
```

### GlobalTransform2D

`GlobalTransform2D` is computed from the entity hierarchy. It represents the final world-space transform.

```dart
// Read-only - computed by TransformPropagateSystem
final global = entity.get<GlobalTransform2D>()!;
print('World position: (${global.x}, ${global.y})');
print('Rotation: ${global.rotation}');

// Get as matrix for rendering
final matrix = global.matrix;
```

Add `TransformPropagateSystem` to your app to automatically compute global transforms from the parent-child hierarchy.

## Sprites

`Sprite` is the primary component for rendering textured quads.

### Basic Sprite

```dart
world.spawn()
  ..insert(Transform2D.from(100, 200))
  ..insert(GlobalTransform2D())
  ..insert(Sprite(texture: myTexture));
```

### Sprite Options

```dart
Sprite(
  texture: myTexture,
  sourceRect: Rect.fromLTWH(0, 0, 32, 32),  // Sub-region of texture
  color: Color(0xFFFF0000),                   // Tint color
  flipX: true,                                 // Horizontal flip
  flipY: false,                                // Vertical flip
  anchor: Vector2(0.5, 0.5),                  // Center anchor (default)
  customSize: Vector2(64, 64),                // Override size
)
```

### Anchor Points

The anchor determines the sprite's pivot point:

| Anchor | Position |
|--------|----------|
| `Vector2(0, 0)` | Top-left |
| `Vector2(0.5, 0.5)` | Center (default) |
| `Vector2(0.5, 1.0)` | Bottom-center |
| `Vector2(1, 1)` | Bottom-right |

### Visibility

Hide entities from rendering without removing them:

```dart
world.spawn()
  ..insert(Transform2D.from(100, 200))
  ..insert(GlobalTransform2D())
  ..insert(Sprite(texture: myTexture))
  ..insert(Visibility(true));

// Toggle visibility
entity.get<Visibility>()!.toggle();
entity.get<Visibility>()!.hide();
entity.get<Visibility>()!.show();
```

### SpriteBundle

Convenience for spawning sprites with common components:

```dart
SpriteBundle(
  texture: playerTexture,
  x: 100,
  y: 200,
  anchor: Vector2(0.5, 1.0),
).spawn(world);
```

## Cameras

`Camera2D` defines the viewable area of the world.

### Transform2D vs GlobalTransform2D

Cameras use both transform types for different purposes:

| Transform | When to Use | Example |
|-----------|-------------|---------|
| `Transform2D` | **Setting** camera position (local coordinates) | Moving camera, following player |
| `GlobalTransform2D` | **Reading** camera position for rendering (world coordinates) | Screen-to-world conversion, visibility culling |

`GlobalTransform2D` is automatically computed by `TransformPropagateSystem` from the entity hierarchy. Always use `GlobalTransform2D` when you need the camera's actual world position for rendering calculations.

### Creating a Camera

```dart
world.spawn()
  ..insert(Transform2D.from(0, 0))       // Local position (modifiable)
  ..insert(GlobalTransform2D())           // World position (computed)
  ..insert(Camera2D(
    projection: OrthographicProjection(viewportHeight: 20),
  ));
```

### Orthographic Projection

```dart
OrthographicProjection(
  viewportHeight: 20,    // World units visible vertically
  near: -100,            // Near clip plane
  far: 100,              // Far clip plane
)
```

The viewport width is calculated automatically from the aspect ratio.

### Following a Target

Move the camera to follow a player:

```dart
class CameraFollowSystem implements System {
  @override
  Future<void> run(World world) async {
    // Get player position
    final (_, playerTransform) = world
      .query1<Transform2D>(filter: const With<Player>())
      .iter()
      .first;

    // Update camera position
    for (final (_, cameraTransform, _) in
        world.query2<Transform2D, Camera2D>().iter()) {
      cameraTransform.translation
        ..x = playerTransform.translation.x
        ..y = playerTransform.translation.y;
    }
  }
}
```

### Screen to World Conversion

Convert mouse clicks to world coordinates:

```dart
// Get camera entity and its GlobalTransform2D (world-space position)
final (cameraEntity, camera) = world.query1<Camera2D>().iter().first;
final cameraTransform = world.get<GlobalTransform2D>(cameraEntity)!;

final worldPos = camera.screenToWorld(
  Vector2(mouseX, mouseY),
  cameraTransform,
  RenderSize(screenWidth, screenHeight),
);
```

> **Note**: Use `GlobalTransform2D` (not `Transform2D`) for screen/world conversions. `GlobalTransform2D` contains the computed world-space position after parent transforms are applied.

### Split-Screen

Multiple cameras with viewports:

```dart
// Player 1 - left half
world.spawn()
  ..insert(Transform2D.from(0, 0))
  ..insert(GlobalTransform2D())
  ..insert(Camera2D(
    viewport: Viewport(x: 0, y: 0, width: 0.5, height: 1),
    order: 0,
  ));

// Player 2 - right half
world.spawn()
  ..insert(Transform2D.from(0, 0))
  ..insert(GlobalTransform2D())
  ..insert(Camera2D(
    viewport: Viewport(x: 0.5, y: 0, width: 0.5, height: 1),
    order: 1,
  ));
```

### Using Camera with CustomPainter

To render only what's visible to the camera, you need to:
1. Calculate the camera's visible world bounds
2. Apply the camera transform to the canvas
3. Cull entities outside the visible area

**Step 1: Get visible world bounds**

```dart
Rect getVisibleBounds(
  Camera2D camera,
  GlobalTransform2D cameraTransform,
  Size screenSize,
) {
  final renderSize = RenderSize(screenSize.width, screenSize.height);

  // Get visible dimensions in world units
  final visibleWidth = camera.projection.visibleWidth(renderSize);
  final visibleHeight = camera.projection.visibleHeight(renderSize);

  // Camera position is the center of the view
  final left = cameraTransform.x - visibleWidth / 2;
  final top = cameraTransform.y - visibleHeight / 2;

  return Rect.fromLTWH(left, top, visibleWidth, visibleHeight);
}
```

**Step 2: Apply camera transform to canvas**

```dart
void applyCameraTransform(
  Canvas canvas,
  Size size,
  Camera2D camera,
  GlobalTransform2D cameraTransform,
) {
  final renderSize = RenderSize(size.width, size.height);

  // Get visible dimensions
  final visibleWidth = camera.projection.visibleWidth(renderSize);
  final visibleHeight = camera.projection.visibleHeight(renderSize);

  // Calculate scale from world units to screen pixels
  final scaleX = size.width / visibleWidth;
  final scaleY = size.height / visibleHeight;

  // Transform: translate to center, then scale, then offset by camera position
  canvas.translate(size.width / 2, size.height / 2);
  canvas.scale(scaleX, -scaleY);  // Flip Y for screen coordinates
  canvas.translate(-cameraTransform.x, -cameraTransform.y);
}
```

**Step 3: Complete CustomPainter example**

```dart
class GamePainter extends CustomPainter {
  final World world;

  GamePainter(this.world);

  @override
  void paint(Canvas canvas, Size size) {
    // Get the active camera
    final cameraQuery = world.query2<Camera2D, GlobalTransform2D>().iter();
    if (cameraQuery.isEmpty) return;

    final (cameraEntity, camera, cameraTransform) = cameraQuery.first;

    // Calculate visible bounds for culling
    final visibleBounds = getVisibleBounds(camera, cameraTransform, size);

    // Add margin to avoid popping at edges
    final cullBounds = visibleBounds.inflate(64);

    // Save canvas state before transforming
    canvas.save();

    // Apply camera transform
    applyCameraTransform(canvas, size, camera, cameraTransform);

    // Draw only visible sprites
    for (final (_, sprite, transform) in
        world.query2<Sprite, GlobalTransform2D>().iter()) {

      // Simple point-in-rect culling
      if (!cullBounds.contains(Offset(transform.x, transform.y))) {
        continue;  // Skip - not visible
      }

      // Draw the sprite at its world position
      drawSprite(canvas, sprite, transform);
    }

    // Restore canvas state
    canvas.restore();
  }

  void drawSprite(Canvas canvas, Sprite sprite, GlobalTransform2D transform) {
    final srcRect = sprite.effectiveSourceRect;
    final spriteSize = sprite.size;

    // Calculate destination rect centered on anchor
    final dstRect = Rect.fromCenter(
      center: Offset(transform.x, transform.y),
      width: spriteSize.x,
      height: spriteSize.y,
    );

    // Draw (assuming you have the image from TextureHandle)
    // canvas.drawImageRect(image, srcRect, dstRect, Paint());
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}
```

**Efficient AABB culling for sprites**

For better culling accuracy, use the sprite's actual bounding box:

```dart
bool isVisible(Sprite sprite, GlobalTransform2D transform, Rect cullBounds) {
  final size = sprite.size;
  final anchor = sprite.anchor;

  // Calculate world-space bounding box
  final left = transform.x - size.x * anchor.x;
  final top = transform.y - size.y * anchor.y;
  final spriteBounds = Rect.fromLTWH(left, top, size.x, size.y);

  // Check overlap with visible area
  return cullBounds.overlaps(spriteBounds);
}
```

**Using the view-projection matrix directly**

For more complex rendering or when using raw transforms:

```dart
void paintWithMatrix(Canvas canvas, Size size, World world) {
  // Get camera with GlobalTransform2D (world-space position)
  final cameraQuery = world.query2<Camera2D, GlobalTransform2D>().iter();
  if (cameraQuery.isEmpty) return;
  final (_, camera, cameraTransform) = cameraQuery.first;

  final renderSize = RenderSize(size.width, size.height);

  // Get view-projection matrix (requires GlobalTransform2D, not Transform2D)
  final vpMatrix = camera.viewProjectionMatrix(cameraTransform, renderSize);

  // Convert to Flutter Matrix4 for canvas
  final matrix = Matrix4.identity()
    ..setEntry(0, 0, vpMatrix.entry(0, 0))
    ..setEntry(1, 1, vpMatrix.entry(1, 1))
    ..setEntry(0, 3, vpMatrix.entry(0, 3))
    ..setEntry(1, 3, vpMatrix.entry(1, 3));

  // Apply to canvas (note: requires additional screen-space conversion)
  canvas.transform(matrix.storage);
}
```

## Texture Atlas

Load sprite sheets and texture atlases for efficient batching.

### Grid Layout (Most Common)

For regular sprite sheets with uniform tiles:

```dart
final atlas = TextureAtlas.grid(
  texture: sheetTexture,
  columns: 8,
  rows: 4,
  tileWidth: 32,   // Optional: auto-calculated if omitted
  tileHeight: 32,  // Optional: auto-calculated if omitted
);
```

### Custom Layout

For non-uniform atlases, use `TextureAtlasLayout`:

```dart
final atlas = TextureAtlas(
  texture: sheetTexture,
  layout: TextureAtlasLayout.fromRects([
    Rect.fromLTWH(0, 0, 32, 32),    // Index 0
    Rect.fromLTWH(32, 0, 32, 32),   // Index 1
    Rect.fromLTWH(0, 32, 48, 48),   // Index 2 (different size)
    Rect.fromLTWH(48, 32, 32, 64),  // Index 3 (different size)
  ]),
  names: {  // Optional: named lookup
    'idle': 0,
    'walk': 1,
    'jump': 2,
    'attack': 3,
  },
);
```

### Using Atlas Sprites

```dart
// Get sprite rect by index
final region = atlas.getSpriteRect(0);

// Get sprite rect by name (if names were provided)
final jumpRect = atlas.getSpriteRectByName('jump');

// Use createSprite for convenience
world.spawn()
  ..insert(Transform2D.from(100, 200))
  ..insert(GlobalTransform2D())
  ..insert(atlas.createSprite(0));

// Or create sprite manually with region
world.spawn()
  ..insert(Transform2D.from(100, 200))
  ..insert(GlobalTransform2D())
  ..insert(Sprite.region(
    texture: atlas.texture,
    region: region,
  ));
```

## Animation

Animate sprites with frame-based animation clips. Animation frames reference sprite indices in a texture atlas.

### Creating Animation Clips

```dart
// From a range of indices (most common)
final walkClip = AnimationClip.fromIndices(
  name: 'walk',
  startIndex: 0,
  endIndex: 3,
  frameDuration: 0.1,
  looping: true,
);

// From a list of specific indices
final jumpClip = AnimationClip.fromIndexList(
  name: 'jump',
  indices: [4, 5, 6, 5, 4],  // Can repeat frames
  frameDuration: 0.15,
  looping: false,
);

// With variable durations per frame
final idleClip = AnimationClip.withDurations(
  name: 'idle',
  indices: [0, 1, 2, 1],
  durations: [0.5, 0.1, 0.5, 0.1],  // Different timing per frame
  looping: true,
);

// Manual frame construction
final customClip = AnimationClip(
  name: 'custom',
  frames: [
    AnimationFrame(index: 0, duration: 0.2),
    AnimationFrame(index: 1, duration: 0.1),
    AnimationFrame(index: 2, duration: 0.3),
  ],
  looping: true,
);
```

### Animation Player

```dart
world.spawn()
  ..insert(Transform2D.from(100, 200))
  ..insert(GlobalTransform2D())
  ..insert(Sprite(texture: spriteSheet))
  ..insert(AnimationPlayer(
    animations: {
      'walk': walkClip,
      'idle': idleClip,
      'jump': jumpClip,
    },
    initialAnimation: 'idle',  // Optional: start playing immediately
  ));

// Control playback
final player = entity.get<AnimationPlayer>()!;
player.play('walk');           // Switch animation
player.play('walk', restart: true);  // Restart even if already playing
player.pause();
player.resume();
player.stop();                 // Stop and reset to beginning
player.toggle();               // Toggle play/pause

// Query state
print(player.currentAnimation);  // 'walk'
print(player.currentIndex);      // Current sprite index
print(player.isPlaying);         // true/false
print(player.progress);          // 0.0 to 1.0
```

Add `AnimateSystemWithResource` to your app to update sprite source rects each frame (uses `Time` resource for delta time).

## RenderWorld and Extraction

The render system uses a two-world architecture for performance. See [Two-World Architecture](/docs/guides/two-world-architecture) for details.

### Quick Overview

```dart
// Main World: Game logic
world.spawn()
  ..insert(Transform2D.from(100, 200))   // Local transform
  ..insert(GlobalTransform2D())           // World transform (computed)
  ..insert(Sprite(texture: myTexture));   // Sprite data

// Render World: GPU-ready data (created by extractors)
// ExtractedSprite with:
//   - Pre-computed world-space matrix
//   - Pre-calculated sort key
//   - Texture handle ready for batching
```

### Creating Custom Extracted Components

Use `ExtractedData` for render-world components:

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

For sortable entities, use `SortableExtractedData`:

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

## Multiple Painters and Render Layers

Games often need to render different types of entities with different painters - tilemaps, NPCs, particles, UI, etc. Fledge supports this through distinct extracted component types that painters can query independently.

### Pattern: Separate Extracted Types per Painter

Create distinct extracted component types for each renderable category:

```dart
// Tilemap tiles - rendered first (background)
class ExtractedTile with ExtractedData, SortableExtractedData {
  final TextureHandle texture;
  final Rect sourceRect;
  final Offset position;
  @override
  final int sortKey;

  const ExtractedTile({...});
}

// NPCs/Characters - rendered after tiles
class ExtractedNPC with ExtractedData, SortableExtractedData {
  final double x;
  final double y;
  final int spriteIndex;
  final Color tint;
  @override
  final int sortKey;

  ExtractedNPC({required this.y, ...})
    : sortKey = (y * 1000).toInt();  // Y-sorted within NPC layer
}

// Particles - rendered on top
class ExtractedParticle with ExtractedData {
  final double x;
  final double y;
  final double radius;
  final Color color;

  const ExtractedParticle({...});
}
```

### Pattern: Specialized Painters

Each painter queries only its component type from the render world:

```dart
/// Renders tilemap background layers.
class TilemapPainter extends CustomPainter {
  final RenderWorld renderWorld;

  TilemapPainter(this.renderWorld);

  @override
  void paint(Canvas canvas, Size size) {
    // Query only tilemap data
    final tiles = renderWorld.query1<ExtractedTile>()
      .iter()
      .toList()
      ..sort((a, b) => a.$2.sortKey.compareTo(b.$2.sortKey));

    for (final (_, tile) in tiles) {
      // Draw tile...
    }
  }
}

/// Renders NPCs and characters.
class NPCPainter extends CustomPainter {
  final RenderWorld renderWorld;

  NPCPainter(this.renderWorld);

  @override
  void paint(Canvas canvas, Size size) {
    // Query only NPC data
    final npcs = renderWorld.query1<ExtractedNPC>()
      .iter()
      .toList()
      ..sort((a, b) => a.$2.sortKey.compareTo(b.$2.sortKey));

    for (final (_, npc) in npcs) {
      // Draw NPC...
    }
  }
}

/// Renders particle effects.
class ParticlePainter extends CustomPainter {
  final RenderWorld renderWorld;

  ParticlePainter(this.renderWorld);

  @override
  void paint(Canvas canvas, Size size) {
    for (final (_, particle) in renderWorld.query1<ExtractedParticle>().iter()) {
      // Draw particle...
    }
  }
}
```

### Composing Painters

**Option 1: Stack of CustomPaint widgets**

Control render order through widget order:

```dart
Stack(
  children: [
    // Background (rendered first)
    CustomPaint(
      painter: TilemapPainter(renderWorld),
      size: gameSize,
    ),
    // Middle layer
    CustomPaint(
      painter: NPCPainter(renderWorld),
      size: gameSize,
    ),
    // Foreground (rendered last)
    CustomPaint(
      painter: ParticlePainter(renderWorld),
      size: gameSize,
    ),
  ],
)
```

**Option 2: RenderLayer pattern (Recommended)**

Use the `RenderLayer` abstract class from `fledge_render_flutter`:

```dart
import 'package:fledge_render_flutter/fledge_render_flutter.dart';

class TilemapLayer extends RenderLayer {
  @override
  void paint(Canvas canvas, Size size, RenderWorld renderWorld) {
    final tiles = renderWorld.query1<ExtractedTile>()
      .iter()
      .toList()
      ..sort((a, b) => a.$2.sortKey.compareTo(b.$2.sortKey));

    for (final (_, tile) in tiles) {
      // Draw tile...
    }
  }
}

class NPCLayer extends RenderLayer {
  @override
  void paint(Canvas canvas, Size size, RenderWorld renderWorld) {
    final npcs = renderWorld.query1<ExtractedNPC>()
      .iter()
      .toList()
      ..sort((a, b) => a.$2.sortKey.compareTo(b.$2.sortKey));

    for (final (_, npc) in npcs) {
      // Draw NPC...
    }
  }
}
```

Compose layers in your painter:

```dart
class GamePainter extends CustomPainter {
  final RenderWorld renderWorld;
  final List<RenderLayer> layers;

  GamePainter(this.renderWorld, {required this.layers});

  @override
  void paint(Canvas canvas, Size size) {
    for (final layer in layers) {
      layer.paint(canvas, size, renderWorld);
    }
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}

// Usage
CustomPaint(
  painter: GamePainter(
    renderWorld,
    layers: [
      TilemapLayer(),
      NPCLayer(),
      ParticleLayer(),
    ],
  ),
  size: gameSize,
)
```

Or use `CompositeRenderLayer` for simpler cases:

```dart
final gameLayer = CompositeRenderLayer([
  TilemapLayer(),
  NPCLayer(),
  ParticleLayer(),
]);

// In your painter
gameLayer.paint(canvas, size, renderWorld);
```

**Option 3: Layer-encoded sort keys**

Single query with layer information in sort keys:

```dart
import 'package:fledge_render/fledge_render.dart';

// Use the built-in DrawLayer enum with predefined ranges:
// - background:  0 - 99,999
// - ground:      100,000 - 199,999
// - characters:  200,000 - 299,999
// - foreground:  300,000 - 399,999
// - particles:   400,000 - 499,999
// - ui:          500,000+

// Encode layer in sort key using the extension method
class ExtractedSprite with ExtractedData, SortableExtractedData {
  @override
  final int sortKey;
  final DrawLayer layer;

  ExtractedSprite({required this.layer, required double y, ...})
    : sortKey = layer.sortKey(subOrder: (y * 1000).toInt());
}

// Single painter sorts everything by sortKey
class GamePainter extends CustomPainter {
  final RenderWorld renderWorld;

  GamePainter(this.renderWorld);

  @override
  void paint(Canvas canvas, Size size) {
    final all = renderWorld.query1<ExtractedSprite>()
      .iter()
      .toList()
      ..sort((a, b) => a.$2.sortKey.compareTo(b.$2.sortKey));

    for (final (_, sprite) in all) {
      // All sprites rendered in correct layer + Y order
    }
  }
}
```

### Registering Multiple Extractors

Each painter needs its corresponding extractor:

```dart
void _setupGame() {
  _renderWorld = RenderWorld();

  _extractors = Extractors()
    ..register(TilemapExtractor())     // Extracts ExtractedTile
    ..register(NPCExtractor())         // Extracts ExtractedNPC
    ..register(ParticleExtractor());   // Extracts ExtractedParticle

  _world.insertResource(_extractors);
}
```

### Choosing an Approach

| Approach | Best For | Trade-offs |
|----------|----------|------------|
| **Separate painters (Stack)** | Simple games, clear layer separation | Multiple paint calls, harder to intermix layers |
| **RenderLayer pattern** | Most games (Recommended) | Single paint call, explicit layer control, reusable |
| **Layer-encoded sort keys** | Complex scenes with interleaved entities | Single sort, entities can overlap across "layers" |

For most 2D games, the **RenderLayer pattern** offers the best balance of performance and clarity. Use **layer-encoded sort keys** when entities from different categories need to intermix (e.g., NPCs walking behind foreground trees).

### Layer Utilities

`fledge_render_flutter` provides several utility layers for common patterns:

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

## Flutter Integration

`fledge_render_flutter` provides the actual rendering implementation.

### Backend Selection

```dart
import 'package:fledge_render_flutter/fledge_render_flutter.dart';

// Select best available backend
final backend = await BackendSelector.selectBest();

// Force Canvas backend (stable, works everywhere)
final canvas = CanvasBackend();
await canvas.initialize();

// Prefer GPU backend when available (experimental)
final backend = await BackendSelector.selectBest(preferGpu: true);
```

### Creating Textures

```dart
final texture = await backend.createTextureFromData(
  TextureDescriptor(width: 256, height: 256),
  imageData,
);
```

### Rendering

```dart
final frame = backend.beginFrame(size);
frame.drawSpriteBatch(batch);
backend.endFrame(frame);
```

## Render Graph

For advanced use cases, `fledge_render` provides a render graph for organizing complex render pipelines.

### Nodes and Edges

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

The render schedule organizes systems by stage:

| Stage | Purpose |
|-------|---------|
| `RenderStage.extract` | Copy main world → render world |
| `RenderStage.prepare` | Create/update GPU resources |
| `RenderStage.queue` | Collect and sort draw calls |
| `RenderStage.render` | Execute GPU commands |
| `RenderStage.cleanup` | Release temporary resources |

## Materials (Experimental)

Custom materials for shader effects:

```dart
// Standard sprite material
final material = SpriteMaterial(
  texture: myTexture,
  blend: BlendMode.srcOver,
);

// Custom shader material
final shaderMaterial = ShaderMaterial(
  shader: myFragmentShader,
  uniforms: {'time': time.elapsed},
);
```

## Resources Reference

| Resource | Package | Description |
|----------|---------|-------------|
| `RenderWorld` | fledge_render | Separate world for render data |
| `Extractors` | fledge_render | Registry of data extractors |
| `RenderGraph` | fledge_render | DAG-based render pipeline |
| `RenderBackend` | fledge_render_flutter | Platform rendering interface |

## Layers Reference

| Class | Package | Description |
|-------|---------|-------------|
| `RenderLayer` | fledge_render_flutter | Abstract base class for render layers |
| `CompositeRenderLayer` | fledge_render_flutter | Combines multiple layers in order |
| `TransformedRenderLayer` | fledge_render_flutter | Applies a transform matrix before rendering |
| `ClippedRenderLayer` | fledge_render_flutter | Clips rendering to a rectangle |
| `ConditionalRenderLayer` | fledge_render_flutter | Conditionally renders based on a predicate |

## Components Reference

| Component | Package | Description |
|-----------|---------|-------------|
| `Transform2D` | fledge_render_2d | Local position, rotation, scale |
| `GlobalTransform2D` | fledge_render_2d | Computed world-space transform |
| `Sprite` | fledge_render_2d | Textured quad rendering |
| `Camera2D` | fledge_render_2d | 2D orthographic camera |
| `AnimationPlayer` | fledge_render_2d | Frame-based animation |
| `Visibility` | fledge_render_2d | Show/hide entities |

## See Also

- [Two-World Architecture](/docs/guides/two-world-architecture) - Extraction system details
- [Tiled Tilemaps](/docs/plugins/tiled) - Tilemap rendering integration
- [Plugins Overview](/docs/plugins/overview) - Plugin system introduction
