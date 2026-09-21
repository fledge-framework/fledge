# fledge_audio

Full-featured audio plugin for [Fledge](https://fledge-framework.dev) games — background music, sound effects, and 2D spatial audio.

[![pub package](https://img.shields.io/pub/v/fledge_audio.svg)](https://pub.dev/packages/fledge_audio)

## Installation

```yaml
dependencies:
  fledge_audio: ^0.2.0
```

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_audio/fledge_audio.dart';

void main() async {
  final app = App()
    ..addPlugin(WallTimePlugin())
    ..addPlugin(AudioPlugin());

  await app.tick(); // initialize systems before loading assets

  final assets = app.world.audioAssets!;
  await assets.loadSound('explosion', 'assets/sounds/explosion.wav');
  await assets.loadMusic('theme', 'assets/music/theme.mp3');

  app.world.playMusic('theme', crossfade: const Duration(seconds: 2));
  app.world.playSfx('explosion');

  await app.run();
}
```

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs/plugins/audio) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
