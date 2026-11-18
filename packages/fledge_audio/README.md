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

## Sound sources

An `AudioSource` is a sound that belongs to an entity: an engine hum, a
fan, a campfire. With a `Transform2D` (and an active `AudioListener`) it is
attenuated and panned by where the entity is; without one it plays centred
at its volume times its channel's volume.

```dart
// Starts looping as soon as the clip has loaded.
final fan = world.spawn()
  ..insert(Transform2D.from(320, 180))
  ..insert(AudioSource.looping(soundKey: 'fan_hum', volume: 0.6));

// Stop it, fading out (or at once, without fadeOut)...
world.get<AudioSource>(fan.entity)!
    .stop(fadeOut: const Duration(milliseconds: 400));

// ...and start it again from the beginning.
world.get<AudioSource>(fan.entity)!.play();
```

`play()` and `stop()` are carried out by `SpatialAudioSystem` at the end of
the frame. A `play()` waits for the engine and the clip; a `stop()` before
then cancels the start (an `autoPlay` source included). Despawning the
entity, or removing its `AudioSource`, stops its sound. Its `volume` and
`playbackSpeed` (speed and pitch, 1.0 as recorded) may change while it
plays: an engine's hum rises with `playbackSpeed = 0.8 + revs * 0.6`.

Nothing in the plugin holds up a frame. Channel volumes reach music that is
already playing, audio pauses while the window lacks focus, and everything
above the `AudioBackend` interface can be tested with a fake backend
(`AudioPlugin(backend: ...)`).

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs/plugins/audio) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
