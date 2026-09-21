import 'package:fledge_camera_2d/fledge_camera_2d.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CameraFollowSystem', () {
    late World world;
    late Entity target;
    late Entity cameraEntity;

    setUp(() {
      world = World();
      target =
          (world.spawn()
                ..insert(Transform2D.from(100, 200))
                ..insert(GlobalTransform2D.identity()))
              .entity;
      // Manually set GlobalTransform2D so we don't need to run
      // TransformPropagateSystem in this focused test.
      world
          .get<GlobalTransform2D>(target)!
          .matrix
          .setValues(1, 0, 0, 0, 1, 0, 100, 200, 1);

      cameraEntity =
          (world.spawn()
                ..insert(Transform2D.from(0, 0))
                ..insert(Camera2D())
                ..insert(CameraFollow(target: target, smoothing: 0.5)))
              .entity;
    });

    test('lerps toward target with smoothing factor', () async {
      await CameraFollowSystem().run(world);
      final t = world.get<Transform2D>(cameraEntity)!;
      // 0.5 * (100 - 0) = 50
      expect(t.translation.x, closeTo(50, 1e-9));
      expect(t.translation.y, closeTo(100, 1e-9));
    });

    test('converges to target within N frames', () async {
      final system = CameraFollowSystem();
      for (var i = 0; i < 40; i++) {
        await system.run(world);
      }
      final t = world.get<Transform2D>(cameraEntity)!;
      expect(t.translation.x, closeTo(100, 1e-3));
      expect(t.translation.y, closeTo(200, 1e-3));
    });

    test('smoothing = 1.0 snaps in a single frame', () async {
      world.get<CameraFollow>(cameraEntity)!.smoothing = 1.0;
      await CameraFollowSystem().run(world);
      final t = world.get<Transform2D>(cameraEntity)!;
      expect(t.translation.x, 100);
      expect(t.translation.y, 200);
    });

    test('applies offset', () async {
      world.get<CameraFollow>(cameraEntity)!
        ..smoothing = 1.0
        ..offset = const Offset(10, -20);
      await CameraFollowSystem().run(world);
      final t = world.get<Transform2D>(cameraEntity)!;
      expect(t.translation.x, 110);
      expect(t.translation.y, 180);
    });

    test('missing target logs once and stops', () async {
      world.despawn(target);
      // First run — should log without throwing.
      await CameraFollowSystem().run(world);
      final follow = world.get<CameraFollow>(cameraEntity)!;
      expect(follow.warnedMissingTarget, isTrue);
      // Second run — should be a no-op (already warned).
      await CameraFollowSystem().run(world);
    });

    test(
      'pixelPerfect: camera position is snapped to whole pixels',
      () async {
        // Target at (100.6, 200.4) — the smoothed camera position lands
        // at non-integer coordinates, which pixelPerfect must round.
        world.get<Transform2D>(target)!.translation.setValues(100.6, 200.4);
        world.get<GlobalTransform2D>(target)!.matrix.setValues(
              1, 0, 0, 0, 1, 0, 100.6, 200.4, 1,
            );
        world.get<CameraFollow>(cameraEntity)!.smoothing = 1.0;
        world.get<Camera2D>(cameraEntity)!.pixelPerfect = true;

        await CameraFollowSystem().run(world);

        final t = world.get<Transform2D>(cameraEntity)!;
        expect(t.translation.x, 101);
        expect(t.translation.y, 200);
      },
    );

    test('non-pixelPerfect keeps sub-pixel positions', () async {
      world.get<Transform2D>(target)!.translation.setValues(100.6, 200.4);
      world.get<GlobalTransform2D>(target)!.matrix.setValues(
            1, 0, 0, 0, 1, 0, 100.6, 200.4, 1,
          );
      world.get<CameraFollow>(cameraEntity)!.smoothing = 1.0;
      world.get<Camera2D>(cameraEntity)!.pixelPerfect = false;

      await CameraFollowSystem().run(world);

      final t = world.get<Transform2D>(cameraEntity)!;
      expect(t.translation.x, closeTo(100.6, 1e-4));
      expect(t.translation.y, closeTo(200.4, 1e-4));
    });
  });
}
