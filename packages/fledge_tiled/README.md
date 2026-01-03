# fledge_tiled

[Tiled](https://www.mapeditor.org/) tilemap support for [Fledge](https://fledge-framework.dev) games. Load and render TMX/TSX maps with full ECS integration.

[![pub package](https://img.shields.io/pub/v/fledge_tiled.svg)](https://pub.dev/packages/fledge_tiled)

## Features

- **TMX/TSX Parsing**: Load Tiled maps and external tilesets
- **Tile Layers**: Efficient rendering with atlas batching
- **Object Layers**: Spawn entities from Tiled objects
- **Animated Tiles**: Automatic tile animation support
- **Collision Shapes**: Generate collision from objects and tiles
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
    spawnObjectEntities: true,
    entityObjectTypes: {'enemy', 'collectible'},
    onObjectSpawn: (entity, obj) {
      switch (obj.type) {
        case 'enemy':
          entity.insert(Enemy(
            health: obj.properties.getIntOr('health', 100),
          ));
        case 'collectible':
          entity.insert(Collectible(
            value: obj.properties.getIntOr('value', 10),
          ));
      }
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

Generate collision shapes from Tiled:

```dart
SpawnTilemapEvent(
  assetKey: 'level1',
  config: TilemapSpawnConfig(
    generateCollision: true,
    collisionLayers: {'walls', 'obstacles'},
  ),
)
```

## Animated Tiles

Animated tiles defined in Tiled are automatically animated:

```dart
// Just add the TiledPlugin and tiles animate automatically
app.addPlugin(TiledPlugin());
```

## Documentation

See the [Tilemap Guide](https://fledge-framework.dev/docs/guides/tilemaps) for detailed documentation.

## Related Packages

- [fledge_ecs](https://pub.dev/packages/fledge_ecs) - Core ECS framework
- [fledge_render](https://pub.dev/packages/fledge_render) - Render infrastructure
- [fledge_render_2d](https://pub.dev/packages/fledge_render_2d) - 2D rendering components

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
