# Changelog

## [0.2.2] - 2026-09-21



## [0.2.1] - 2026-09-20

### Changed

- Widened `flutter_soloud` constraint to `>=4.0.0 <6.0.0` (was `^3.4.8`) so pub can resolve the current stable 4.x/5.x line. The 4.0.0 release made `SoLoud.play`, `play3d`, and `speechText` synchronous (return `SoundHandle` directly instead of `Future<SoundHandle>`); the internal call sites in `audio_event_system.dart` and `spatial_audio_system.dart` no longer `await` them.
- SDK floor bumped to Dart `>=3.11.0` / Flutter `>=3.41.0` (was 3.6 / 3.38). Required by `flutter_soloud` 4.x+ and the workspace-wide floor.


## [0.2.0] - 2026-09-20

### Added

- `AudioClip` asset + `Assets<AudioClip>` storage.

### Changed

- Consumer migration to the new `schedule:` API.

### Deprecated

- `AudioAssets` — use `Assets<AudioClip>`.


## [0.1.14] - 2026-04-14

## [0.1.13] - 2026-04-14



## [0.1.12] - 2026-04-14



## [0.1.11] - 2026-01-21



## [0.1.10] - 2026-01-06

## [0.1.9] - 2026-01-06



## [0.1.8] - 2026-01-06



## [0.1.7] - 2026-01-05

## [0.1.7] - 2026-01-05

### Miscellaneous

- Bump dependencies



## [0.1.6] - 2026-01-05



## [0.1.5] - 2026-01-04



## [0.1.4] - 2026-01-04



## [0.1.3] - 2026-01-04

## [0.1.2] - 2026-01-03

## [0.1.0] - 2025-01-02

### Added

- Initial release of fledge_audio
- Background music playback with crossfading
- Sound effect playback with volume control
- AudioAssets resource for loading and managing audio files
- World extension methods for playing audio (playSfx, playMusic)
- AudioChannels for volume control (master, music, sfx, voice, ambient)
- AudioListener component for spatial audio
- AudioSource component for positional audio entities
- Automatic pause on window focus loss
