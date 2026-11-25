import 'dart:ui' show Color, Size;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_particles/fledge_particles.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

final _template = ParticleTemplate(
  lifetimeMin: 1,
  lifetimeMax: 1,
  velocityMin: Vector2.zero(),
  velocityMax: Vector2.zero(),
  acceleration: Vector2.zero(),
  sizeMin: 4,
  sizeMax: 4,
  colorStart: const Color(0xFFFFFFFF),
  colorEnd: const Color(0xFFFFFFFF),
);

/// One emitter whose pool holds a particle (size 4) at each of [at].
World _world(List<(double, double)> at) {
  final world = World();
  final pool = ParticlePool(at.length);
  for (final (x, y) in at) {
    pool.spawn(
      position: Vector2(x, y),
      velocity: Vector2.zero(),
      maxLifetime: 1,
      size: 4,
      colorStart: const Color(0xFFFFFFFF),
      colorEnd: const Color(0xFFFFFFFF),
    );
  }
  world.spawn()
    ..insert(GlobalTransform2D.identity())
    ..insert(
      ParticleEmitter(
        template: _template,
        emitRate: 0,
        texture: const TextureHandle(id: 7, width: 4, height: 4),
        pool: pool,
      ),
    );
  return world;
}

List<double> _extractedX(World world) {
  final rw = RenderWorld();
  ParticleExtractor().extract(world, rw);
  return [for (final s in rw.extractedSprites) s.transform.storage[6]]..sort();
}

void main() {
  test('particles far outside the camera view are culled, ones in the '
      'margin kept', () {
    // The view is 200 x 200 around the origin: x in -100..100.
    final world = _world([(0, 0), (150, 0), (5000, 0), (0, -5000)])
      ..insertResource(ActiveCameraView()..viewportSize = const Size(200, 200));
    expect(_extractedX(world), [0, 150]);
  });

  test('the cull follows the camera', () {
    final world = _world([(0, 0), (5000, 0)])
      ..insertResource(
        ActiveCameraView(x: 5000)..viewportSize = const Size(200, 200),
      );
    expect(_extractedX(world), [5000]);
  });

  test('with no camera view (headless), nothing is culled', () {
    final world = _world([(0, 0), (5000, 0), (0, -5000)]);
    expect(_extractedX(world), hasLength(3));
  });
}
