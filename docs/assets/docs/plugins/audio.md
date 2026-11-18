# Audio

The `fledge_audio` plugin plays background music, sound effects and 2D spatial audio, with volume channels. It uses flutter_soloud for low-latency playback, behind a small `AudioBackend` interface.

Nothing in the plugin ever holds up a frame: the engine starts and clips load in the background, and requests made meanwhile wait (music) or are reported as skipped (sound effects).

## Installation

Add `fledge_audio` to your `pubspec.yaml`:

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
    ..addPlugin(WallTimePlugin()) // fades and channel volumes follow time
    ..addPlugin(AudioPlugin());

  // Register clips by key. They load in the background once the engine
  // has started; nothing waits for them.
  app.world
    ..loadMusic('theme', 'assets/music/theme.ogg')
    ..loadSound('explosion', 'assets/sounds/explosion.wav');

  // Music waits for its clip, so it can be asked for straight away.
  app.world.playMusic('theme', crossfade: const Duration(seconds: 2));

  await app.run();
}
```

## How requests are carried out

Every audio command (`playSfx`, `playMusic`, `setVolume`, ...) sends an event that `AudioEventSystem` handles at the start of the next frame (`Schedules.first`, in `FirstSets.platform`). It reads every request every frame, so none are lost while the engine starts:

- **Channel volume, pause and resume** apply at once, even before the engine is up.
- **Music** waits until the engine is up and the track's clip has loaded. Only the latest music request counts: asking for track B while A is still loading means B.
- **Sound effects** play if their clip is ready. Otherwise they are skipped and an `AudioFailed` says why (`still loading`, `audio has not started`, `audio is paused`): a sound effect that arrived late would be wrong.

Register clips early (at startup, or behind a loading screen) so sound effects are ready when they're needed. `AudioLibrary.settled` tells you when every registered clip has loaded or failed.

## Loading clips

```dart
world.loadSound('hoe', 'assets/sounds/hoe.wav');
world.loadMusic('town', 'assets/music/town.ogg');
```

Clips live in the `AudioLibrary` resource, by key, and load through `Assets<AudioClip>` (`fledge_assets`). **Sounds** are decoded into memory for instant starts. **Music** is streamed (decoded while it plays), so a long track never sits whole in memory.

Each clip announces itself with `AudioAssetLoaded` when it's ready, or `AudioFailed` if it can't be loaded. Query a clip with `world.audioLibrary!.statusOf(key)` (`waiting`, `loading`, `ready`, `failed`), and free one with `remove(key, backend)`.

## Playing sound effects

```dart
world.playSfx('explosion');
world.playSfx('footstep', volume: 0.5, playbackSpeed: 1.2);

// Positioned in the world: attenuated and panned relative to the active
// AudioListener (when spatial audio is enabled).
world.playSfx('door', position: (120.0, 40.0));
```

## Playing music

```dart
world.playMusic('menu');

// Fade from the current track, or in from silence.
world.playMusic('battle', crossfade: const Duration(seconds: 2));

world.playMusic(
  'boss',
  loop: true,
  volume: 0.8,          // before the music channel
  startPosition: 10.0,  // seconds
);
```

Asking for the track that's already playing changes nothing (except its volume), unless you pass `restart: true`. So a game can ask for "the music for here and now" every frame, and only real changes do anything.

Crossfades run on the audio thread (SoLoud's own fades), so they're smooth whatever the frame rate. Each outgoing track fades from wherever it is and stops itself; crossfades that overlap never leave a track behind.

### Stopping music

```dart
world.stopMusic();
world.stopMusic(fadeOut: const Duration(seconds: 1));
```

## Volume channels

Five channels: `master`, `music`, `sfx`, `voice`, `ambient`. A sound's volume is its own volume × its channel × master.

```dart
world.setVolume(AudioChannel.master, 0.8);
world.setVolume(AudioChannel.music, 0.5);
world.setVolume(AudioChannel.music, 0.2, fade: const Duration(seconds: 2));

final musicVolume = world.getVolume(AudioChannel.music);
```

Channel changes reach the music that's already playing (`MusicVolumeSystem`), and spatial sources, which are re-mixed every frame. A sound effect keeps the volume it started with. A change during a track's fade-in re-targets the fade over the time it has left, rather than cutting it short.

## Pause and resume

```dart
world.pauseAudio();
world.resumeAudio();
world.toggleAudioPause();

if (world.isAudioPaused) { /* ... */ }
```

Pausing pauses every voice: the music, tracks fading out, sound effects and spatial sources. Music started while paused starts paused.

With `pauseOnFocusLoss` (the default), audio pauses while the window doesn't have focus and resumes when it comes back. Focus only undoes the pauses focus caused: a pause the game asked for stays. Focus comes from Flutter's app lifecycle; to drive it yourself, set `world.getResource<AudioFocus>()!.hasFocus`.

## Audio while the world isn't ticking

Games often stop ticking the world on menus, loading screens or a pause screen. Audio still needs to run there: title music has to start, clips keep loading, fades finish, focus pause works. Call `world.pumpAudio` on every frame you don't tick:

```dart
void onFrame(double dt) {
  if (playing) {
    app.tick();
  } else {
    app.world.playMusic('title', crossfade: const Duration(seconds: 3));
    app.world.pumpAudio(delta: dt);
  }
}
```

It runs the audio systems once, advancing only audio's own event queues, so gameplay events waiting for the next tick are untouched. Sources run too, so one can be played, stopped or changed from a menu; with nothing moving, their mix stays as it was.

## Spatial audio

### The listener

Add an `AudioListener` to your player or camera entity:

```dart
world.spawn()
  ..insert(Transform2D.from(0, 0))
  ..insert(AudioListener());
```

### Sources

Add `AudioSource` components to entities that emit sound:

```dart
world.spawn()
  ..insert(Transform2D.from(100, 50))
  ..insert(AudioSource(soundKey: 'engine', looping: true, autoPlay: true));
```

```dart
AudioSource(
  soundKey: 'engine',        // key in the AudioLibrary
  looping: true,
  autoPlay: true,            // starts once its clip is ready
  volume: 1.0,               // before attenuation and the channel
  playbackSpeed: 1.0,
  channel: AudioChannel.sfx,
  maxDistance: 500.0,        // overrides the config
  referenceDistance: 50.0,   // overrides the config
)
```

Without a `Transform2D` (or with no active listener, or spatial audio off)
a source plays centred at its volume times its channel's volume.

#### Starting and stopping

```dart
final source = world.get<AudioSource>(fan)!;
source.stop(fadeOut: const Duration(milliseconds: 400)); // or at once
source.play(); // again, from the beginning
```

`play()` and `stop()` are carried out by `SpatialAudioSystem` at the end of
the frame, and only the latest call counts. A `play()` waits for the engine
and the clip; a `stop()` before then cancels the start (an `autoPlay` source
included). Despawning the entity, or removing its `AudioSource`, stops its
sound with a short fade.

### Configuration

```dart
AudioPlugin(config: AudioConfig(
  spatialConfig: SpatialAudioConfig(
    enabled: true,
    maxDistance: 500.0,       // silent at this distance
    referenceDistance: 100.0, // full volume within it
    rolloffFactor: 1.0,       // attenuation curve steepness
    maxPan: 0.8,              // furthest left/right (-0.8 to 0.8)
  ),
))
```

Attenuation is linear: full volume inside `referenceDistance`, silent at `maxDistance`. Pan follows the lateral offset (`(dx / maxDistance).clamp(-maxPan, maxPan)`). Listeners and sources without a `Transform2D` are ignored.

`SpatialAudioSystem` runs in `Schedules.last`, so it reads each entity's *final* position for the frame, after physics, movement in `update`, and camera follow, shake and parallax. Move listeners and sources in any earlier schedule; no ordering against the audio systems is needed.

## Configuration

```dart
AudioPlugin()               // defaults
AudioPlugin.nonSpatial()    // sources play without distance or pan mixing

AudioPlugin(config: AudioConfig(
  masterVolume: 0.8,        // the engine's global volume
  channels: AudioChannelConfig(music: 0.6, sfx: 1.0, voice: 1.0, ambient: 0.8),
  maxConcurrentSounds: 32,
  pauseOnFocusLoss: true,
  spatialConfig: SpatialAudioConfig(maxDistance: 500.0),
))
```

## Testing without a sound device

Everything above `AudioBackend` is engine-agnostic. Pass your own backend to test audio logic headlessly:

```dart
final app = App()
  ..insertResource(WallTime())
  ..addPlugin(AudioPlugin(backend: MyFakeBackend()));
```

`SoLoudBackend` (the default) only loads the native library when the engine starts, so an app with `AudioPlugin` can be built, and its schedule checked, without one. If the engine can't start, audio stays off and `world.audioState!.initError` says why.

## Responding to audio events

```dart
for (final e in world.eventReader<MusicChanged>().read()) {
  print('Music: ${e.previousKey} -> ${e.newKey}');
}
for (final e in world.eventReader<AudioFailed>().read()) {
  print('Audio: ${e.key}: ${e.error}');
}
```

## Querying state

```dart
final state = world.audioState!;
state.isInitialized;      // the engine has started
state.currentMusicKey;    // or world.currentMusicKey
state.isMusicPlaying;     // or world.isMusicPlaying
state.isCrossfading;
state.activeSoundCount;
```

## Complete example

```dart
App buildApp() {
  final app = App()
    ..addPlugin(WallTimePlugin())
    ..addPlugin(AudioPlugin(config: AudioConfig(
      channels: AudioChannelConfig(music: 0.7),
    )))
    ..addSystem(MusicForPlaceSystem(), schedule: Schedules.update);
  app.world
    ..loadMusic('village', 'assets/music/village.ogg')
    ..loadMusic('forest', 'assets/music/forest.ogg')
    ..loadSound('step', 'assets/sounds/step.wav');
  return app;
}

/// Asks for the music for where the player is, every frame: only changes
/// do anything.
class MusicForPlaceSystem implements System {
  @override
  SystemMeta get meta => const SystemMeta(
    name: 'music_for_place',
    eventWrites: {PlayMusicRequest},
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  void run(World world) {
    final inForest = /* ... */ false;
    world.playMusic(
      inForest ? 'forest' : 'village',
      crossfade: const Duration(seconds: 3),
    );
  }
}
```

## Systems reference

| System | Schedule | Purpose |
|--------|----------|---------|
| `AudioInitSystem` | `first` (`FirstSets.platform`) | Starts the engine without waiting for it |
| `AudioEventSystem` | `first` (`FirstSets.platform`) | Carries out requests; starts and settles clip loads |
| `AudioFocusSystem` | `first` (`FirstSets.platform`) | Pauses while the window lacks focus (if enabled) |
| `ChannelFadeSystem` | `update` | Advances channel volume fades |
| `MusicVolumeSystem` | `update` | Applies channel volume to the playing music |
| `SpatialAudioSystem` | `last` | Starts, stops and mixes `AudioSource`s; stops the sounds of despawned sources |
| `AudioCleanupSystem` | `last` | Forgets ended voices; sends `SfxFinished` / `MusicFinished` |

## Resources reference

| Resource | Description |
|----------|-------------|
| `AudioLibrary` | Sounds and music by key, and their loading status |
| `Assets<AudioClip>` | The loaded clips (`fledge_assets`) |
| `AudioState` | The engine, the playing music, live voices, pause state |
| `VolumeChannels` | Volume per channel, and channel fades |
| `AudioFocus` | Whether the window has focus |
| `AudioPump` | The audio systems, for `world.pumpAudio` |
| `AudioConfig`, `SpatialAudioConfig` | Configuration |

## Events reference

### Requests

| Event | Description |
|-------|-------------|
| `PlaySfxRequest` | Play a sound effect (optionally positioned) |
| `PlayMusicRequest` | Play a track (crossfade, restart) |
| `StopMusicRequest` | Stop the music (optionally fading) |
| `PauseAudioRequest` / `ResumeAudioRequest` | Pause or resume everything |
| `SetChannelVolumeRequest` | Set a channel's volume (optionally fading) |

### Responses

| Event | Description |
|-------|-------------|
| `SfxStarted` | A sound effect started (with its `AudioVoice`) |
| `SfxFinished` | A sound effect or source sound ended |
| `MusicStarted` | A track started |
| `MusicChanged` | The music changed from one track to another |
| `MusicFinished` | A non-looping track reached its end |
| `AudioPaused` / `AudioResumed` | Audio paused (by focus loss or not) / resumed |
| `AudioAssetLoaded` | A clip finished loading |
| `AudioFailed` | Something couldn't be loaded or played, and why |

## Components reference

| Component | Description |
|-----------|-------------|
| `AudioListener` | The spatial audio receiver |
| `AudioSource` | A spatial audio emitter |

## Platform notes

- **Windows/macOS/Linux**: full support via flutter_soloud FFI
- **iOS/Android**: full support via flutter_soloud
- **Web**: limited support (WebAudio backend)

## See also

- [Plugins Overview](/docs/plugins/overview): the plugin system
- [Assets](/docs/plugins/assets): `Assets<T>` and handles
- [App & Plugins Guide](/docs/guides/app-plugins): plugin architecture
