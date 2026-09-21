# fledge_tiled

[Tiled](https://www.mapeditor.org/) tilemap support for [Fledge](https://fledge-framework.dev) games. Load and render TMX/TSX maps with full ECS integration.

[![pub package](https://img.shields.io/pub/v/fledge_tiled.svg)](https://pub.dev/packages/fledge_tiled)

## Installation

```yaml
dependencies:
  fledge_tiled: ^0.2.1
```

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_tiled/fledge_tiled.dart';
import 'package:flutter/services.dart';

void main() async {
  final app = App()
    ..addPlugin(WallTimePlugin())
    ..addPlugin(TiledPlugin());

  final loader = AssetTilemapLoader(
    loadStringContent: (path) => rootBundle.loadString(path),
  );
  final tilemap = await loader.load(
    'assets/maps/level1.tmx',
    (path, w, h) async => await loadTexture(path),
  );

  app.world.getResource<TilemapAssets>()!.put('level1', tilemap);
  app.world.eventWriter<SpawnTilemapEvent>().send(
    SpawnTilemapEvent(assetKey: 'level1'),
  );

  await app.run();
}
```

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs/plugins/tiled) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
