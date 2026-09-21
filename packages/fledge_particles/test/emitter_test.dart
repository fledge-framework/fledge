import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_particles/fledge_particles.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

TextureHandle _tex() => const TextureHandle(id: 1, width: 16, height: 16);

ParticleTemplate _template() => ParticleTemplate(
      lifetimeMin: 1.0,
      lifetimeMax: 1.0,
      velocityMin: Vector2.zero(),
      velocityMax: Vector2.zero(),
      acceleration: Vector2.zero(),
      sizeMin: 4,
      sizeMax: 4,
      colorStart: const Color(0xFFFFFFFF),
      colorEnd: const Color(0x00FFFFFF),
    );

/// Build a world with a WallTime resource driving frame delta and a
/// single emitter entity. Returns the entity and emitter for further
/// tweaks.
({World world, Entity entity, ParticleEmitter emitter}) buildWorld({
  double emitRate = 10.0,
  int capacity = 32,
  double? maxDuration,
  bool isActive = true,
  math.Random? rng,
}) {
  final world = World();
  final time = WallTime();
  world.insertResource<WallTime>(time);

  final emitter = ParticleEmitter(
    template: _template(),
    emitRate: emitRate,
    texture: _tex(),
    pool: ParticlePool(capacity),
    maxDuration: maxDuration,
    isActive: isActive,
    rng: rng ?? math.Random(1234),
  );
  final entity = (world.spawn()
        ..insert(GlobalTransform2D.identity())
        ..insert(emitter))
      .entity;
  return (world: world, entity: entity, emitter: emitter);
}

/// Advance the world by [dt] seconds and run the three particle
/// systems in schedule order (emit → update, then reap).
Future<void> tick(World world, double dt) async {
  world.getResource<WallTime>()!.delta = dt;
  await ParticleEmitSystem().run(world);
  await ParticleUpdateSystem().run(world);
  await ParticleReapSystem().run(world);
}

void main() {
  group('ParticleEmitSystem', () {
    test('emitRate produces roughly rate*seconds particles', () async {
      final (:world, entity: _, :emitter) = buildWorld(emitRate: 10);
      // Ten frames at 0.1s each = 1s total = 10 particles.
      for (var i = 0; i < 10; i++) {
        // We only want to observe emission, not reap, so we skip
        // ParticleReapSystem here. Update still runs so we're
        // exercising the full "particles get advanced" path.
        world.getResource<WallTime>()!.delta = 0.1;
        await ParticleEmitSystem().run(world);
        await ParticleUpdateSystem().run(world);
      }
      expect(emitter.pool.liveCount, 10);
    });

    test('isActive=false stops emission but preserves live particles',
        () async {
      final (:world, entity: _, :emitter) = buildWorld(emitRate: 20);
      // Seed a few particles first.
      await tick(world, 0.1);
      final beforePause = emitter.pool.liveCount;
      expect(beforePause, greaterThan(0));

      emitter.isActive = false;
      // Advance a few frames — no new particles should appear.
      for (var i = 0; i < 3; i++) {
        world.getResource<WallTime>()!.delta = 0.1;
        await ParticleEmitSystem().run(world);
      }
      expect(emitter.pool.liveCount, beforePause);
    });

    test('maxDuration stops emission but existing particles live on', () async {
      final (:world, entity: _, :emitter) = buildWorld(
        emitRate: 20,
        maxDuration: 0.5,
      );

      // Half a second's worth of emission (~10 particles at rate 20).
      for (var i = 0; i < 5; i++) {
        world.getResource<WallTime>()!.delta = 0.1;
        await ParticleEmitSystem().run(world);
      }
      final atCap = emitter.pool.liveCount;

      // Now push past maxDuration. No new particles should spawn.
      for (var i = 0; i < 5; i++) {
        world.getResource<WallTime>()!.delta = 0.1;
        await ParticleEmitSystem().run(world);
      }
      expect(emitter.pool.liveCount, atCap);
      // Sanity: canEmit reports the stopped state.
      expect(emitter.canEmit, isFalse);
    });

    test('accumulator carries fractional emissions across frames', () async {
      // 5/s at 0.1s = 0.5 particles/frame. Two frames → 1 particle;
      // four frames → 2 particles.
      final (:world, entity: _, :emitter) = buildWorld(emitRate: 5);
      world.getResource<WallTime>()!.delta = 0.1;
      await ParticleEmitSystem().run(world);
      expect(emitter.pool.liveCount, 0);
      await ParticleEmitSystem().run(world);
      expect(emitter.pool.liveCount, 1);
      await ParticleEmitSystem().run(world);
      expect(emitter.pool.liveCount, 1);
      await ParticleEmitSystem().run(world);
      expect(emitter.pool.liveCount, 2);
    });
  });

  group('ParticleUpdateSystem', () {
    test('advances position by velocity*dt', () async {
      final world = World();
      world.insertResource<WallTime>(WallTime());

      // Fixed template with a known velocity so we can assert the step.
      final template = ParticleTemplate(
        lifetimeMin: 10.0,
        lifetimeMax: 10.0,
        velocityMin: Vector2(100, 0),
        velocityMax: Vector2(100, 0),
        acceleration: Vector2.zero(),
        sizeMin: 1,
        sizeMax: 1,
        colorStart: const Color(0xFFFFFFFF),
        colorEnd: const Color(0xFFFFFFFF),
      );
      final emitter = ParticleEmitter(
        template: template,
        emitRate: 0, // We'll spawn manually.
        texture: _tex(),
        pool: ParticlePool(4),
        rng: math.Random(1),
      );
      world.spawn()
        ..insert(GlobalTransform2D.identity())
        ..insert(emitter);

      // Manually seed one particle.
      template.spawnInto(
        emitter.pool,
        origin: Vector2.zero(),
        rng: math.Random(1),
      );

      world.getResource<WallTime>()!.delta = 0.1;
      await ParticleUpdateSystem().run(world);

      final p = emitter.pool.live.first;
      expect(p.position.x, closeTo(10.0, 1e-9));
      expect(p.lifetime, closeTo(0.1, 1e-9));
    });

    test('reaps dead particles', () async {
      final (:world, entity: _, :emitter) = buildWorld(emitRate: 0);
      // Manually spawn a short-lived particle.
      emitter.pool.spawn(
        position: Vector2.zero(),
        velocity: Vector2.zero(),
        maxLifetime: 0.05,
        colorStart: const Color(0xFFFFFFFF),
        colorEnd: const Color(0x00FFFFFF),
      );
      expect(emitter.pool.liveCount, 1);

      // One 0.1s tick — particle should age out and be reaped.
      await tick(world, 0.1);
      expect(emitter.pool.liveCount, 0);
    });
  });
}
