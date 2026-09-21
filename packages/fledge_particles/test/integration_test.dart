import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_particles/fledge_particles.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

TextureHandle _tex() => const TextureHandle(id: 7, width: 4, height: 4);

ParticleTemplate _shortTemplate() => ParticleTemplate(
  lifetimeMin: 0.2,
  lifetimeMax: 0.2,
  velocityMin: Vector2(0, -10),
  velocityMax: Vector2(0, -10),
  acceleration: Vector2.zero(),
  sizeMin: 4,
  sizeMax: 4,
  colorStart: const Color(0xFFFFFFFF),
  colorEnd: const Color(0x00FFFFFF),
);

void main() {
  test('ParticlePlugin spawns and reaps particles across ticks', () async {
    // Deliberately skip WallTimePlugin so `WallTime.delta` isn't
    // overwritten by WallTimeUpdateSystem each frame — we insert a
    // WallTime resource directly and drive the delta ourselves for
    // deterministic assertions.
    final app = App()
      ..insertResource<WallTime>(WallTime())
      ..addPlugin(RenderPlugin())
      ..addPlugin(const ParticlePlugin());

    final pool = ParticlePool(32);
    final emitter = ParticleEmitter(
      template: _shortTemplate(),
      emitRate: 20.0,
      texture: _tex(),
      pool: pool,
      rng: math.Random(1),
    );
    app.world.spawn()
      ..insert(GlobalTransform2D.identity())
      ..insert(emitter);

    final time = app.world.getResource<WallTime>()!;

    // Run 20 ticks at 0.05s each = 1s total. At emitRate=20 that's
    // ~20 spawns, but the lifetime is 0.2s so particles die and get
    // reaped continuously; the pool should never exceed the emit cap
    // and should always have some live particles after warm-up.
    var maxSeen = 0;
    for (var i = 0; i < 20; i++) {
      time.delta = 0.05;
      await app.tick();
      if (pool.liveCount > maxSeen) maxSeen = pool.liveCount;
    }
    expect(maxSeen, greaterThan(0));
    expect(pool.liveCount, greaterThan(0));

    // Stopping the emitter and running long enough should reap
    // everything.
    emitter.isActive = false;
    for (var i = 0; i < 10; i++) {
      time.delta = 0.05;
      await app.tick();
    }
    expect(pool.liveCount, 0);
  });

  test('checkScheduleOrdering is empty for a ParticlePlugin-only app', () {
    final app = App()..addPlugin(const ParticlePlugin());
    // No WallTimePlugin, no RenderPlugin — a bare ParticlePlugin should
    // still be self-consistent under the ordering checker.
    expect(app.checkScheduleOrdering(), isEmpty);
  });

  test(
    'ParticleExtractor produces ExtractedSprite entries in render world',
    () async {
      final app = App()
        ..insertResource<WallTime>(WallTime())
        ..addPlugin(RenderPlugin())
        ..addPlugin(const ParticlePlugin());

      final emitter = ParticleEmitter(
        template: _shortTemplate(),
        emitRate: 50.0,
        texture: _tex(),
        pool: ParticlePool(16),
        rng: math.Random(1),
      );
      app.world.spawn()
        ..insert(GlobalTransform2D.identity())
        ..insert(emitter);

      final time = app.world.getResource<WallTime>()!;
      for (var i = 0; i < 5; i++) {
        time.delta = 0.05;
        await app.tick();
      }

      final rw = app.world.getResource<RenderWorld>()!;
      final count = rw.query1<ExtractedSprite>().iter().length;
      expect(count, greaterThan(0));
      // Every extracted particle should sit inside the DrawLayer.particles
      // sort range.
      for (final (_, sprite) in rw.query1<ExtractedSprite>().iter()) {
        expect(sprite.layer, DrawLayer.particles);
        expect(
          sprite.sortKey,
          greaterThanOrEqualTo(
            DrawLayer.particles.index * DrawLayerExtension.layerMultiplier,
          ),
        );
        expect(
          sprite.sortKey,
          lessThan(
            (DrawLayer.particles.index + 1) *
                DrawLayerExtension.layerMultiplier,
          ),
        );
      }
    },
  );
}
