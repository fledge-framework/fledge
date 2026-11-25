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
        system.run(world);
      }
      final shake = world.query1<CameraShake>().iter().first.$2;
      // 5 frames * 0.1s * 1.0 decay = 0.5 subtracted → trauma ≈ 0.5.
      expect(shake.trauma, closeTo(0.5, 1e-9));
    });

    test('picks a bounded offset scaled by trauma squared', () async {
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
      system.run(world);
      final shake = world.query1<CameraShake>().iter().first.$2;
      // With trauma=1.0, intensity=1.0. Random in [-1,1] * 10 → |delta| ≤ 10.
      expect(shake.offsetX.abs(), lessThanOrEqualTo(10));
      expect(shake.offsetY.abs(), lessThanOrEqualTo(10));
      expect(shake.rotationOffset.abs(), lessThanOrEqualTo(1.0));
      expect(shake.offsetX, isNot(0));
    });

    test('never writes the camera transform', () async {
      final world = World();
      world.spawn()
        ..insert(Transform2D.from(5, 7))
        ..insert(Camera2D())
        ..insert(
          CameraShake(trauma: 1.0, traumaDecayPerSec: 0, rng: math.Random(1)),
        );
      final system = CameraShakeSystem(fixedDelta: 0.1);
      for (var i = 0; i < 3; i++) {
        system.run(world);
      }
      final t = world.query1<Transform2D>().iter().first.$2;
      expect(t.translation.x, 5);
      expect(t.translation.y, 7);
      expect(t.rotation, 0);
    });

    test('offset returns to zero once trauma runs out', () async {
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
      system.run(world);
      system.run(world);
      final shake = world.query1<CameraShake>().iter().first.$2;
      expect(shake.offsetX, 0);
      expect(shake.offsetY, 0);
      expect(shake.rotationOffset, 0);
    });

    test('ActiveCameraViewSystem adds the shake offset', () {
      final world = World();
      world.spawn()
        ..insert(GlobalTransform2D(Transform2D.from(100, 50).toMatrix()))
        ..insert(Camera2D())
        ..insert(
          CameraShake(trauma: 1.0, traumaDecayPerSec: 0, rng: math.Random(3)),
        );
      CameraShakeSystem(fixedDelta: 0).run(world);
      const ActiveCameraViewSystem().run(world);
      final shake = world.query1<CameraShake>().iter().first.$2;
      final view = world.getResource<ActiveCameraView>()!;
      expect(view.x, closeTo(100 + shake.offsetX, 1e-3));
      expect(view.y, closeTo(50 + shake.offsetY, 1e-3));
    });

    test('a camera-fixed parallax layer moves with the shake', () {
      final world = World();
      world.spawn()
        ..insert(Transform2D.from(100, 50))
        ..insert(Camera2D())
        ..insert(
          CameraShake(trauma: 1.0, traumaDecayPerSec: 0, rng: math.Random(3)),
        );
      final layer = world.spawn()
        ..insert(Transform2D.from(0, 0))
        ..insert(GlobalTransform2D())
        ..insert(const Parallax(0));
      CameraShakeSystem(fixedDelta: 0).run(world);
      ParallaxSystem().run(world);
      final shake = world.query1<CameraShake>().iter().first.$2;
      final global = world.get<GlobalTransform2D>(layer.entity)!;
      expect(global.x, closeTo(100 + shake.offsetX, 1e-3));
      expect(global.y, closeTo(50 + shake.offsetY, 1e-3));
    });

    test('with CameraFollow and CameraPlugin, the shake shows the same '
        'frame and the follow does not drift', () async {
      final app = App()
        ..addPlugin(RenderPlugin())
        ..addPlugin(const CameraPlugin());
      final issues = app.checkScheduleOrdering();
      expect(issues, isEmpty, reason: issues.join('\n'));

      final world = app.world;
      final target =
          (world.spawn()
                ..insert(Transform2D.from(300, 200))
                ..insert(
                  GlobalTransform2D(Transform2D.from(300, 200).toMatrix()),
                ))
              .entity;
      final camera =
          (world.spawn()
                ..insert(Transform2D.from(300, 200))
                ..insert(Camera2D())
                ..insert(CameraFollow(target: target, smoothTime: 0.2))
                ..insert(
                  CameraShake(
                    trauma: 1.0,
                    traumaDecayPerSec: 0,
                    rng: math.Random(7),
                  ),
                ))
              .entity;
      world.insertResource(WallTime()..delta = 1 / 60);

      var shaken = 0;
      for (var i = 0; i < 30; i++) {
        await app.tick();
        world.getResource<WallTime>()!.delta = 1 / 60;
        final shake = world.get<CameraShake>(camera)!;
        final view = world.getResource<ActiveCameraView>()!;
        final transform = world.get<Transform2D>(camera)!;
        // The follow keeps the camera on the (still) target...
        expect(transform.translation.x, closeTo(300, 1e-3));
        expect(transform.translation.y, closeTo(200, 1e-3));
        // ...and the view shows it plus this frame's shake.
        expect(view.x, closeTo(300 + shake.offsetX, 1e-3));
        expect(view.y, closeTo(200 + shake.offsetY, 1e-3));
        if (shake.offsetX != 0 || shake.offsetY != 0) shaken++;
      }
      expect(shaken, greaterThan(0));
    });

    test('addTrauma bumps back up after decay', () {
      final s = CameraShake(trauma: 0.2);
      s.addTrauma(0.5);
      expect(s.trauma, closeTo(0.7, 1e-9));
    });
  });
}
