# Changelog

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
