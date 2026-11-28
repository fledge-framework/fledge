# Audio

`fledge_audio` plays music, sound effects and 2D spatial audio, with volume
channels. It runs on [flutter_soloud](https://pub.dev/packages/flutter_soloud)
behind a small `AudioBackend` interface.

Nothing in the plugin holds up a frame. The engine starts and clips load in
the background; requests made meanwhile wait (music) or are reported as
skipped (sound effects).

## What you need

```yaml
dependencies:
  fledge_audio: ^0.7.2
```

- **Flutter 3.50+** (Dart 3.14+). flutter_soloud 5.3 builds its native library
  with Dart build hooks, and before Flutter 3.50 `flutter run` on Windows
  could lose that library, so the app started silent.
- **Platforms**: desktop first (Windows, macOS, Linux). flutter_soloud also
  supports Android, iOS and the web; the web needs the extra setup in
  [its setup guide](https://docs.page/alnitak/flutter_soloud_docs/get_started/setup).
  Fledge isn't tested on those.
- Audio files are Flutter assets: list them under `flutter: assets:` in your
  `pubspec.yaml`. MP3, WAV, OGG and FLAC work everywhere.
- Spatial audio reads `GlobalTransform2D` (falling back to `Transform2D`)
  from `fledge_render_2d`, which comes in as a dependency.
- Add `WallTimePlugin` too: channel fades advance with `WallTime`.

## Quick start

```dart
final app = App()
  ..addPlugin(WallTimePlugin())
  ..addPlugin(AudioPlugin());

// Register clips by key. They load in the background once the engine has
// started.
app.world
  ..loadMusic('theme', 'assets/music/theme.ogg')
  ..loadSound('explosion', 'assets/sounds/explosion.wav');

// Music waits for its clip, so you can ask for it straight away.
app.world.playMusic('theme', crossfade: const Duration(seconds: 2));
```

## How requests are carried out

Every audio command (`playSfx`, `playMusic`, `setVolume`, …) sends an event,
which `AudioEventSystem` handles at the start of the next frame. It reads
every request every frame, so none are lost while the engine starts:

- **Channel volume, pause and resume** apply at once, even before the engine
  is up.
- **Music** waits until the engine is up and the track has loaded. Only the
  latest music request counts: asking for track B while A is loading means B.
- **Sound effects** play if their clip is ready. Otherwise they're skipped,
  with an `AudioFailed` saying why (`still loading`, `audio has not started`,
  `audio is paused`, `no such sound in the AudioLibrary`). A sound effect that
  arrives late would be wrong.

So register clips early (at startup, or behind a loading screen).

## Loading clips

```dart
void registerAudio(World world) {
  world.loadSound('hoe', 'assets/sounds/hoe.wav');
  world.loadMusic('town', 'assets/music/town.ogg');
}
```

Clips live in the `AudioLibrary` resource by key and load through
`Assets<AudioClip>` (see [Assets](/docs/app/assets)), using an
`AudioClipLoader`. The two kinds (`AudioKind`) load differently:

- **Sounds** are decoded into memory, for instant starts.
- **Music** is streamed (decoded while it plays), so a long track never sits
  whole in memory.

Registering the same key twice with the same path does nothing; with a
different path it throws a `StateError` (remove the old one first).

Each clip sends `AudioAssetLoaded` when it's ready, or `AudioFailed` if it
can't be loaded. To check on one yourself:

| `AudioLibrary` member | Meaning |
|---|---|
| `statusOf(key)` | An `AudioClipStatus`: `waiting` (for the engine), `loading`, `ready` or `failed`; null if not registered |
| `errorOf(key)` | Why it failed |
| `settled` | Every registered clip is ready or failed: a loading screen can wait on this |
| `kindOf(key)`, `contains(key)`, `keys` | What's registered |
| `remove(key, backend)` | Unregister and free a clip |

```dart
bool audioReady(World world) => world.audioLibrary?.settled ?? false;
```

## Sound effects

```dart
void footstep(World world) {
  world.playSfx('footstep', volume: 0.5);
  world.playSfx('door', position: (120.0, 40.0)); // panned and attenuated
  world.playSfx('coin', playbackSpeed: 1.2); // faster and higher
}
```

With a `position`, the sound is attenuated and panned relative to the active
`AudioListener` (see [Spatial audio](#spatial-audio)). Each one sends
`SfxStarted` (with its `AudioVoice`) and, when it ends, `SfxFinished`.

## Music

```dart
void music(World world) {
  // Crossfade from whatever is playing (or from silence) over 3 s.
  world.playMusic('town', crossfade: const Duration(seconds: 3));

  // Options: loop (default true), volume, startPosition (seconds), restart.
  world.playMusic('boss', loop: false, volume: 0.8, startPosition: 12.5);

  world.stopMusic(fadeOut: const Duration(seconds: 2));
}
```

Asking for the track that's already playing changes nothing but its volume,
unless `restart: true`. So a system can ask for "the music for this area" every
frame. Crossfades and fade-outs run on the audio thread, smooth at any frame
rate.

Music sends `MusicStarted`, `MusicChanged` (`previousKey`, `newKey`) when it
replaces another track, and `MusicFinished` when a track that doesn't loop
reaches its end.

## Volume channels

There are five channels (`AudioChannel`): `master`, `music`, `sfx`, `voice`
and `ambient`. A sound's volume is its own volume × its channel × master.
Changes reach what's already playing, music and sources included.

```dart
void volumeSettings(World world) {
  world.setVolume(AudioChannel.music, 0.5);
  world.setVolume(
    AudioChannel.master,
    0.0,
    fade: const Duration(seconds: 1), // fade out everything
  );
  final music = world.getVolume(AudioChannel.music);
}
```

The `VolumeChannels` resource (`world.volumeChannels`) also has
`getEffectiveVolume`, `mute`, `isMuted` and `isFading`. Starting channel
volumes come from `AudioConfig.channels`.

## Pausing

```dart
void pauseMenu(World world, bool open) {
  if (open) {
    world.pauseAudio();
  } else {
    world.resumeAudio();
  }
  // Or: world.toggleAudioPause();
}
```

Pausing stops everything: music, effects and sources. `AudioPaused` and
`AudioResumed` report it. Sound effects asked for while paused are skipped;
sources and music started while paused start paused.

With `AudioConfig.pauseOnFocusLoss` (on by default), audio also pauses while
the app doesn't have focus and resumes when it comes back. Focus comes from
Flutter's app lifecycle (an `AppLifecycleListener`: anything but `resumed`
counts as unfocused), so it works without `fledge_window`. Focus only undoes
the pauses it caused: a pause the game asked for stays. That pause's event is
`AudioPaused(byFocusLoss: true)`. To drive focus yourself, set
`world.getResource<AudioFocus>()!.hasFocus`.

## Audio while the world isn't ticking

Games often stop ticking the world on a menu, loading screen or pause screen.
Audio still needs to run there: title music starts, clips keep loading, fades
finish. Call `world.pumpAudio` on each frame you don't tick:

```dart
Future<void> onFrame(App app, bool playing, double dt) async {
  if (playing) {
    await app.tick();
  } else {
    await app.world.pumpAudio(delta: dt);
  }
}
```

It runs the audio systems once and advances only audio's own event queues,
so gameplay events waiting for the next tick are left alone. `delta` drives
channel fades.

## Spatial audio

### The listener

Put an `AudioListener` on the player or the camera, with a `Transform2D`.
The first active one (`isActive`) is used.

```dart
void spawnListener(World world) {
  world.spawn()
    ..insert(Transform2D.from(0, 0))
    ..insert(AudioListener());
}
```

### Sources

An `AudioSource` is a sound that belongs to an entity: an engine hum, a fan,
a campfire. With a `Transform2D` (and an active listener) it's attenuated and
panned by where the entity is; without one it plays centred at its volume ×
its channel.

```dart
void spawnFan(World world) {
  // Starts looping as soon as the clip has loaded.
  final fan = world.spawn()
    ..insert(Transform2D.from(320, 180))
    ..insert(AudioSource.looping(soundKey: 'fan_hum', volume: 0.6));

  // Stop it with a fade (or at once, without fadeOut)...
  world.get<AudioSource>(fan.entity)!
      .stop(fadeOut: const Duration(milliseconds: 400));

  // ...and start it again from the beginning.
  world.get<AudioSource>(fan.entity)!.play();
}
```

| Constructor | Defaults |
|---|---|
| `AudioSource(...)` | `sfx` channel, not looping, no `autoPlay` |
| `AudioSource.looping(soundKey:, channel:, volume:, autoPlay:)` | Looping, `autoPlay: true` |
| `AudioSource.ambient(soundKey:, volume:, looping:, maxDistance:)` | `ambient` channel, looping, `autoPlay: true` |

`play()` and `stop()` are carried out by `SpatialAudioSystem` at the end of
the frame. A `play()` waits for the engine and the clip; a `stop()` before
then cancels the start, `autoPlay` included. Only the latest call counts
(it's held in `request`, an `AudioSourceRequest`). Despawning the entity, or
removing its `AudioSource`, stops its sound with a short fade.

`volume`, `playbackSpeed` (speed and pitch, 1.0 as recorded), `looping` and
`channel` are plain fields. Volume and speed may change while the source
plays, so an engine's hum can rise with its revs:

```dart
void engineHum(World world, Entity car, double revs) {
  world.get<AudioSource>(car)?.playbackSpeed = 0.8 + revs * 0.6;
}
```

`isPlaying` says whether it has a live voice. When a source's sound ends
(it reached its end, was stopped, or its entity went away) an
`AudioSourceFinished` is sent with its `soundKey` and `entity`; the entity
may already be despawned. `SfxFinished` is only for effects started with
`playSfx`.

### How it's mixed

| `SpatialAudioConfig` field | Default | Meaning |
|---|---|---|
| `enabled` | `true` | Off: everything plays centred |
| `referenceDistance` | 100 | Full volume up to here |
| `maxDistance` | 1000 | Silent from here |
| `rolloffFactor` | 1.0 | Slope of the falloff (below) |
| `maxPan` | 0.8 | The furthest left/right a sound pans |

Volume falls off **linearly** between `referenceDistance` and `maxDistance`.
`rolloffFactor` multiplies the slope: 1.0 reaches silence at `maxDistance`,
2.0 halfway there. There is no inverse-square curve. Pan is the horizontal
offset divided by `maxDistance`, clamped to ±`maxPan`. Each source can
override `referenceDistance` and `maxDistance`.

Positions are world-space: each entity's propagated `GlobalTransform2D`
when it has one, so a listener on a child of the camera or a source on a
child of a moving car follows its parent. An entity without one (no
`TransformPropagateSystem`, or spawned this frame before propagation ran)
uses its `Transform2D.translation`. `SpatialAudioSystem` runs in `last`, so
it sees transforms propagated in `postUpdate`; if you register
`TransformPropagateSystem` in `last`, it still runs after it.

There's no Doppler effect. `AudioListener.velocityX`/`velocityY` were never
read and are deprecated.

## Configuration

```dart
final app = App()
  ..addPlugin(WallTimePlugin())
  ..addPlugin(
    AudioPlugin(
      config: const AudioConfig(
        masterVolume: 0.8,
        channels: AudioChannelConfig(music: 0.7, sfx: 1.0),
        spatialConfig: SpatialAudioConfig(maxDistance: 500),
        pauseOnFocusLoss: true,
        maxConcurrentSounds: 32,
      ),
    ),
  );
```

`masterVolume` and `maxConcurrentSounds` are applied to the engine when it
starts (flutter_soloud's global volume and voice limit). `masterVolume` is
separate from the `master` channel, which always starts at 1.0.
`AudioPlugin.defaults()` and `AudioPlugin.nonSpatial()` (spatial audio off)
are shorthands.

## Testing and custom backends

Everything above `AudioBackend` is engine-agnostic. Pass your own
implementation to test audio logic without a sound device:
`AudioPlugin(backend: MyFakeBackend())`. Voices are `AudioVoice`s, opaque ids
the backend hands out.

`SoLoudBackend` (the default) only loads the native library when the engine
starts, so an app with `AudioPlugin` can be built, and its schedule checked,
without one. If the engine can't start, audio stays off and
`world.audioState!.initError` says why.

To serve audio from your own `AssetBundle` (a packed or encrypted one), pass
it to the backend. Clips are then read through the bundle and handed to the
engine from memory, with no copy written to disk:

```dart
import 'package:fledge_audio/fledge_audio.dart';
import 'package:flutter/services.dart';

AudioPlugin audioFromBundle(AssetBundle bundle) =>
    AudioPlugin(backend: SoLoudBackend(null, bundle));
```

## Querying state

`world.audioState` (`AudioState`) has `isInitialized`, `currentMusicKey`,
`isMusicPlaying`, `isCrossfading`, `isPaused` and `activeSoundCount`. The
shortcuts `world.isMusicPlaying`, `world.currentMusicKey` and
`world.isAudioPaused` read it too.

## Systems

Order your own systems against these with their `systemName` constants:

| System | Schedule | Job |
|---|---|---|
| `AudioInitSystem` | `first` (`FirstSets.platform`) | Starts the engine on the first frame, without waiting |
| `AudioEventSystem` | `first`, after init | Carries out requests, drives loading |
| `AudioFocusSystem` | `first`, after the event system | Focus pause (only with `pauseOnFocusLoss`) |
| `ChannelFadeSystem` | `update` | Advances channel fades |
| `MusicVolumeSystem` | `update`, after `ChannelFadeSystem` | Keeps playing music at its channel volume |
| `SpatialAudioSystem` | `last`, after `TransformPropagateSystem` | Plays, stops and mixes `AudioSource`s, after every transform writer |
| `AudioCleanupSystem` | `last`, after `SpatialAudioSystem` | Forgets ended voices, sends `SfxFinished`/`AudioSourceFinished`/`MusicFinished` |

## Events

| Requests (sent by the helpers) | Responses |
|---|---|
| `PlaySfxRequest`, `PlayMusicRequest`, `StopMusicRequest`, `PauseAudioRequest`, `ResumeAudioRequest`, `SetChannelVolumeRequest` | `SfxStarted`, `SfxFinished`, `AudioSourceFinished`, `MusicStarted`, `MusicChanged`, `MusicFinished`, `AudioPaused`, `AudioResumed`, `AudioAssetLoaded`, `AudioFailed` |

```dart
final reportAudioErrors = FunctionSystem(
  'reportAudioErrors',
  eventReads: {AudioFailed},
  run: (world) {
    for (final failure in world.eventReader<AudioFailed>().read()) {
      print('audio: ${failure.key}: ${failure.error}');
    }
  },
);
```

## See also

- [Window](/docs/platform/window)
- [Assets](/docs/app/assets)
- [Transforms](/docs/rendering/transforms)
- [API reference](https://pub.dev/documentation/fledge_audio/latest/)
