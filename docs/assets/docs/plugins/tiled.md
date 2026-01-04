# Tiled Tilemaps

The `fledge_tiled` plugin provides full integration with [Tiled](https://www.mapeditor.org/), the popular 2D tilemap editor. Load TMX/TSX maps and render them efficiently using Fledge's ECS architecture.

## Installation

Add `fledge_tiled` to your `pubspec.yaml`:

```yaml
dependencies:
  fledge_tiled: ^0.1.0
```

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_tiled/fledge_tiled.dart';
import 'package:flutter/services.dart';

void main() async {
  final app = App()
    .addPlugin(TimePlugin())
    .addPlugin(TiledPlugin());

  // Load the tilemap
  final loader = AssetTilemapLoader(
    loadStringContent: (path) => rootBundle.loadString(path),
  );

  final tilemap = await loader.load(
    'assets/maps/level1.tmx',
    (path, width, height) async {
      // Your texture loading logic here
      return await loadTexture(path);
    },
  );

  // Store and spawn
  app.world.getResource<TilemapAssets>()!.put('level1', tilemap);

  app.world.eventWriter<SpawnTilemapEvent>().send(
    SpawnTilemapEvent(assetKey: 'level1'),
  );

  await app.run();
}
```

## Features

### Tile Layers

Tile layers are automatically converted to ECS entities with pre-computed tile data for efficient rendering.

```dart
// Query tile layers
for (final (entity, layer) in world.query1<TileLayer>().iter()) {
  print('Layer: ${layer.name}');
  print('Tiles: ${layer.tiles?.length ?? 0}');
  print('Visible: ${layer.visible}');
}
```

Each tile includes:
- Grid position (x, y)
- Tileset reference
- Flip flags (horizontal, vertical, diagonal)
- Animation flag

### Object Layers

Object layers contain shapes that can be used for spawning entities, collision zones, triggers, and more.

```dart
// Query object layers
for (final (entity, layer) in world.query1<ObjectLayer>().iter()) {
  for (final obj in layer.objects) {
    print('Object: ${obj.name} (${obj.type})');
    print('Position: ${obj.x}, ${obj.y}');
    print('Shape: ${obj.shape}');
  }
}

// Find objects by type
final spawnPoints = layer.findByType('spawn_point');
final triggers = layer.findByType('trigger');
```

### Spawning Object Entities

Configure automatic entity spawning from Tiled objects:

```dart
SpawnTilemapEvent(
  assetKey: 'level1',
  config: TilemapSpawnConfig(
    tileConfig: TileLayerConfig(
      generateColliders: true,
      colliderLayers: {'Collision'},
    ),
    objectTypes: {
      'enemy': ObjectTypeConfig(
        createCollider: false,
        onSpawn: (entity, obj) {
          entity.insert(Enemy(
            health: obj.properties.getIntOr('health', 100),
            speed: obj.properties.getDoubleOr('speed', 50.0),
          ));
        },
      ),
      'collectible': ObjectTypeConfig(
        createCollider: true,
        onSpawn: (entity, obj) {
          entity.insert(Collectible(
            itemType: obj.properties.getStringOr('item_type', 'coin'),
            value: obj.properties.getIntOr('value', 10),
          ));
        },
      ),
      'trigger': ObjectTypeConfig(
        createCollider: true,
        onSpawn: (entity, obj) {
          entity.insert(TriggerZone(
            targetScene: obj.properties.getString('target_scene'),
            oneShot: obj.properties.getBoolOr('one_shot', true),
          ));
        },
      ),
    },
  ),
)
```

### Custom Properties

Access Tiled custom properties with type-safe methods:

```dart
final props = obj.properties;

// String properties
final name = props.getString('name');
final nameOrDefault = props.getStringOr('name', 'Unknown');

// Numeric properties
final health = props.getInt('health');
final speed = props.getDouble('speed');

// Boolean properties
final isBoss = props.getBool('is_boss');
final enabled = props.getBoolOr('enabled', true);

// Color properties (Tiled #AARRGGBB format)
final tint = props.getColor('tint_color');

// Object references
final targetId = props.getObjectRef('target');

// Check existence
if (props.has('special_ability')) {
  // Handle special ability
}
```

### Animated Tiles

Tiles with animations defined in Tiled are automatically animated:

```dart
// The TilemapAnimator component tracks all animations
final animator = world.get<TilemapAnimator>(mapEntity);
if (animator != null) {
  print('Animated tiles: ${animator.animations.length}');

  // Get current frame for a tile
  final currentFrame = animator.getCurrentFrame(tileLocalId);
}
```

Animation updates are handled automatically by `TileAnimationSystem`.

### Collision Shapes

fledge_tiled supports two sources of collision data:

1. **Object layer collisions** - Shapes drawn directly as objects in Tiled
2. **Tileset tile collisions** - Collision shapes defined per-tile in the tileset editor

Both types can be generated automatically via `TilemapSpawnConfig`.

#### Object Layer Collisions

Collision shapes from object layers are automatically created when spawning object entities with `createColliders: true` (the default):

```dart
SpawnTilemapEvent(
  assetKey: 'level1',
  config: TilemapSpawnConfig(
    objectTypes: {
      'trigger': ObjectTypeConfig(
        createCollider: true,
      ),
    },
  ),
)
```

Query the generated colliders:

```dart
for (final (entity, collider) in world.query1<Collider>().iter()) {
  for (final shape in collider.shapes) {
    if (shape is RectangleShape) {
      print('Rectangle: ${shape.x}, ${shape.y}, ${shape.width}x${shape.height}');
    } else if (shape is PolygonShape) {
      print('Polygon with ${shape.vertexCount} vertices');
    }
  }
}
```

#### Tile Collision Generation

In Tiled, you can define collision shapes directly on tiles in the tileset editor (Tileset → Select Tile → Collision Editor). Enable automatic tile collider generation with `TileLayerConfig`:

```dart
SpawnTilemapEvent(
  assetKey: 'level1',
  config: TilemapSpawnConfig(
    tileConfig: TileLayerConfig(
      generateColliders: true, // Enable collider generation
    ),
  ),
)
```

This automatically:
1. Scans all tiles in each tile layer for collision shapes defined in their tileset
2. Converts shapes to world-space coordinates
3. Merges adjacent rectangles into larger shapes (reduces collision checks)
4. Spawns a `Collider` entity as a child of each layer

**Filter specific layers:**

```dart
TilemapSpawnConfig(
  tileConfig: TileLayerConfig(
    generateColliders: true,
    colliderLayers: {'collision', 'walls'}, // Only these layers
  ),
)
```

**Custom collider setup:**

```dart
TilemapSpawnConfig(
  tileConfig: TileLayerConfig(
    generateColliders: true,
    onColliderSpawn: (entity, layerName, collider) {
      // Add custom components to the collider entity
      if (layerName == 'hazards') {
        entity.insert(DamageZone(damage: 10));
      } else if (layerName == 'walls') {
        entity.insert(StaticBody());
      }
    },
  ),
)
```

#### TilemapSpawnConfig Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `tileConfig` | `TileLayerConfig` | `TileLayerConfig()` | Configuration for tile layer colliders |
| `objectTypes` | `Map<String, ObjectTypeConfig>?` | `null` | Object spawning configuration by type |
| `onLayerSpawn` | `Function?` | `null` | Callback for custom layer entity setup |

#### TileLayerConfig Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `generateColliders` | `bool` | `false` | Generate colliders from tile collision data |
| `colliderLayers` | `Set<String>?` | `null` | Layer names to generate colliders for (null = all) |
| `onColliderSpawn` | `Function?` | `null` | Callback for custom tile collider entity setup |

#### ObjectTypeConfig Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `createCollider` | `bool` | `true` | Create collision shapes from the object's geometry |
| `onSpawn` | `Function?` | `null` | Callback for custom setup when this object type is spawned |

#### Manual Collision Generation

For advanced use cases, you can generate collisions manually using the `TileCollider` utility:

```dart
// Get the loaded tilemap
final assets = world.getResource<TilemapAssets>()!;
final loaded = assets.get('level')!;

// Access collision shapes for a specific tile
final tileset = loaded.tilesets[0];
final shapes = tileset.getCollisionShapes(localTileId);

// Convert to world coordinates
final worldShapes = TileCollider.fromTileCollision(
  tileset,
  tile.localId,
  tile.x * loaded.tileWidth.toDouble(),
  tile.y * loaded.tileHeight.toDouble(),
);

// Or generate for an entire layer
final allShapes = TileCollider.fromTileLayer(
  tiles: collisionTiles,
  tileWidth: loaded.tileWidth.toDouble(),
  tileHeight: loaded.tileHeight.toDouble(),
);

// Optimize by merging adjacent rectangles
final rectangles = allShapes.whereType<RectangleShape>().toList();
final merged = TileCollider.mergeRectangles(rectangles);
```

#### Supported Collision Shapes

Both object and tileset collisions support:

- `RectangleShape` - Rectangles with rotation
- `EllipseShape` - Ellipses and circles
- `PolygonShape` - Closed polygons
- `PolylineShape` - Open polylines
- `PointShape` - Single points

### Layer Visibility

Toggle layer visibility at runtime:

```dart
for (final (entity, tilemap) in world.query1<Tilemap>().iter()) {
  // Hide a layer
  tilemap.setLayerVisible('secrets', false);

  // Show a layer
  tilemap.setLayerVisible('foreground', true);

  // Check visibility
  final visible = tilemap.isLayerVisible('background', true);

  // Clear override (use layer's default)
  tilemap.clearLayerVisibility('secrets');
}
```

## Entity Hierarchy

Tilemaps create a parent-child entity hierarchy:

```
Tilemap Entity (root)
├── TileLayer Entity (child)
│   └── Collider Entity (grandchild, if tileConfig.generateColliders enabled)
├── TileLayer Entity (child)
├── ObjectLayer Entity (child)
│   ├── Object Entity (grandchild, with Collider if ObjectTypeConfig.createCollider enabled)
│   ├── Object Entity (grandchild)
│   └── Object Entity (grandchild)
└── TileLayer Entity (child)
```

Use hierarchy queries to traverse:

```dart
// Get all layers for a tilemap
for (final layerEntity in world.getChildren(mapEntity)) {
  final tileLayer = world.get<TileLayer>(layerEntity);
  final objectLayer = world.get<ObjectLayer>(layerEntity);
  // ...
}

// Despawn entire tilemap
world.despawnRecursive(mapEntity);
```

## Components Reference

### Tilemap

Root component for a loaded map:

| Property | Type | Description |
|----------|------|-------------|
| `map` | `TiledMap` | Parsed Tiled map data |
| `bounds` | `Rect` | World-space bounds |
| `tileWidth` | `int` | Tile width in pixels |
| `tileHeight` | `int` | Tile height in pixels |
| `width` | `int` | Map width in tiles |
| `height` | `int` | Map height in tiles |
| `infinite` | `bool` | Whether this is an infinite map |
| `layerVisibility` | `Map<String, bool>` | Layer visibility overrides |

### TileLayer

Component for tile layers:

| Property | Type | Description |
|----------|------|-------------|
| `name` | `String` | Layer name from Tiled |
| `layerIndex` | `int` | Rendering order |
| `opacity` | `double` | Layer opacity (0.0-1.0) |
| `visible` | `bool` | Visibility flag |
| `offset` | `Offset` | Pixel offset |
| `parallax` | `Offset` | Parallax factor |
| `tintColor` | `Color` | Tint color |
| `tiles` | `List<TileData>?` | Pre-computed tile data |

### ObjectLayer

Component for object layers:

| Property | Type | Description |
|----------|------|-------------|
| `name` | `String` | Layer name |
| `layerIndex` | `int` | Rendering order |
| `objects` | `List<TiledObjectData>` | Objects in this layer |
| `drawOrder` | `DrawOrder` | topDown or index |

### TiledObject

Component attached to spawned object entities:

| Property | Type | Description |
|----------|------|-------------|
| `id` | `int` | Unique object ID |
| `name` | `String?` | Object name |
| `type` | `String?` | Object type/class |
| `properties` | `TiledProperties` | Custom properties |

## Resources

### TilemapAssets

Stores loaded tilemaps:

```dart
final assets = world.getResource<TilemapAssets>()!;

// Store a loaded tilemap
assets.put('level1', loadedTilemap);

// Retrieve a tilemap
final tilemap = assets.get('level1');

// Check if loaded
if (assets.contains('level1')) {
  // ...
}

// Remove a tilemap
assets.remove('level1');
```

### TilesetRegistry

Caches shared tilesets:

```dart
final registry = world.getResource<TilesetRegistry>()!;

// Check if tileset is already loaded
if (!registry.isLoaded('tilesets/terrain.tsx')) {
  // Load and register
  registry.register('tilesets/terrain.tsx', loadedTileset);
}

// Get a registered tileset
final tileset = registry.get('tilesets/terrain.tsx');
```

## Plugin Configuration

Customize plugin behavior:

```dart
TiledPlugin(TiledPluginConfig(
  respectLayerVisibility: true,  // Skip invisible layers during extraction
  chunkSize: 16,                  // Chunk size for infinite maps
  maxLoadedChunks: 64,            // Max chunks in memory
))
```

## Rendering Tiles

The rendering pipeline is independent from the ECS structure. To render tiles, you need to map tile data back to texture regions in the original spritesheet/atlas.

### Texture Loading Integration

The `TextureLoader` callback bridges your renderer's texture system with fledge_tiled:

```dart
// TextureLoader signature:
// Future<TextureHandle> Function(String path, int width, int height)

// Create a texture handle that maps to your renderer's texture system
Future<TextureHandle> myTextureLoader(String path, int width, int height) async {
  // Load the image using your renderer (Flutter, Canvas, GPU, etc.)
  final image = await loadImage(path);

  // Assign a unique ID that your renderer can look up later
  final textureId = myRenderer.registerTexture(image);

  return TextureHandle(id: textureId, width: width, height: height);
}

final tilemap = await loader.load('maps/level.tmx', myTextureLoader);
```

The `TextureHandle.id` you assign during loading is how you'll map back to your renderer's internal texture representation.

### Accessing Tile Texture Data

After spawning a tilemap, access texture information through the loaded tileset:

```dart
// Get the loaded tilemap
final assets = world.getResource<TilemapAssets>()!;
final loaded = assets.get('level')!;

// Query tile layers
for (final (_, layer) in world.query1<TileLayer>().iter()) {
  for (final tile in layer.tiles ?? []) {
    if (tile.gid == 0) continue; // Empty tile

    // Get tileset for this tile
    final tileset = loaded.tilesets[tile.tilesetIndex];

    // Get texture handle (maps to your renderer's texture)
    final TextureHandle texture = tileset.atlas.texture;

    // Get source rectangle in the spritesheet (pixel coordinates)
    final Rect sourceRect = tileset.getTileRect(tile.localId);
    // sourceRect contains: left, top, width, height (e.g., 0, 32, 16, 16)

    // Handle flip transformations
    final flipH = tile.flipHorizontal;
    final flipV = tile.flipVertical;
    final flipD = tile.flipDiagonal; // 90° rotation

    // Compute world position
    final worldX = tile.x * tileset.tileWidth;
    final worldY = tile.y * tileset.tileHeight;

    // Render using your renderer:
    myRenderer.drawSprite(
      textureId: texture.id,
      srcRect: sourceRect,
      dstX: worldX,
      dstY: worldY,
      flipX: flipH,
      flipY: flipV,
      rotate90: flipD,
    );
  }
}
```

### Rendering Animated Tiles

For tiles with animations, get the current frame from `TilemapAnimator`:

```dart
// Get animator from tilemap entity
final animator = world.get<TilemapAnimator>(tilemapEntity);

for (final tile in layer.tiles ?? []) {
  final tileset = loaded.tilesets[tile.tilesetIndex];

  // Get display ID (animated tiles resolve to current frame)
  int displayId = tile.localId;
  if (tile.animated && animator != null) {
    displayId = animator.getCurrentFrame(tile.localId);
  }

  // Get source rect for the current animation frame
  final sourceRect = tileset.getTileRect(displayId);
  // ... render with sourceRect
}
```

### Two-World Extraction

For render pipelines using the [two-world architecture](/docs/guides/two-world-architecture), `TilemapExtractor` creates `ExtractedTile` entities in the render world each frame with pre-resolved texture data:

```dart
// In render world systems, query extracted tiles
for (final (_, tile) in renderWorld.query1<ExtractedTile>().iter()) {
  // Pre-resolved texture and source rect
  final textureId = tile.texture.id;
  final srcRect = tile.sourceRect;

  // World position and size
  final position = tile.position;
  final width = tile.tileWidth;
  final height = tile.tileHeight;

  // Color (with layer opacity/tint applied)
  final color = tile.color;

  // Flip flags (bit 0: H, bit 1: V, bit 2: diagonal)
  final flipH = tile.flipHorizontal;
  final flipV = tile.flipVertical;
  final flipD = tile.flipDiagonal;

  // Sort key for depth ordering (uses DrawLayerExtension.sortKeyFromIndex)
  final sortKey = tile.sortKey;
}
```

### Data Flow Overview

```
TMX/TSX File
    ↓ [AssetTilemapLoader + TextureLoader callback]
LoadedTilemap
├── tilesets: List<LoadedTileset>
│   └── atlas: TextureAtlas
│       ├── texture: TextureHandle (your renderer's texture ID)
│       └── layout: GridAtlasLayout (computes source rects)
└── animations: Map<int, TileAnimation>

    ↓ [TilemapSpawnSystem]

Game World Entities
├── Tilemap (root entity)
├── TileLayer (child entities)
│   └── tiles: List<TileData>
│       ├── localId → tileset.getTileRect(localId) → Rect
│       ├── tilesetIndex → tileset.atlas.texture → TextureHandle
│       └── flipFlags → transformation
└── TilemapAnimator (animation state)

    ↓ [TilemapExtractor - each frame]

Render World Entities
└── ExtractedTile
    ├── texture: TextureHandle
    ├── sourceRect: Rect (already computed)
    ├── position: Offset (world space)
    └── flipFlags, color, sortKey
```

### UV Coordinate Conversion

If your renderer uses normalized UV coordinates (0.0-1.0) instead of pixel coordinates, convert from the pixel rect:

```dart
final srcRect = tileset.getTileRect(localId);
final texWidth = tileset.atlas.texture.width;
final texHeight = tileset.atlas.texture.height;

// Normalize to 0.0-1.0 range
final u0 = srcRect.left / texWidth;
final v0 = srcRect.top / texHeight;
final u1 = srcRect.right / texWidth;
final v1 = srcRect.bottom / texHeight;
```

## See Also

- [Plugins Overview](/docs/plugins/overview) - Plugin system introduction
- [Hierarchies Guide](/docs/guides/hierarchies) - Entity parent-child relationships
- [Two-World Architecture](/docs/guides/two-world-architecture) - Render extraction and the render pipeline
