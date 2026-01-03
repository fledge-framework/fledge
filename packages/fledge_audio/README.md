# fledge_audio

Full-featured audio plugin for [Fledge](https://fledge-framework.dev) games. Background music, sound effects, and spatial audio.

[![pub package](https://img.shields.io/pub/v/fledge_audio.svg)](https://pub.dev/packages/fledge_audio)

## Features

- **Background Music**: Play music with crossfading between tracks
- **Sound Effects**: Play one-shot sounds with volume control
- **Spatial Audio**: 2D positional audio based on entity positions
- **Volume Channels**: Master, music, SFX, voice, and ambient channels
- **Auto-Pause**: Pause audio when window loses focus

## Installation

```yaml
dependencies:
  fledge_audio: ^0.1.0
```

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_audio/fledge_audio.dart';

void main() async {
  final app = App()
    ..addPlugin(TimePlugin())
    ..addPlugin(AudioPlugin());

  // Load assets
  final assets = app.world.audioAssets!;
  await assets.loadSound('explosion', 'assets/sounds/explosion.wav');
  await assets.loadMusic('theme', 'assets/music/theme.mp3');

  // Play audio
  app.world.playSfx('explosion');
  app.world.playMusic('theme', crossfade: Duration(seconds: 2));
}
```

## Spatial Audio

Add positional audio to your game:

```dart
// Add listener to player/camera
world.spawn()
  ..insert(Transform2D.from(0, 0))
  ..insert(AudioListener());

// Add audio source to entities
world.spawn()
  ..insert(Transform2D.from(100, 50))
  ..insert(AudioSource(
    soundKey: 'engine',
    looping: true,
    autoPlay: true,
  ));
```

The audio system automatically adjusts volume and panning based on the listener's position relative to audio sources.

## Volume Channels

Control volume by category:

```dart
final channels = world.getResource<AudioChannels>()!;

// Set individual channel volumes (0.0 to 1.0)
channels.master = 0.8;
channels.music = 0.6;
channels.sfx = 1.0;
channels.voice = 1.0;
channels.ambient = 0.5;
```

## Documentation

See the [Audio Guide](https://fledge-framework.dev/docs/guides/audio) for detailed documentation.

## Related Packages

- [fledge_ecs](https://pub.dev/packages/fledge_ecs) - Core ECS framework
- [fledge_window](https://pub.dev/packages/fledge_window) - Window focus detection

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
