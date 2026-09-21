import 'dart:math' as math;

import 'package:fledge_camera_2d/fledge_camera_2d.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CameraShake / CameraShakeSystem', () {
    test('addTrauma clamps to [0,1]', () {
      final s = CameraShake();
      s.addTrauma(0.3);
      expect(s.trauma, closeTo(0.3, 1e-9));
      s.addTrauma(2.0);
      expect(s.trauma, 1.0);
      s.trauma = -0.5;
      s.addTrauma(0.1);
      // clamp is applied on add.
      expect(s.trauma, closeTo(0.0, 1e-9)); // -0.5 + 0.1 = -0.4 → clamped to 0
    });

    test('intensity scales as trauma squared', () {
      final s = CameraShake(trauma: 0.5);
      expect(s.intensity, closeTo(0.25, 1e-9));
      s.trauma = 1.0;
      expect(s.intensity, closeTo(1.0, 1e-9));
    });

    test('decays trauma over frames', () async {
      final world = World();
      world.spawn()
        ..insert(Transform2D.from(0, 0))
        ..insert(Camera2D())
        ..insert(
          CameraShake(trauma: 1.0, traumaDecayPerSec: 1.0, rng: math.Random(1)),
        );
      final system = CameraShakeSystem(fixedDelta: 0.1);
      for (var i = 0; i < 5; i++) {
        await system.run(world);
      }
      final shake = world.query1<CameraShake>().iter().first.$2;
      // 5 frames * 0.1s * 1.0 decay = 0.5 subtracted → trauma ≈ 0.5.
      expect(shake.trauma, closeTo(0.5, 1e-9));
    });

    test('applies bounded delta scaled by trauma squared', () async {
      final world = World();
      world.spawn()
        ..insert(Transform2D.from(0, 0))
        ..insert(Camera2D())
        ..insert(
          CameraShake(
            trauma: 1.0,
            traumaDecayPerSec: 0,
            maxOffsetX: 10,
            maxOffsetY: 10,
            maxRotationRadians: 1.0,
            rng: math.Random(1),
          ),
        );
      final system = CameraShakeSystem(fixedDelta: 0);
      await system.run(world);
      final t = world.query1<Transform2D>().iter().first.$2;
      // With trauma=1.0, intensity=1.0. Random in [-1,1] * 10 → |delta| ≤ 10.
      expect(t.translation.x.abs(), lessThanOrEqualTo(10));
      expect(t.translation.y.abs(), lessThanOrEqualTo(10));
      expect(t.rotation.abs(), lessThanOrEqualTo(1.0));
    });

    test('undoes previous delta before applying new one', () async {
      final world = World();
      world.spawn()
        ..insert(Transform2D.from(0, 0))
        ..insert(Camera2D())
        ..insert(
          CameraShake(
            trauma: 0.5,
            traumaDecayPerSec: 100, // decay to 0 after one frame
            rng: math.Random(1),
          ),
        );
      final system = CameraShakeSystem(fixedDelta: 0.1);
      await system.run(world);
      // After trauma hits 0, next run should undo any leftover
      // shake, returning translation exactly to 0.
      await system.run(world);
      final t = world.query1<Transform2D>().iter().first.$2;
      expect(t.translation.x, closeTo(0, 1e-9));
      expect(t.translation.y, closeTo(0, 1e-9));
      expect(t.rotation, closeTo(0, 1e-9));
    });

    test('addTrauma bumps back up after decay', () {
      final s = CameraShake(trauma: 0.2);
      s.addTrauma(0.5);
      expect(s.trauma, closeTo(0.7, 1e-9));
    });
  });
}
