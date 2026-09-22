## 0.3.0

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

# Changelog

## [0.2.2] - 2026-09-21



## [0.2.1] - 2026-09-20

### Added

- `example/example.dart` demonstrating the package's core API (pana requirement).

### Changed

- SDK floor bumped to Dart `>=3.11.0` / Flutter `>=3.41.0` (was 3.6 / 3.38). Matches the workspace-wide floor.


## [0.2.0] - 2026-09-20

### Added

- Initial release.
- CPU-driven emitter with object pooling.
- Preset library for common effects.
- Renders through `DrawLayer.particles`.


## [0.1.0]

### Features

- Initial release of `fledge_particles`.
- `Particle` value class with position/velocity/acceleration, lifetime,
  color-start/end interpolation, and size ramping.
- `ParticlePool` — fixed-capacity pool that recycles `Particle` objects
  to minimize GC pressure.
- `ParticleEmitter` component + `ParticleTemplate` recipe with
  randomizable ranges for lifetime, velocity, size, and angular velocity.
- Three systems wired with explicit `before:` / `after:` ordering:
  - `ParticleEmitSystem` (`Schedules.update`) spawns new particles.
  - `ParticleUpdateSystem` (`Schedules.update`) advances live particles.
  - `ParticleReapSystem` (`Schedules.postUpdate`) reclaims dead particles.
- `ParticleExtractor` — reuses `ExtractedSprite` so particles slot into
  the existing sprite render path via the reserved
  `DrawLayer.particles` sort range.
- Presets: `ParticleEmitter.fire`, `.smoke`, `.spark`, `.trail`.
- `ParticlePlugin` — one-line install alongside `RenderPlugin`.
