import 'package:fledge_camera_2d/fledge_camera_2d.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';

/// The system publishes the active camera's world position into
/// [ActiveCameraView] every frame so the widget render path can
/// translate its canvas. Runs after CameraFollowSystem in the
/// camera plugin's postUpdate stack.
void main() {
  group('ActiveCameraViewSystem', () {
    test('writes the active camera position into ActiveCameraView', () async {
      final world = World();
      world.spawn()
        ..insert(Transform2D.from(120, 80))
        ..insert(
          GlobalTransform2D()..matrix.setValues(1, 0, 0, 0, 1, 0, 120, 80, 1),
        )
        ..insert(Camera2D());

      await const ActiveCameraViewSystem().run(world);

      final view = world.getResource<ActiveCameraView>();
      expect(view, isNotNull);
      expect(view!.x, 120);
      expect(view.y, 80);
    });

    test('picks the lowest-order active camera when several exist', () async {
      final world = World();
      // Backup camera (higher order) — the ActiveCameraView should
      // NOT track this one.
      world.spawn()
        ..insert(
          GlobalTransform2D()..matrix.setValues(1, 0, 0, 0, 1, 0, 999, 999, 1),
        )
        ..insert(Camera2D(order: 10));
      // Primary camera — order 0 (lower wins).
      world.spawn()
        ..insert(
          GlobalTransform2D()..matrix.setValues(1, 0, 0, 0, 1, 0, 10, 20, 1),
        )
        ..insert(Camera2D(order: 0));

      await const ActiveCameraViewSystem().run(world);

      final view = world.getResource<ActiveCameraView>();
      expect(view!.x, 10);
      expect(view.y, 20);
    });

    test('ignores inactive cameras', () async {
      final world = World();
      world.spawn()
        ..insert(
          GlobalTransform2D()..matrix.setValues(1, 0, 0, 0, 1, 0, 5, 6, 1),
        )
        ..insert(Camera2D(isActive: false));
      await const ActiveCameraViewSystem().run(world);
      // No active camera → nothing inserted, and no crash.
      expect(world.getResource<ActiveCameraView>(), isNull);
    });

    test('updates the existing resource in place on subsequent runs', () async {
      final world = World();
      final e = world.spawn()
        ..insert(
          GlobalTransform2D()..matrix.setValues(1, 0, 0, 0, 1, 0, 1, 2, 1),
        )
        ..insert(Camera2D());
      await const ActiveCameraViewSystem().run(world);
      final first = world.getResource<ActiveCameraView>();
      world
          .get<GlobalTransform2D>(e.entity)!
          .matrix
          .setValues(1, 0, 0, 0, 1, 0, 50, 60, 1);
      await const ActiveCameraViewSystem().run(world);
      final second = world.getResource<ActiveCameraView>();
      // Same instance is reused.
      expect(identical(first, second), isTrue);
      expect(second!.x, 50);
      expect(second.y, 60);
    });
  });
}
