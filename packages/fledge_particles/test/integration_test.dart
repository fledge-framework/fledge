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
      final count = rw.extractedSpriteCount;
      expect(count, greaterThan(0));
      // Every extracted particle should sit inside the DrawLayer.particles
      // sort range.
      for (final sprite in rw.extractedSprites) {
        expect(sprite.layer, DrawLayer.particles);
        // The quad is the particle's size; the transform doesn't scale it
        // again (the pipeline multiplies the two).
        expect(sprite.size, Vector2(4, 4));
        final m = sprite.transform.storage;
        expect(math.sqrt(m[0] * m[0] + m[1] * m[1]), closeTo(1, 1e-9));
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

  test(
    'particles beyond the packed y window still carry a precise sub-order',
    () async {
      // y * ySortScale clamps at y = 9,999.9, so the integer keys tie;
      // the unclamped preciseSubOrder breaks the tie by position.
      final app = App()
        ..insertResource<WallTime>(WallTime())
        ..addPlugin(RenderPlugin())
        ..addPlugin(const ParticlePlugin());
      app.world.spawn()
        ..insert(
          GlobalTransform2D(
            Matrix3.identity()..setColumn(2, Vector3(0, 20000, 1)),
          ),
        )
        ..insert(
          ParticleEmitter(
            template: _shortTemplate(),
            emitRate: 50.0,
            texture: _tex(),
            pool: ParticlePool(16),
            rng: math.Random(1),
          ),
        );
      final time = app.world.getResource<WallTime>()!;
      for (var i = 0; i < 3; i++) {
        time.delta = 0.05;
        await app.tick();
      }

      final sprites = [
        for (final s in app.world.getResource<RenderWorld>()!.extractedSprites)
          s,
      ];
      expect(sprites, isNotEmpty);
      for (final s in sprites) {
        expect(s.sortKey, DrawLayer.particles.sortKey(subOrder: 99999));
        expect(s.preciseSubOrder, isNotNull);
        expect(
          s.preciseSubOrder!,
          greaterThan(19000 * DrawLayerExtension.ySortScale),
        );
      }
    },
  );

  group('particles share the sprite y-sort convention', () {
    ExtractedSprite extractParticleAt(double y, {int layerSubOrder = 0}) {
      final world = World();
      final pool = ParticlePool(1)
        ..spawn(
          position: Vector2(0, y),
          velocity: Vector2.zero(),
          maxLifetime: 1,
          colorStart: const Color(0xFFFFFFFF),
          colorEnd: const Color(0xFFFFFFFF),
        );
      world.spawn()
        ..insert(GlobalTransform2D.identity())
        ..insert(
          ParticleEmitter(
            template: _shortTemplate(),
            emitRate: 0,
            texture: _tex(),
            pool: pool,
            layer: DrawLayer.characters,
            layerSubOrder: layerSubOrder,
          ),
        );
      final rw = RenderWorld();
      ParticleExtractor().extract(world, rw);
      return rw.extractedSprites.single;
    }

    ExtractedSprite extractSpriteAt(double y) {
      final world = World();
      world.spawn()
        ..insert(Sprite(texture: _tex()))
        ..insert(GlobalTransform2D(Matrix3.identity()..setEntry(1, 2, y)));
      final rw = RenderWorld();
      SpriteExtractor().extract(world, rw);
      return rw.extractedSprites.single;
    }

    test('particle at y=100 sorts between sprites at y=99 and y=101', () {
      final above = extractSpriteAt(99);
      final particle = extractParticleAt(100);
      final below = extractSpriteAt(101);
      final sorted = [below, particle, above];
      ExtractedSprite.sortByDrawOrder(sorted);
      expect(sorted, [above, particle, below]);
      // Integer keys alone already agree (same units as sprites).
      expect(particle.sortKey, greaterThan(above.sortKey));
      expect(particle.sortKey, lessThan(below.sortKey));
    });

    test('particle and sprite at equal y produce equal sort keys', () {
      for (final y in [0.0, 100.0, 1234.56, 20000.0, -50.0]) {
        final particle = extractParticleAt(y);
        final sprite = extractSpriteAt(y);
        expect(particle.sortKey, sprite.sortKey, reason: 'y = $y');
        expect(
          particle.preciseSubOrder,
          sprite.preciseSubOrder,
          reason: 'y = $y',
        );
        expect(ExtractedSprite.compareDrawOrder(particle, sprite), 0);
      }
    });

    test('sub-order matches DrawLayerExtension.ySortSubOrder', () {
      final particle = extractParticleAt(123.45);
      expect(
        particle.sortKey,
        DrawLayer.characters.sortKey(
          subOrder: DrawLayerExtension.ySortSubOrder(123.45),
        ),
      );
      expect(
        particle.preciseSubOrder,
        // Vector2 is float32, hence the tolerance.
        closeTo(123.45 * DrawLayerExtension.ySortScale, 1e-3),
      );
    });

    test('explicit layerSubOrder carries no precise sub-order', () {
      final particle = extractParticleAt(100, layerSubOrder: 7);
      expect(particle.sortKey, DrawLayer.characters.sortKey(subOrder: 7));
      expect(particle.preciseSubOrder, isNull);
    });
  });
}
