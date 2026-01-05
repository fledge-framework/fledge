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

## Pathfinding

The `fledge_tiled` package includes a complete pathfinding solution built on collision data from Tiled tilemaps. This enables NPCs, enemies, and other entities to navigate around obstacles.

### CollisionGrid

A `CollisionGrid` represents walkability data for a tilemap as a 2D grid of boolean values:

```dart
// Create an empty grid (all tiles walkable)
final grid = CollisionGrid(width: 100, height: 100);

// Query walkability
if (grid.isWalkable(10, 20)) {
  print('Tile (10, 20) is walkable');
}

// Mark tiles as blocked
grid.setBlocked(10, 20);

// Mark tiles as walkable
grid.setWalkable(10, 20);

// Check bounds
if (grid.isInBounds(x, y)) {
  // Safe to query this tile
}
```

### Extracting Collision Data

Extract collision grids from Tiled tilemaps using two approaches:

#### From a Loaded Tilemap

Use `extractCollisionGrid()` when you have a fully loaded tilemap:

```dart
// Load the tilemap
final loader = AssetTilemapLoader(
  loadStringContent: (path) => rootBundle.loadString(path),
);
final tilemap = await loader.load('assets/maps/level.tmx', textureLoader);

// Extract collision grid
final grid = extractCollisionGrid(
  tilemap,
  collisionLayers: {'Collision', 'Walls'}, // Layer names containing collision tiles
);

// Use for pathfinding
final pathfinder = Pathfinder();
final result = pathfinder.findPath(grid, 0, 0, 10, 10);
```

The extractor examines tile layers matching the specified names. Any non-zero tile GID in those layers marks that cell as blocked.

#### From TMX Content (Lightweight)

Use `extractCollisionGridFromTmx()` when you only need collision data without loading textures. This is useful for preloading pathfinding data at game start:

```dart
// Load raw TMX content
final tmxContent = await rootBundle.loadString('assets/maps/level.tmx');

// Extract collision grid without loading textures
final grid = extractCollisionGridFromTmx(
  tmxContent,
  mapWidth: 100,   // Map dimensions in tiles
  mapHeight: 100,
  collisionLayers: {'Collision'},
);
```

This approach is much faster than fully loading tilemaps and is ideal for:
- Preloading collision data for all maps at game start
- NPC pathfinding in maps the player hasn't visited yet
- Memory-efficient collision storage

#### Batch Extraction

Extract collision data from multiple tilemaps at once:

```dart
final grids = extractCollisionGrids({
  'level1': level1Tilemap,
  'level2': level2Tilemap,
  'dungeon': dungeonTilemap,
});

final level1Grid = grids['level1']!;
```

### Pathfinder

The `Pathfinder` class implements A* pathfinding with configurable options:

```dart
// Create with default options
final pathfinder = Pathfinder();

// Or configure behavior
final pathfinder = Pathfinder(
  maxIterations: 10000,      // Prevent infinite loops on large maps
  allowDiagonal: true,       // Allow 8-directional movement
  allowCornerCutting: false, // Don't cut through diagonal obstacles
);
```

#### Finding Paths

```dart
final result = pathfinder.findPath(
  grid,
  startX, startY,  // Starting tile coordinates
  goalX, goalY,    // Destination tile coordinates
);

if (result.success) {
  // Path found - result.path is List<(int, int)>
  for (final (x, y) in result.path!) {
    print('Move to tile ($x, $y)');
  }
} else {
  // Path not found
  print('Failed: ${result.failureReason}');
  // Possible reasons:
  // - "Start position is blocked"
  // - "Goal position is blocked"
  // - "No path found"
  // - "Max iterations exceeded"
}
```

#### PathResult

The `PathResult` class contains:

| Property | Type | Description |
|----------|------|-------------|
| `path` | `List<(int, int)>?` | List of tile coordinates from start to goal, or null if no path |
| `success` | `bool` | Whether a valid path was found |
| `failureReason` | `String?` | Human-readable reason if path finding failed |

#### Pathfinder Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `maxIterations` | `int` | `10000` | Maximum A* iterations before giving up |
| `allowDiagonal` | `bool` | `false` | Allow 8-directional movement instead of 4 |
| `allowCornerCutting` | `bool` | `false` | Allow diagonal moves through corners (requires `allowDiagonal`) |

### Use Cases

#### NPC Schedule Movement

Pre-calculate paths for NPCs following schedules:

```dart
class NpcWorldManager {
  final Map<NpcId, CollisionGrid> _mapGrids = {};
  final Pathfinder _pathfinder = Pathfinder(allowDiagonal: true);

  void setNpcPath(NpcId id, int targetX, int targetY) {
    final state = getState(id);
    final grid = _mapGrids[state.currentMap];
    if (grid == null) return;

    final (currentX, currentY) = state.currentTile;
    final result = _pathfinder.findPath(
      grid,
      currentX, currentY,
      targetX, targetY,
    );

    if (result.success) {
      state.setPath(result.path!);
    }
  }
}
```

#### Preloading All Map Collision Data

Load collision data for all maps at game start for seamless pathfinding:

```dart
class WorldCollisionData {
  final Map<MapId, CollisionGrid> _grids = {};

  Future<void> loadAll() async {
    for (final mapDef in allMaps.values) {
      final tmxContent = await rootBundle.loadString(
        'assets/${mapDef.assetPath}',
      );

      _grids[mapDef.id] = extractCollisionGridFromTmx(
        tmxContent,
        mapWidth: mapDef.widthInTiles,
        mapHeight: mapDef.heightInTiles,
        collisionLayers: mapDef.collisionLayers,
      );
    }
  }

  CollisionGrid? getGrid(MapId id) => _grids[id];
}
```

#### Enemy AI

Use pathfinding for enemy movement toward the player:

```dart
@system
void enemyPathfindingSystem(World world) {
  final grid = world.getResource<CurrentMapCollision>()?.grid;
  if (grid == null) return;

  final pathfinder = Pathfinder(allowDiagonal: true);

  // Get player position
  final playerTile = getPlayerTile(world);

  for (final (_, enemy, transform) in world.query2<Enemy, Transform2D>().iter()) {
    final enemyTile = worldToTile(transform.translation);

    final result = pathfinder.findPath(
      grid,
      enemyTile.x, enemyTile.y,
      playerTile.x, playerTile.y,
    );

    if (result.success && result.path!.length > 1) {
      // Move toward next tile in path
      final (nextX, nextY) = result.path![1];
      enemy.targetTile = (nextX, nextY);
    }
  }
}
```

### Layer Depth Sorting

For top-down games where characters should appear between tilemap layers (e.g., behind roofs but in front of floors), use Tiled's layer `class` attribute combined with Fledge's `DrawLayer` system.

#### Setting Up Layers in Tiled

In Tiled 1.9+, you can assign a "Class" to any layer:

1. Select a layer in the Layers panel
2. In the Properties panel, set the `Class` field to `above`
3. Layers with `class="above"` will render in front of characters
4. Layers without the class render behind characters

```
TMX Layer Structure:
├── Collision (hidden)    → Not rendered
├── Layer 0 (floor)       → DrawLayer.ground    (sortKey: 100,000+)
├── Layer 1 (furniture)   → DrawLayer.ground    (sortKey: 100,000+)
├── Layer 2 class="above" → DrawLayer.foreground (sortKey: 300,000+)
└── Layer 3 class="above" → DrawLayer.foreground (sortKey: 300,000+)

Character sprites use DrawLayer.characters (sortKey: 200,000+)
```

#### How It Works

The `TilemapExtractor` checks each layer's `layerClass` property:

```dart
// In TilemapExtractor._extractLayer():
final drawLayer = (layer.layerClass == 'above')
    ? DrawLayer.foreground
    : DrawLayer.ground;
final sortKey = drawLayer.sortKey(subOrder: tile.y * 100 + layer.layerIndex);
```

This places tiles into the correct `DrawLayer` range:

| DrawLayer | Sort Key Range | Purpose |
|-----------|---------------|---------|
| `ground` | 100,000 - 199,999 | Tile layers without `class="above"` |
| `characters` | 200,000 - 299,999 | Player, NPCs, enemies |
| `foreground` | 300,000 - 399,999 | Tile layers with `class="above"` |

#### Rendering Pipeline Integration

To render tiles correctly with characters, your render pipeline needs to handle the sortKey ranges:

```dart
// Example: Split tilemap rendering into ground and foreground passes
layers = [
  // Ground tiles (below characters)
  TilemapLayer(
    textureManager: textureManager,
    maxSortKey: DrawLayer.characters.sortKey(),
  ),
  // Characters (sorted by Y position within their range)
  CharacterLayer(textureManager: textureManager),
  // Foreground tiles (above characters)
  TilemapLayer(
    textureManager: textureManager,
    minSortKey: DrawLayer.foreground.sortKey(),
  ),
];
```

#### Accessing Layer Class

Query the layer class at runtime:

```dart
for (final (_, layer) in world.query1<TileLayer>().iter()) {
  if (layer.layerClass == 'above') {
    print('${layer.name} renders above characters');
  } else {
    print('${layer.name} renders below characters');
  }
}
```

#### Character Sort Key

Ensure your character extraction uses `DrawLayer.characters`:

```dart
class ExtractedCharacter with ExtractedData, SortableExtractedData {
  @override
  final int sortKey;

  ExtractedCharacter(Transform2D transform)
      : sortKey = DrawLayer.characters.sortKey(
          subOrder: (transform.translation.y * 100).toInt(),
        );
}
```

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
| `layerClass` | `String?` | Layer class from Tiled (e.g., `"above"` for foreground layers) |
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

  // Sort key for depth ordering
  // Uses DrawLayer.ground (100,000+) or DrawLayer.foreground (300,000+)
  // based on layer.layerClass == 'above'
  final sortKey = tile.sortKey;
}
```

The sort key is computed using `DrawLayer` ranges, enabling proper depth sorting with characters:

- Layers without `class="above"` → `DrawLayer.ground` (100,000 - 199,999)
- Character sprites → `DrawLayer.characters` (200,000 - 299,999)
- Layers with `class="above"` → `DrawLayer.foreground` (300,000 - 399,999)

See [Layer Depth Sorting](#layer-depth-sorting) for details on setting this up in Tiled.

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
- [Pixel-Perfect Rendering](/docs/guides/pixel-perfect-rendering) - Preventing tile seams
