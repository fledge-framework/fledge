# Particles

The `fledge_particles` plugin provides a CPU-driven particle system for Fledge games — emitter components, template recipes, pooled particle instances, and factory presets for common effects (fire, smoke, spark, trail).

Particle output is extracted as `ExtractedSprite` and drawn through the existing sprite render path in the reserved `DrawLayer.particles` sort range, so particles composite correctly against your other 2D content without a bespoke render node.

## Installation

```yaml
dependencies:
  fledge_particles: ^0.1.0
```

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_particles/fledge_particles.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';

Future<void> main() async {
  final app = App()
    ..addPlugin(WallTimePlugin())
    ..addPlugin(RenderPlugin())
    ..addPlugin(const ParticlePlugin());

  // A campfire.
  app.world.spawn()
    ..insert(Transform2D.from(200, 200))
    ..insert(GlobalTransform2D.identity())
    ..insert(ParticleEmitterPresets.fire(texture: myParticleTexture));

  await app.run();
}
```

## Core concepts

### ParticleTemplate

A recipe describing how to instantiate a `Particle`. Templates supply randomizable ranges for lifetime, velocity, size, and angular velocity, plus fixed color endpoints and acceleration. A single template can be shared across many emitters — none of its fields are mutated at spawn time.

```dart
const template = ParticleTemplate(
  lifetimeMin: 0.6,
  lifetimeMax: 1.2,
  velocityMin: Vector2(-12, -80),
  velocityMax: Vector2(12, -40),
  acceleration: Vector2(0, -10),   // upward "gravity" for fire
  sizeMin: 6,
  sizeMax: 10,
  sizeStartToEnd: 0.2,             // shrinks to 20% by end of life
  colorStart: Color(0xFFFFC060),   // hot orange
  colorEnd: Color(0x00E03020),     // fades to transparent red
  angularVelocityMin: -1.0,
  angularVelocityMax: 1.0,
);
```

### ParticleEmitter

An emitter attached to an entity — the ECS component that produces particles. Combined with `Transform2D` + `GlobalTransform2D`, `ParticleEmitSystem` spawns new particles at the emitter's world position at `emitRate` particles per second.

```dart
world.spawn()
  ..insert(Transform2D.from(200, 200))
  ..insert(GlobalTransform2D.identity())
  ..insert(ParticleEmitter(
    template: template,
    emitRate: 60.0,           // 60 particles/sec
    texture: sparkTexture,    // atlas or standalone texture
    pool: ParticlePool(128),  // ring buffer of 128 slots
    layer: DrawLayer.particles,
    layerSubOrder: 0,
  ));
```

Toggle at runtime by setting `emitRate` to zero — the pool keeps existing particles alive until they die naturally.

### ParticlePool

A pre-allocated ring buffer of `Particle` instances. Spawning re-uses a dead slot when the pool is full; when every slot is alive, `spawnInto` returns `null` and the emit is dropped that frame. Pool capacity is a fixed per-emitter budget — pick a size proportional to `emitRate * maxLifetime`.

## Presets

`ParticleEmitterPresets` bundles configured emitters for common effects. Each preset returns a fully-configured emitter with a matching template and a modestly-sized pool. Games are expected to override fields for local tweaks.

| Preset | Description |
|--------|-------------|
| `fire` | Orange-to-red flame with upward velocity. Torch, campfire. |
| `smoke` | Gray, slow-drifting, long-lived. Chimney plume, steam. |
| `spark` | Bright, short-lived, falls under gravity. Impact, muzzle flash. |
| `trail` | Motion trails behind fast-moving entities. |

```dart
// Torch — steady flame at 60 particles/sec.
ParticleEmitterPresets.fire(texture: fireTex);

// Candle — same shape, lower density.
ParticleEmitterPresets.fire(texture: fireTex, emitRate: 15.0);

// Sparks from a hit.
ParticleEmitterPresets.spark(texture: sparkTex, capacity: 32);
```

## Systems and scheduler placement

`ParticlePlugin` adds three systems with explicit `before:` / `after:` ordering. `App.checkScheduleOrdering()` returns an empty list for a `ParticlePlugin`-only app.

| System | Schedule | Description |
|--------|----------|-------------|
| `ParticleEmitSystem` | `update` | Spawns new particles at each emitter's world position. |
| `ParticleUpdateSystem` | `update`, after emit | Advances every live particle — position, velocity, color, angular velocity. |
| `ParticleReapSystem` | `postUpdate` | Reclaims dead particles from each emitter's pool. |

`ParticleExtractor` is registered on the shared `Extractors` resource, so particles feed the render world alongside sprites and tiles.

## Rendering

Extracted particles are `ExtractedSprite`s in the reserved `DrawLayer.particles` range (400,000 – 499,999). This means:

- Particles composite between characters and UI layers by default.
- The sprite render path handles them — no special particle shader, no extra draw pass.
- You can override `layer` and `layerSubOrder` on an emitter to shift particles above or below other content (e.g. muzzle-flash sparks above the character).

## Custom effects

Building a new emitter type is a matter of picking randomization ranges and color endpoints:

```dart
final rainDrop = ParticleTemplate(
  lifetimeMin: 1.5,
  lifetimeMax: 2.0,
  velocityMin: Vector2(-5, 200),
  velocityMax: Vector2(5, 260),
  acceleration: Vector2.zero,       // constant velocity
  sizeMin: 1,
  sizeMax: 2,
  sizeStartToEnd: 1.0,
  colorStart: Color(0x80B0D8FF),
  colorEnd: Color(0x00B0D8FF),
);

world.spawn()
  ..insert(Transform2D.from(0, -50))
  ..insert(GlobalTransform2D.identity())
  ..insert(ParticleEmitter(
    template: rainDrop,
    emitRate: 300.0,
    texture: raindropTexture,
    pool: ParticlePool(512),
  ));
```

## Design notes

- **Why CPU, not GPU?** A GPU compute path would scale better past a few thousand particles, but the Canvas backend has no compute primitive today. Ten thousand CPU particles per frame is comfortable on desktop; a compute-shader path is future work when a `flutter_gpu` backend lands.
- **Why per-emitter pools?** A single shared pool means an active fire emitter can starve out a rain emitter's slots. Per-emitter pools give each effect a fixed budget so effects can't visually deprioritise each other.

## Components reference

| Component | Description |
|-----------|-------------|
| `ParticleEmitter` | Attach to a positioned entity to spawn particles from its world transform. |
| `ParticleTemplate` | Recipe for how to spawn one particle. Value type, sharable. |
| `ParticlePool` | Pre-allocated ring buffer of `Particle` instances. |

## See also

- [2D Rendering](/docs/plugins/render) — sprites and layer sorting via `DrawLayer`.
- [Lighting (2D)](/docs/plugins/lighting_2d) — pair with `AmbientLight.dark` and `Light2D` for glow-in-the-dark torches.
- [Plugins Overview](/docs/plugins/overview)
