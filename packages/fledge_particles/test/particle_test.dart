import 'dart:ui' show Color;

import 'package:fledge_particles/fledge_particles.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('Particle', () {
    test('isAlive flips when lifetime reaches maxLifetime', () {
      final p = Particle(
        position: Vector2.zero(),
        velocity: Vector2.zero(),
        maxLifetime: 1.0,
        colorStart: const Color(0xFFFFFFFF),
        colorEnd: const Color(0x00FFFFFF),
      );
      expect(p.isAlive, isTrue);
      p.lifetime = 0.999;
      expect(p.isAlive, isTrue);
      p.lifetime = 1.0;
      expect(p.isAlive, isFalse);
    });

    test('t is clamped into 0..1 and monotone in lifetime', () {
      final p = Particle(
        position: Vector2.zero(),
        velocity: Vector2.zero(),
        maxLifetime: 2.0,
        colorStart: const Color(0xFFFFFFFF),
        colorEnd: const Color(0x00FFFFFF),
      );
      expect(p.t, 0.0);
      p.lifetime = 1.0;
      expect(p.t, closeTo(0.5, 1e-9));
      p.lifetime = 3.0;
      expect(p.t, 1.0);
    });

    test('color interpolates between colorStart and colorEnd', () {
      final p = Particle(
        position: Vector2.zero(),
        velocity: Vector2.zero(),
        maxLifetime: 1.0,
        colorStart: const Color(0xFFFF0000),
        colorEnd: const Color(0xFF0000FF),
      );
      // At t=0, color should be the start color.
      expect(p.color, const Color(0xFFFF0000));

      // At t=1, color should be the end color.
      p.lifetime = 1.0;
      expect(p.color, const Color(0xFF0000FF));
    });

    test('currentSize ramps between size and size*sizeStartToEnd', () {
      final p = Particle(
        position: Vector2.zero(),
        velocity: Vector2.zero(),
        maxLifetime: 1.0,
        size: 10,
        sizeStartToEnd: 0.5,
        colorStart: const Color(0xFFFFFFFF),
        colorEnd: const Color(0xFFFFFFFF),
      );
      expect(p.currentSize, 10.0);
      p.lifetime = 1.0;
      expect(p.currentSize, closeTo(5.0, 1e-9));
      // Halfway through, halfway between endpoints.
      p.lifetime = 0.5;
      expect(p.currentSize, closeTo(7.5, 1e-9));
    });
  });

  group('ParticlePool', () {
    ParticlePool make(int cap) => ParticlePool(cap);

    Particle? spawnOne(ParticlePool pool, {double lifetime = 1.0}) =>
        pool.spawn(
          position: Vector2.zero(),
          velocity: Vector2.zero(),
          maxLifetime: lifetime,
          colorStart: const Color(0xFFFFFFFF),
          colorEnd: const Color(0x00FFFFFF),
        );

    test('initial state: empty and not full', () {
      final pool = make(4);
      expect(pool.liveCount, 0);
      expect(pool.isFull, isFalse);
      expect(pool.live, isEmpty);
    });

    test('spawn increments liveCount and yields a live iterable', () {
      final pool = make(3);
      spawnOne(pool);
      spawnOne(pool);
      expect(pool.liveCount, 2);
      expect(pool.live.length, 2);
    });

    test('spawn returns null when full and reports isFull', () {
      final pool = make(2);
      spawnOne(pool);
      spawnOne(pool);
      expect(pool.isFull, isTrue);
      expect(spawnOne(pool), isNull);
      expect(pool.liveCount, 2);
    });

    test('reap reclaims dead particles and returns the count', () {
      final pool = make(3);
      final a = spawnOne(pool, lifetime: 1.0)!;
      final b = spawnOne(pool, lifetime: 1.0)!;
      spawnOne(pool, lifetime: 1.0);
      // Age two of them past their lifetimes.
      a.lifetime = a.maxLifetime;
      b.lifetime = b.maxLifetime;
      expect(pool.reap(), 2);
      expect(pool.liveCount, 1);
      expect(pool.live.length, 1);
    });

    test('reap makes room for new spawns', () {
      final pool = make(2);
      final a = spawnOne(pool, lifetime: 1.0)!;
      spawnOne(pool, lifetime: 1.0);
      expect(pool.isFull, isTrue);

      a.lifetime = a.maxLifetime;
      pool.reap();
      expect(pool.isFull, isFalse);

      // Spawn again — should succeed now that we've freed a slot.
      expect(spawnOne(pool), isNotNull);
      expect(pool.liveCount, 2);
    });

    test('capacity of 1 works at the boundary', () {
      final pool = make(1);
      final a = spawnOne(pool)!;
      expect(pool.isFull, isTrue);
      expect(spawnOne(pool), isNull);
      a.lifetime = a.maxLifetime;
      pool.reap();
      expect(pool.isFull, isFalse);
      expect(spawnOne(pool), isNotNull);
    });
  });
}
