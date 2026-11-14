# fledge_audio

Full-featured audio plugin for [Fledge](https://fledge-framework.dev) games — background music, sound effects, and 2D spatial audio.

[![pub package](https://img.shields.io/pub/v/fledge_audio.svg)](https://pub.dev/packages/fledge_audio)

## Installation

```yaml
dependencies:
  fledge_audio: ^0.6.0
```

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_audio/fledge_audio.dart';

void main() async {
  final app = App()
    ..addPlugin(WallTimePlugin())
    ..addPlugin(AudioPlugin());

  // Register clips by key; they load in the background once the engine is
  // up (music streamed, sounds decoded up front). Nothing waits on them.
  app.world
    ..loadMusic('theme', 'assets/music/theme.ogg')
    ..loadSound('explosion', 'assets/sounds/explosion.wav');

  // Music waits for its clip; crossfades run on the audio thread.
  app.world.playMusic('theme', crossfade: const Duration(seconds: 2));
  app.world.playSfx('explosion', position: (120, 40));

  await app.run();
}
```

Nothing in the plugin holds up a frame. Channel volumes reach music that is
already playing, audio pauses while the window lacks focus, and everything
above the `AudioBackend` interface can be tested with a fake backend
(`AudioPlugin(backend: ...)`).

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs/plugins/audio) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
