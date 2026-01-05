# fledge_tiled

[Tiled](https://www.mapeditor.org/) tilemap support for [Fledge](https://fledge-framework.dev) games. Load and render TMX/TSX maps with full ECS integration.

[![pub package](https://img.shields.io/pub/v/fledge_tiled.svg)](https://pub.dev/packages/fledge_tiled)

## Features

- **TMX/TSX Parsing**: Load Tiled maps and external tilesets
- **Tile Layers**: Efficient rendering with atlas batching
- **Layer Depth Sorting**: Render characters between tilemap layers using `class="above"`
- **Object Layers**: Spawn entities from Tiled objects
- **Animated Tiles**: Automatic tile animation support
- **Collision Shapes**: Generate collision from objects and tiles
- **Pathfinding**: A* pathfinding with collision grid extraction
- **Custom Properties**: Type-safe access to Tiled properties
- **Infinite Maps**: Chunk-based loading for large maps

## Installation

```yaml
dependencies:
  fledge_tiled: ^0.1.0
```

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_tiled/fledge_tiled.dart';

void main() async {
  final app = App()
    ..addPlugin(TimePlugin())
    ..addPlugin(TiledPlugin());

  // Load a tilemap
  final loader = AssetTilemapLoader(
    loadStringContent: (path) => rootBundle.loadString(path),
  );
  final tilemap = await loader.load(
    'assets/maps/level1.tmx',
    (path, w, h) async => await loadTexture(path),
  );

  // Store and spawn
  app.world.getResource<TilemapAssets>()!.put('level1', tilemap);
  app.world.eventWriter<SpawnTilemapEvent>().send(
    SpawnTilemapEvent(assetKey: 'level1'),
  );

  await app.run();
}
```

## Object Spawning

Spawn game entities from Tiled objects:

```dart
SpawnTilemapEvent(
  assetKey: 'level1',
  config: TilemapSpawnConfig(
    objectTypes: {
      'enemy': ObjectTypeConfig(
        onSpawn: (entity, obj) {
          entity.insert(Enemy(
            health: obj.properties.getIntOr('health', 100),
          ));
        },
      ),
      'collectible': ObjectTypeConfig(
        createCollider: false,
        onSpawn: (entity, obj) {
          entity.insert(Collectible(
            value: obj.properties.getIntOr('value', 10),
          ));
        },
      ),
    },
  ),
)
```

## Custom Properties

Access Tiled properties with type safety:

```dart
// Get property with default
final speed = obj.properties.getDoubleOr('speed', 100.0);
final name = obj.properties.getStringOr('name', 'Unknown');
final enabled = obj.properties.getBoolOr('enabled', true);

// Get required property (throws if missing)
final id = obj.properties.getInt('id');
```

## Collision

Generate collision shapes from Tiled tile layers:

```dart
SpawnTilemapEvent(
  assetKey: 'level1',
  config: TilemapSpawnConfig(
    tileConfig: TileLayerConfig(
      generateColliders: true,
      colliderLayers: {'walls', 'obstacles'},
    ),
  ),
)
```

## Animated Tiles

Animated tiles defined in Tiled are automatically animated:

```dart
// Just add the TiledPlugin and tiles animate automatically
app.addPlugin(TiledPlugin());
```

## Pathfinding

Extract collision grids from tilemaps and find paths using A* pathfinding:

```dart
// Extract collision grid from a loaded tilemap
final grid = extractCollisionGrid(
  tilemap,
  collisionLayers: {'Collision', 'Walls'},
);

// Or directly from TMX content (useful for preloading)
final tmxContent = await rootBundle.loadString('assets/maps/level.tmx');
final grid = extractCollisionGridFromTmx(
  tmxContent,
  mapWidth: 100,
  mapHeight: 100,
  collisionLayers: {'Collision'},
);

// Find a path
final pathfinder = Pathfinder(allowDiagonal: true);
final result = pathfinder.findPath(grid, startX, startY, goalX, goalY);

if (result.success) {
  for (final (x, y) in result.path!) {
    print('Move to ($x, $y)');
  }
}
```

See the [Tilemap Guide](https://fledge-framework.dev/docs/plugins/tiled) for detailed pathfinding documentation.

## Layer Depth Sorting

For top-down games where characters should appear between tilemap layers (e.g., behind roofs but in front of floors), use Tiled's layer `class` attribute:

1. In Tiled, set `class="above"` on layers that should render in front of characters
2. The `TilemapExtractor` automatically assigns these layers to `DrawLayer.foreground`
3. Normal layers are assigned to `DrawLayer.ground`

```
TMX Layer Setup:
├── Layer 0 (ground)      → DrawLayer.ground    (behind characters)
├── Layer 1 (objects)     → DrawLayer.ground    (behind characters)
├── Layer 2 class="above" → DrawLayer.foreground (in front of characters)
└── Layer 3 class="above" → DrawLayer.foreground (in front of characters)
```

Access the layer class in code:

```dart
for (final (_, layer) in world.query1<TileLayer>().iter()) {
  print('${layer.name}: class=${layer.layerClass}');
  // Output: "Layer 2: class=above"
}
```

See the [Tilemap Guide](https://fledge-framework.dev/docs/plugins/tiled) for render pipeline integration.

## Documentation

See the [Tilemap Guide](https://fledge-framework.dev/docs/guides/tilemaps) for detailed documentation.

## Related Packages

- [fledge_ecs](https://pub.dev/packages/fledge_ecs) - Core ECS framework
- [fledge_render](https://pub.dev/packages/fledge_render) - Render infrastructure
- [fledge_render_2d](https://pub.dev/packages/fledge_render_2d) - 2D rendering components

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
