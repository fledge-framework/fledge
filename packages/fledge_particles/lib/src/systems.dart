import 'dart:math' as math;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart' show GlobalTransform2D;

import 'emitter.dart';
import 'particle.dart';

/// Shared fallback RNG for emitters that don't supply their own.
///
/// Seeded implicitly by `dart:math` — deterministic runs should supply
/// a per-emitter [math.Random] via [ParticleEmitter.rng].
final math.Random _defaultRng = math.Random();

/// System that spawns new particles from every active
/// [ParticleEmitter] in the world.
///
/// Advances each emitter's fractional accumulator by
/// `emitRate * delta` seconds, then spawns one particle per whole unit
/// accumulated. Emitters whose [ParticleEmitter.canEmit] is false skip
/// the spawn phase, but their internal clock still ticks so
/// [ParticleEmitter.maxDuration] resolves correctly.
///
/// Runs in `Schedules.update` before [ParticleUpdateSystem] so
/// newly-spawned particles get their first integration step this
/// frame.
class ParticleEmitSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'ParticleEmitSystem',
        writes: {ComponentId.of<ParticleEmitter>()},
        reads: {ComponentId.of<GlobalTransform2D>()},
        resourceReads: const {WallTime},
        before: const ['ParticleUpdateSystem', 'ParticleReapSystem'],
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    final delta = _frameDelta(world);
    for (final (_, emitter, transform)
        in world.query2<ParticleEmitter, GlobalTransform2D>().iter()) {
      emitter.elapsedSinceStart += delta;

      if (!emitter.canEmit || emitter.emitRate <= 0.0) {
        continue;
      }

      emitter.emitAccumulator += emitter.emitRate * delta;

      // Nothing to do this frame — keep the fractional accumulator for
      // the next tick and move on.
      if (emitter.emitAccumulator < 1.0) continue;

      final rng = emitter.rng ?? _defaultRng;
      final origin = transform.translation;

      var toSpawn = emitter.emitAccumulator.floor();
      // Consume the whole units from the accumulator regardless of
      // whether the pool has room — otherwise a saturated pool would
      // race the accumulator up unboundedly.
      emitter.emitAccumulator -= toSpawn;

      while (toSpawn > 0 && !emitter.pool.isFull) {
        emitter.template.spawnInto(emitter.pool, origin: origin, rng: rng);
        toSpawn--;
      }
    }
    return Future.value();
  }

  double _frameDelta(World world) {
    final time = world.getResource<WallTime>();
    return time?.delta ?? 0.0;
  }
}

/// System that advances every live particle by the current frame's
/// delta.
///
/// Integrates position/velocity semi-implicitly (velocity is advanced
/// first, then position uses the new velocity) and advances lifetime
/// and rotation. Dead particles are left in place for
/// [ParticleReapSystem] to reclaim in `Schedules.postUpdate`.
class ParticleUpdateSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'ParticleUpdateSystem',
        writes: {ComponentId.of<ParticleEmitter>()},
        resourceReads: const {WallTime},
        after: const ['ParticleEmitSystem'],
        before: const ['ParticleReapSystem'],
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    final delta = _frameDelta(world);
    if (delta <= 0.0) return Future.value();

    for (final (_, emitter) in world.query1<ParticleEmitter>().iter()) {
      for (final p in emitter.pool.live) {
        _advance(p, delta);
      }
    }
    return Future.value();
  }

  static void _advance(Particle p, double delta) {
    // Semi-implicit Euler: velocity gets the acceleration step first,
    // then position uses the new velocity. Simple, stable for small
    // timesteps, and matches how physics-adjacent systems in the
    // workspace already integrate.
    p.velocity.x += p.acceleration.x * delta;
    p.velocity.y += p.acceleration.y * delta;
    p.position.x += p.velocity.x * delta;
    p.position.y += p.velocity.y * delta;
    p.rotation += p.angularVelocity * delta;
    p.lifetime += delta;
  }

  double _frameDelta(World world) {
    final time = world.getResource<WallTime>();
    return time?.delta ?? 0.0;
  }
}

/// System that reclaims dead particles from every emitter's pool.
///
/// Runs in `Schedules.postUpdate` after the emit/update pair in
/// `Schedules.update`, so extraction in `Schedules.extract` sees a
/// pool that contains only live particles (aside from the small dead
/// window between update and reap, which the extractor filters
/// anyway).
class ParticleReapSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'ParticleReapSystem',
        writes: {ComponentId.of<ParticleEmitter>()},
        after: const ['ParticleEmitSystem', 'ParticleUpdateSystem'],
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    for (final (_, emitter) in world.query1<ParticleEmitter>().iter()) {
      emitter.pool.reap();
    }
    return Future.value();
  }
}
