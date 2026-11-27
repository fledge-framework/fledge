# Particles

`fledge_particles` is a CPU particle system: emitter components, particle
templates, fixed-size pools and presets for fire, smoke, sparks and trails.
Particles are drawn through the sprite pipeline, as `ExtractedSprite`s in the
`DrawLayer.particles` band, so they sort with the rest of your 2D content.

```yaml
dependencies:
  fledge_render_2d: ^0.7.1
  fledge_particles: ^0.7.1
```

Flutter 3.50+ (Dart 3.14+); desktop first, web and mobile best-effort.
Setup:

- Add `RenderPlugin`, in either order. If it comes after `ParticlePlugin`,
  the particle extractor registers itself on the first tick (a startup
  system named `ParticlePlugin.registerExtractorSystemName`). Without
  `RenderPlugin` at all, the particles simulate but aren't drawn, which
  suits headless tests.
- Add `WallTimePlugin`: the particle systems advance by `WallTime.delta`, and
  without it nothing emits or moves.

<!-- snippet-setup
import 'package:vector_math/vector_math.dart';

late World world;
late Entity torch;
late TextureHandle dotTexture;
-->

## Quick start

```dart
final app = App()
  ..addPlugin(WallTimePlugin())
  ..addPlugin(RenderPlugin())
  ..addPlugin(const ParticlePlugin())
  ..addSystem(TransformPropagateSystem(), schedule: Schedules.preUpdate);

// A campfire at (200, 200), using a small soft dot texture.
app.world.spawn()
  ..insert(Transform2D.from(200, 200))
  ..insert(GlobalTransform2D())
  ..insert(ParticleEmitterPresets.fire(texture: dotTexture));
```

Each particle is a square `size` world units wide, drawn with the whole
texture (its full rect) tinted by the particle's colour. `kSolidColorTexture`
gives plain squares (register it first: see
[The solid-colour pixel](/docs/rendering/sprites-animation#the-solid-colour-pixel)).

## What ParticlePlugin adds

| System | Schedule | Does |
|---|---|---|
| `ParticleEmitSystem` | `update` | Spawns particles from each active emitter. |
| `ParticleUpdateSystem` | `update`, after emit | Moves, rotates and ages live particles. |
| `ParticleReapSystem` | `postUpdate` | Returns dead particles to their pools. |

And `ParticleExtractor`, which adds every live particle to the render world.
Order your own systems with `ParticleEmitSystem.systemName`,
`ParticleUpdateSystem.systemName` and `ParticleReapSystem.systemName`.

## Templates

A `ParticleTemplate` is the recipe for one particle: random ranges for
lifetime, velocity, size and spin, plus colours and a constant acceleration.
Templates aren't changed by spawning, so many emitters can share one.
(`Vector2` isn't const, so neither is a template that uses it.)

```dart
final embers = ParticleTemplate(
  lifetimeMin: 0.6,
  lifetimeMax: 1.2,
  velocityMin: Vector2(-12, -80), // each axis drawn uniformly in [min, max]
  velocityMax: Vector2(12, -40),
  acceleration: Vector2(0, -10),  // units/s²; y points down
  sizeMin: 6,
  sizeMax: 10,
  sizeStartToEnd: 0.2,            // shrinks to 20 % by the end of its life
  colorStart: const Color(0xFFFFC060),
  colorEnd: const Color(0x00E03020),
  colorHold: 0.3,                 // keep colorStart for 30 % of its life
  angularVelocityMin: -1,
  angularVelocityMax: 1,
);
```

A particle's colour goes from `colorStart` to `colorEnd` over its life, after
holding `colorStart` for the first `colorHold` share of it; its size goes from
`size` to `size × sizeStartToEnd`.

## Emitters

`ParticleEmitter` is a component. Put it on an entity with a
`GlobalTransform2D`; particles spawn at that world position and then move on
their own in world space (they don't follow the emitter afterwards).

```dart
void spawnEmbers(World world, ParticleTemplate embers) {
  world.spawn()
    ..insert(Transform2D.from(200, 200))
    ..insert(GlobalTransform2D())
    ..insert(ParticleEmitter(
      template: embers,
      emitRate: 60,             // particles per second; 0 = none
      texture: dotTexture,
      pool: ParticlePool(128),  // at most 128 alive at once
      layer: DrawLayer.particles,
      layerSubOrder: 0,         // 0 = y-sorted inside the layer
      maxDuration: 2,           // stop emitting after 2 s (null = forever)
      rng: math.Random(42),     // optional, for repeatable effects
    ));
}
```

- `emitRate`, `isActive` and `maxDuration` are mutable. Setting `isActive`
  to false (or `emitRate` to 0) stops new particles; live ones finish their
  lives. `canEmit` tells you whether it's emitting.
- `elapsedSinceStart` counts up from spawn and is what `maxDuration` is
  compared against; set it back to 0 to restart a finished emitter.
- Despawning the entity removes its particles at once: the pool belongs to
  the component.

### Bursts

For impacts and pickups, give an emitter `emitRate: 0` and call `burst`. It
spawns up to `count` particles at `origin` immediately, ignoring `emitRate`,
`isActive` and `maxDuration`, and returns how many it spawned (fewer when the
pool fills):

```dart
final chips = world.get<ParticleEmitter>(torch)!;
chips.burst(12, Vector2(320, 180));
```

## Pools

`ParticlePool(capacity)` holds a fixed number of slots. Particle objects are
created the first time a slot is used and reused after that, from a free list,
so a busy emitter allocates almost nothing per frame. When the pool is full,
new particles are dropped (`spawn` returns `null`, `isFull` is true); the
emitter doesn't queue them up for later. `liveCount` and `live` (the living
particles, in no particular order) are there for debugging and custom
drawing. Two emitters can share a template but not a pool.

## Presets

`ParticleEmitterPresets` builds ready-made emitters. Each takes a required
`texture` plus `emitRate`, `capacity`, `layer`, `layerSubOrder` and `rng`:

| Preset | Default rate / capacity | Looks like |
|---|---|---|
| `ParticleEmitterPresets.fire(...)` | 60/s, 128 | Orange flames rising and shrinking. |
| `ParticleEmitterPresets.smoke(...)` | 20/s, 96 | Grey puffs rising slowly and growing. |
| `ParticleEmitterPresets.spark(...)` | 200/s, 64 | Short-lived bright sparks thrown out and falling. |
| `ParticleEmitterPresets.trail(...)` | 45/s, 80 | Pale blue dots that shrink away; put it on a moving entity. |

```dart
world.spawn()
  ..insert(Transform2D.from(80, 120))
  ..insert(GlobalTransform2D())
  ..insert(ParticleEmitterPresets.smoke(
    texture: dotTexture,
    emitRate: 10,
    capacity: 48,
    layer: DrawLayer.foreground,
  ));
```

## Drawing details

- Particles use the sprite convention for sort keys: y-sorted inside their
  layer unless `layerSubOrder` is set, so a particle and a sprite in the same
  layer interleave by y.
- Particles well outside the camera's view are skipped: each one is checked
  against `ActiveCameraView.visibleWorldRect`, widened by
  `ParticleExtractor.cullMargin` (64 world units, the same as sprites) plus
  the particle's size. Without a camera view (headless, tests, before the
  first paint) every live particle is extracted.
- They can't be emissive, so a `LightingPlugin` light map darkens them like
  any other sprite.
- Everything happens on the CPU. Particles sharing a texture and drawn
  next to each other batch into one `drawRawAtlas` call.

See the [API reference](https://pub.dev/documentation/fledge_particles/latest/)
for every member.
