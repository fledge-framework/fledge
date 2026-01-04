# Changelog

## [0.1.5] - 2026-01-04



## [0.1.4] - 2026-01-04



## [0.1.3] - 2026-01-04

## [Unreleased]

### Bug Fixes

- **fledge_render_2d:** Fix null safety error on private field

### Features

- **fledge_tiled:** Refactor TilemapSpawnConfig API



## [0.1.2] - 2026-01-03

## [Unreleased]

### Bug Fixes

- Update dependencies to latest stable versions
- **fledge:** Update dependencies, upgrade melos to v7

### Miscellaneous

- **license:** Remove whitespace from license files
- Update license text
- Bump versions



All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
