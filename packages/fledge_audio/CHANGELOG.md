## 0.3.0

 - **FIX**: bump lower bound of fledge_audio. ([1198dd84](https://github.com/fledge-framework/fledge/commit/1198dd8466d6d92b11ebc5b9127e6ce66c92edab))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_tiled): refactor TilemapSpawnConfig API. ([35b12d1e](https://github.com/fledge-framework/fledge/commit/35b12d1eaa72f7e703f6820b4e0f8d69452f509e))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))

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
