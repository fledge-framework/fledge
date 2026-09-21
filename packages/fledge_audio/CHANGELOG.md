# Changelog

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
