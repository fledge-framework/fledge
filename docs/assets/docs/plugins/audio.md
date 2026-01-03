# Audio

The `fledge_audio` plugin provides comprehensive audio management with background music, sound effects, 2D spatial audio, and volume channels. It uses flutter_soloud for low-latency FFI-based audio playback.

## Installation

Add `fledge_audio` to your `pubspec.yaml`:

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
    .addPlugin(TimePlugin())  // Required for crossfading
    .addPlugin(AudioPlugin());

  // Initialize systems
  await app.tick();

  // Load audio assets
  final assets = app.world.audioAssets!;
  await assets.loadSound('explosion', 'assets/sounds/explosion.wav');
  await assets.loadMusic('theme', 'assets/music/theme.mp3');

  // Play music and process the event
  app.world.playMusic('theme');
  await app.tick();

  // Start Flutter app
  runApp(MyGameApp(app: app));
}
```

## Understanding Event-Driven Audio

Audio commands like `playSfx()`, `playMusic()`, and `stopMusic()` use Fledge's **event system**. When you call these methods, they queue a request event that gets processed by the `AudioEventSystem` during the next `app.tick()`.

### Why This Matters

- **Inside the game loop**: Events are automatically processed each frame - just call `playSfx()` and it plays
- **Outside the game loop** (e.g., splash screens, main menu before game starts): You must call `app.tick()` to process queued events

### Playing Audio Before the Game Loop Starts

```dart
void main() async {
  final app = App()
    .addPlugin(TimePlugin())
    .addPlugin(AudioPlugin());

  // First tick initializes the audio system
  await app.tick();

  // Load assets (direct async call, not event-based)
  final assets = app.world.audioAssets!;
  await assets.loadMusic('menu_theme', 'assets/music/menu.mp3');

  // Queue the play request
  app.world.playMusic('menu_theme');

  // Process the event - music starts playing now
  await app.tick();

  // Music is now playing on your title/splash screen!
  runApp(MyGameApp(app: app));
}
```

### Within Systems (Game Loop Active)

When the game loop is running, events are processed automatically each frame:

```dart
class GameplaySystem implements System {
  @override
  Future<void> run(World world) async {
    // This works immediately - event processed next tick
    if (playerScored) {
      world.playSfx('score');
    }
  }
}
```

## Playing Sound Effects

Sound effects are short audio clips for game events like explosions, footsteps, or UI feedback.

### Basic Playback

```dart
world.playSfx('explosion');
```

### With Options

```dart
world.playSfx(
  'footstep',
  volume: 0.5,           // 0.0 to 1.0
  playbackSpeed: 1.2,    // Speed multiplier
  position: (100.0, 50.0), // For spatial audio
);
```

## Playing Music

Music tracks are longer audio files typically used for background ambience or level themes.

### Basic Playback

```dart
world.playMusic('main_theme');
```

### With Crossfading

Smoothly transition between tracks:

```dart
world.playMusic(
  'battle_theme',
  crossfade: Duration(seconds: 2),
);
```

### With Options

```dart
world.playMusic(
  'ambient',
  loop: true,              // Loop the track (default: true)
  volume: 0.7,             // 0.0 to 1.0
  crossfade: Duration(seconds: 3),
  startPosition: 30.0,     // Start at 30 seconds
);
```

### Stopping Music

```dart
// Stop immediately
world.stopMusic();

// Fade out over 1 second
world.stopMusic(fadeOut: Duration(seconds: 1));
```

## Volume Channels

The plugin provides five volume channels for fine-grained control:

| Channel | Purpose |
|---------|---------|
| `master` | Overall volume multiplier |
| `music` | Background music |
| `sfx` | Sound effects |
| `voice` | Voice/dialogue |
| `ambient` | Environmental sounds |

### Setting Volume

```dart
world.setVolume(AudioChannel.master, 0.8);
world.setVolume(AudioChannel.music, 0.5);
world.setVolume(AudioChannel.sfx, 1.0);
```

### Getting Volume

```dart
final musicVolume = world.getVolume(AudioChannel.music);
```

## Pause and Resume

### Global Pause

```dart
world.pauseAudio();   // Pause all audio
world.resumeAudio();  // Resume all audio
world.toggleAudioPause(); // Toggle pause state
```

### Query Pause State

```dart
if (world.isAudioPaused) {
  // Audio is paused
}
```

## Spatial Audio

The plugin supports 2D spatial audio with panning and distance-based volume falloff.

### Setting Up the Listener

Add an `AudioListener` component to your player or camera entity:

```dart
world.spawn()
  ..insert(Transform2D.from(0, 0))
  ..insert(AudioListener());
```

### Adding Audio Sources

Add `AudioSource` components to entities that emit sound:

```dart
// Looping engine sound
world.spawn()
  ..insert(Transform2D.from(100, 50))
  ..insert(AudioSource(
    soundKey: 'engine',
    looping: true,
    autoPlay: true,
  ));

// One-shot explosion
world.spawn()
  ..insert(Transform2D.from(200, 100))
  ..insert(AudioSource(
    soundKey: 'explosion',
    looping: false,
    autoPlay: true,
    volume: 0.8,
  ));
```

### AudioSource Options

```dart
AudioSource(
  soundKey: 'engine',        // Loaded sound asset key
  looping: true,             // Loop the sound
  autoPlay: true,            // Start playing automatically
  volume: 1.0,               // Base volume
  channel: AudioChannel.sfx, // Volume channel
  maxDistance: 500.0,        // Override config max distance
  referenceDistance: 50.0,   // Override config reference distance
)
```

### Spatial Audio Configuration

Configure spatial audio behavior in the plugin:

```dart
AudioPlugin(config: AudioConfig(
  spatialConfig: SpatialAudioConfig(
    enabled: true,
    maxDistance: 500.0,       // Sound fades to 0 at this distance
    referenceDistance: 100.0, // Full volume within this distance
    rolloffFactor: 1.0,       // Attenuation curve steepness
    maxPan: 0.8,              // Maximum left/right pan (-0.8 to 0.8)
  ),
))
```

## Configuration

### Default Configuration

```dart
AudioPlugin()
// Or explicitly:
AudioPlugin.defaults()
```

### Without Spatial Audio

```dart
AudioPlugin.nonSpatial()
```

### Custom Configuration

```dart
AudioPlugin(config: AudioConfig(
  masterVolume: 0.8,
  channels: AudioChannelConfig(
    music: 0.6,
    sfx: 1.0,
    voice: 1.0,
    ambient: 0.8,
  ),
  pauseOnFocusLoss: true,  // Auto-pause when window loses focus
  spatialConfig: SpatialAudioConfig(
    enabled: true,
    maxDistance: 500.0,
    referenceDistance: 100.0,
  ),
))
```

## Preloading Assets

### Direct Loading

```dart
final assets = world.audioAssets!;
await assets.loadSound('explosion', 'assets/sounds/explosion.wav');
await assets.loadMusic('theme', 'assets/music/theme.mp3');
```

### Event-Based Loading

```dart
world.preloadAudio(
  'assets/sounds/explosion.wav',
  key: 'explosion',
  isMusic: false,
);

// Listen for completion
for (final event in world.eventReader<AudioAssetLoaded>().read()) {
  print('Loaded: ${event.key}');
}
```

## Responding to Audio Events

### Sound Effect Events

```dart
for (final event in world.eventReader<SfxStarted>().read()) {
  print('Playing: ${event.soundKey}');
}

for (final event in world.eventReader<SfxFinished>().read()) {
  print('Finished: ${event.soundKey}');
}
```

### Music Events

```dart
for (final event in world.eventReader<MusicStarted>().read()) {
  print('Music started: ${event.musicKey}');
}

for (final event in world.eventReader<MusicChanged>().read()) {
  print('Music changed: ${event.previousKey} -> ${event.newKey}');
}
```

### Error Handling

```dart
for (final event in world.eventReader<AudioFailed>().read()) {
  print('Audio error for ${event.key}: ${event.reason}');
}
```

## Querying Audio State

```dart
final state = world.audioState;
if (state != null) {
  print('Music playing: ${state.isMusicPlaying}');
  print('Current track: ${state.currentMusicKey}');
  print('Music position: ${state.musicPosition}s');
  print('Active sounds: ${state.activeSoundCount}');
  print('Is paused: ${state.isPaused}');
}
```

## Complete Example

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_audio/fledge_audio.dart';
import 'package:fledge_input/fledge_input.dart';

enum Actions { shoot, toggleMusic, volumeUp, volumeDown }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final inputMap = InputMap.builder()
    .bindKey(LogicalKeyboardKey.space, ActionId.fromEnum(Actions.shoot))
    .bindKey(LogicalKeyboardKey.keyM, ActionId.fromEnum(Actions.toggleMusic))
    .bindKey(LogicalKeyboardKey.equal, ActionId.fromEnum(Actions.volumeUp))
    .bindKey(LogicalKeyboardKey.minus, ActionId.fromEnum(Actions.volumeDown))
    .build();

  final app = App()
    .addPlugin(TimePlugin())
    .addPlugin(AudioPlugin())
    .addPlugin(InputPlugin.simple(
      context: InputContext(name: 'default', map: inputMap),
    ))
    .addSystem(AudioControlSystem());

  // Initialize systems (required before loading assets)
  await app.tick();

  // Load audio assets
  final assets = app.world.audioAssets!;
  await assets.loadSound('laser', 'assets/sounds/laser.wav');
  await assets.loadMusic('menu', 'assets/music/menu.mp3');
  await assets.loadMusic('gameplay', 'assets/music/gameplay.mp3');

  // Start menu music before the game loop
  app.world.playMusic('menu');
  await app.tick();  // Process the play event

  // Launch the Flutter app with music already playing
  runApp(MyGameApp(app: app));
}

class AudioControlSystem implements System {
  @override
  SystemMeta get meta => const SystemMeta(name: 'AudioControlSystem');

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) async {
    final actions = world.getResource<ActionState>()!;

    // Play laser sound on shoot
    if (actions.justPressed(ActionId.fromEnum(Actions.shoot))) {
      world.playSfx('laser');
    }

    // Toggle between menu and gameplay music
    if (actions.justPressed(ActionId.fromEnum(Actions.toggleMusic))) {
      final currentMusic = world.currentMusicKey;
      if (currentMusic == 'menu') {
        world.playMusic('gameplay', crossfade: Duration(seconds: 2));
      } else {
        world.playMusic('menu', crossfade: Duration(seconds: 2));
      }
    }

    // Volume controls
    if (actions.justPressed(ActionId.fromEnum(Actions.volumeUp))) {
      final current = world.getVolume(AudioChannel.master);
      world.setVolume(AudioChannel.master, (current + 0.1).clamp(0.0, 1.0));
    }

    if (actions.justPressed(ActionId.fromEnum(Actions.volumeDown))) {
      final current = world.getVolume(AudioChannel.master);
      world.setVolume(AudioChannel.master, (current - 0.1).clamp(0.0, 1.0));
    }
  }
}
```

## Resources Reference

| Resource | Description |
|----------|-------------|
| `AudioAssets` | Loaded sound and music assets |
| `AudioState` | Current playback state |
| `VolumeChannels` | Per-channel volume levels |
| `AudioConfig` | Plugin configuration |
| `SpatialAudioConfig` | Spatial audio settings |

## Events Reference

### Request Events

| Event | Description |
|-------|-------------|
| `PlaySfxRequest` | Request to play a sound effect |
| `PlayMusicRequest` | Request to play music |
| `StopMusicRequest` | Request to stop music |
| `PauseAudioRequest` | Request to pause all audio |
| `ResumeAudioRequest` | Request to resume all audio |
| `SetChannelVolumeRequest` | Request to change channel volume |
| `PreloadAudioRequest` | Request to preload an audio asset |

### Response Events

| Event | Description |
|-------|-------------|
| `SfxStarted` | Fired when a sound effect starts playing |
| `SfxFinished` | Fired when a sound effect finishes |
| `MusicStarted` | Fired when music starts playing |
| `MusicFinished` | Fired when music finishes |
| `MusicChanged` | Fired when music track changes |
| `AudioFailed` | Fired when an audio operation fails |
| `AudioPaused` | Fired when audio is paused |
| `AudioResumed` | Fired when audio is resumed |
| `AudioAssetLoaded` | Fired when an asset finishes loading |

## Components Reference

| Component | Description |
|-----------|-------------|
| `AudioListener` | Marks an entity as the spatial audio receiver |
| `AudioSource` | Marks an entity as a spatial audio emitter |

## Platform Notes

- **Windows/macOS/Linux**: Full support via flutter_soloud FFI
- **iOS/Android**: Full support via flutter_soloud
- **Web**: Limited support (uses WebAudio backend)

## See Also

- [Plugins Overview](/docs/plugins/overview) - Plugin system introduction
- [Window Management](/docs/plugins/window) - Pause audio on focus loss integration
- [App & Plugins Guide](/docs/guides/app-plugins) - Plugin architecture details
