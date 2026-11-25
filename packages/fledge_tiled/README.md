# fledge_tiled

[Tiled](https://www.mapeditor.org/) tilemap support for [Fledge](https://fledge-framework.dev) games. Load TMX/TSX maps, spawn them as entities, and draw them through the shared sprite pipeline.

[![pub package](https://img.shields.io/pub/v/fledge_tiled.svg)](https://pub.dev/packages/fledge_tiled)

## Installation

```yaml
dependencies:
  fledge_tiled: ^0.6.0
```

Requires Flutter 3.50+ (Dart 3.14+). Desktop (Windows, macOS, Linux) is the supported target; web and mobile are best-effort. Orthogonal maps only; infinite maps spawn, draw and build collision grids from their chunks (all loaded at once).

## Quick Start

Add `RenderPlugin` before `TiledPlugin` (the tile extractor is only registered when `Extractors` already exists), and run `TransformPropagateSystem`.

```dart
import 'package:fledge_assets/fledge_assets.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_tiled/fledge_tiled.dart';
import 'package:flutter/services.dart' show rootBundle;

Future<TextureHandle> loadTexture(App app, String asset) async {
  final data = await rootBundle.load(asset);
  final texture = await decodeTextureBytes(data.buffer.asUint8List());
  final handle = app.world.getResource<Assets<Texture>>()!.add(texture);
  return TextureHandle(
    id: handle.id.id,
    width: texture.width,
    height: texture.height,
  );
}

Future<App> buildGame() async {
  final app = App()
    ..addPlugin(WallTimePlugin()) // animated tiles
    ..addPlugin(RenderPlugin()) // before TiledPlugin
    ..addPlugin(TiledPlugin())
    ..addSystem(TransformPropagateSystem(), schedule: Schedules.preUpdate);

  final loader = TmxLoader(
    tilemapLoader: AssetTilemapLoader(loadStringContent: rootBundle.loadString),
    textureLoader: (path, width, height) => loadTexture(app, path),
  );
  final map = await loader.load('assets/maps/level1.tmx');
  final level = app.world.getResource<Assets<TilemapAsset>>()!.add(map);

  app.world.eventWriter<SpawnTilemapEvent>().send(
    SpawnTilemapEvent.fromHandle(level),
  );
  return app;
}
```

`TilemapAssets.put` + `SpawnTilemapEvent(assetKey:)` and `TilesetRegistry` are deprecated; use `Assets<TilemapAsset>` and handles.

## Documentation

- [Tiled Maps](https://fledge-framework.dev/docs/gameplay/tiled): loading, spawning, objects, properties, collision
- [Rendering Tilemaps](https://fledge-framework.dev/docs/gameplay/tiled-rendering): draw order, y-sorted tiles, culling
- [API reference](https://pub.dev/documentation/fledge_tiled/latest/)

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
