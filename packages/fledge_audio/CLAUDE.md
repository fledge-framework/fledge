# fledge_audio

## Purpose
Music and sound effects with volume channels, crossfading, and spatial audio via SoLoud backend.

## Status: Functional

## Stats
- Source: 17 files, ~1,840 LOC
- Tests: 3 files (volume-channel fade, spatial attenuation math, schedule ordering)
- TODOs in code: 0

## What Works
- Volume channels (master, music, SFX, voice, ambient) with independent control
- Per-channel linear volume fades (`VolumeChannels.fadeTo`) ticked by `ChannelFadeSystem`
- Music crossfading between tracks
- Spatial audio: listener/source positions read from `Transform2D`, linear distance attenuation, lateral stereo pan
- Audio asset loading and management
- Event-driven audio commands (play, stop, fade)
- Audio focus system (pause/resume on app focus changes)
- SoLoud backend integration

## Gaps
- **[P1]** No playback-level integration tests (SoLoud FFI makes these awkward; current tests cover pure logic only)
- **[P2]** `MusicCrossfadeSystem` doesn't re-sample channel volume mid-crossfade, so a simultaneous `music`-channel fade doesn't affect in-flight crossfades

## Action Items
1. Add integration tests around SoLoud init/play once a headless harness exists
2. Make music crossfade re-evaluate channel volume each frame for consistency with channel fades

## Architecture Notes
- **Entry point**: `lib/fledge_audio.dart` (barrel export)
- **AudioPlugin** (`lib/src/plugin.dart`): Takes an `AudioConfig` (`lib/src/config/`). Registers request/response events, inserts `AudioConfig`, `SpatialAudioConfig`, and `VolumeChannels`. `AudioAssets`/`AudioState`/`Assets<AudioClip>` are inserted later by `AudioInitSystem` once SoLoud is up. Crossfading needs `WallTimePlugin` (from `fledge_ecs`).
- **Components**: `AudioSource` (emitter on an entity) and `AudioListener` (receiver, typically on camera/player).
- **Resources**: `VolumeChannels` (`lib/src/resources/audio_channels.dart`, volume per `AudioChannel` + fades), `AudioState` (active handles, backend state), `AudioAssets`.
- **Systems** (`lib/src/systems/`), by schedule:
  - `Schedules.first`, all in the `FirstSets.platform` phase: `AudioInitSystem` (initializes SoLoud; not exclusive — declares `resourceWrites` for `Assets<AudioClip>`, `AudioAssets`, `AudioState`), `AudioEventSystem` (after `AudioInitSystem`; processes play/stop/volume requests, delegates volume fades to `VolumeChannels.fadeTo`), `AudioFocusSystem` (after `AudioInitSystem` and `AudioEventSystem`; pauses on focus loss; only when `config.pauseOnFocusLoss`)
  - `Schedules.update`: `ChannelFadeSystem` (advances per-channel fades), `MusicCrossfadeSystem` (track transitions)
  - `Schedules.last`: `SpatialAudioSystem` (only when `spatialConfig.enabled`; queries `(AudioListener, Transform2D)` and `(AudioSource, Transform2D)` for attenuation + pan; lives in `last` so every per-frame `Transform2D` writer — physics, camera follow/shake/parallax, game movement — has run; `before: [AudioCleanupSystem.systemName]`), `AudioCleanupSystem` (releases finished handles)
  - Every system exposes `static const String systemName` (= class name); all in-package `before:`/`after:` use those constants.
- **Events** (`lib/src/events/audio_events.dart`): Request types (`PlaySfxRequest`, `PlayMusicRequest`, `StopMusicRequest`, `SetChannelVolumeRequest`, …) and responses (`SfxStarted`, `MusicChanged`, `AudioFailed`, …). Double-buffered command/response pattern.
- **Commands** (`lib/src/commands/audio_commands.dart`): `AudioCommands` extension on `World` (`playSfx`, `playMusic`, `setVolume`, …) that writes the request events.
- **Assets** (`lib/src/assets/`): `AudioAssets`, `AudioClip` + `AudioClipLoader` for loading and caching.
- **Tests**: Flutter package — run with `flutter test`. `test/ordering_test.dart` asserts `checkScheduleOrdering()` is empty for the default and non-spatial configs.
- **Volume cascade**: Effective volume = master × channel volume. Channels: master, music, sfx, voice, ambient.
- **Backend**: Uses `flutter_soloud` FFI bindings. Sound handles tracked in active set, cleaned up each frame.
