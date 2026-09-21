# fledge_assets

Ref-counted asset management for the [Fledge](https://fledge-framework.dev) ECS game framework.

[![pub package](https://img.shields.io/pub/v/fledge_assets.svg)](https://pub.dev/packages/fledge_assets)

## Installation

```yaml
dependencies:
  fledge_assets: ^0.2.0
```

## Quick Start

```dart
import 'package:fledge_assets/fledge_assets.dart';

// Register an asset you already have in memory.
final assets = Assets<Texture>();
final handle = assets.add(myTexture);

// Or load one via a loader implementation.
final handle2 = assets.load('assets/sprites/player.png', FileTextureLoader());

// Share and release.
final shared = handle.clone();
handle.drop();
// Entry still alive — `shared` holds a reference.
shared.drop();
// Entry dropped, memory freed.
```

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs/plugins/assets) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
