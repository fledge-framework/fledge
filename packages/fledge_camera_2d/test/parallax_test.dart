import 'package:fledge_camera_2d/fledge_camera_2d.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ParallaxSystem', () {
    test('factor = 0.5 moves entity at half camera speed', () async {
      final world = World();
      // Camera at (100, 0).
      world.spawn()
        ..insert(Transform2D.from(100, 0))
        ..insert(GlobalTransform2D())
        ..insert(Camera2D());
      // Parallax entity at world (0, 0) with factor 0.5.
      final e =
          (world.spawn()
                ..insert(Transform2D.from(0, 0))
                ..insert(GlobalTransform2D())
                ..insert(const Parallax(0.5)))
              .entity;
      await ParallaxSystem().run(world);
      final g = world.get<GlobalTransform2D>(e)!;
      // effective = transform.pos + (1 - factor) * cameraPos
      //           = (0, 0) + 0.5 * (100, 0) = (50, 0).
      expect(g.x, closeTo(50, 1e-9));
      expect(g.y, closeTo(0, 1e-9));
    });

    test('factor = 1.0 leaves entity untouched (foreground)', () async {
      final world = World();
      world.spawn()
        ..insert(Transform2D.from(200, 300))
        ..insert(GlobalTransform2D())
        ..insert(Camera2D());
      final e =
          (world.spawn()
                ..insert(Transform2D.from(50, 60))
                ..insert(GlobalTransform2D())
                ..insert(const Parallax(1.0)))
              .entity;
      await ParallaxSystem().run(world);
      final g = world.get<GlobalTransform2D>(e)!;
      expect(g.x, closeTo(50, 1e-9));
      expect(g.y, closeTo(60, 1e-9));
    });

    test('factor = 0.0 locks entity to viewport (background)', () async {
      final world = World();
      world.spawn()
        ..insert(Transform2D.from(1000, 500))
        ..insert(GlobalTransform2D())
        ..insert(Camera2D());
      final e =
          (world.spawn()
                ..insert(Transform2D.from(10, 20))
                ..insert(GlobalTransform2D())
                ..insert(const Parallax(0.0)))
              .entity;
      await ParallaxSystem().run(world);
      final g = world.get<GlobalTransform2D>(e)!;
      // effective = transform.pos + camera.pos = (1010, 520).
      expect(g.x, closeTo(1010, 1e-9));
      expect(g.y, closeTo(520, 1e-9));
    });

    test('no camera → no-op', () async {
      final world = World();
      final e =
          (world.spawn()
                ..insert(Transform2D.from(5, 6))
                ..insert(GlobalTransform2D())
                ..insert(const Parallax(0.5)))
              .entity;
      // Preload global to non-parallax values.
      final g = world.get<GlobalTransform2D>(e)!;
      g.matrix[6] = 99;
      g.matrix[7] = 88;
      await ParallaxSystem().run(world);
      // Unchanged because no camera was found.
      expect(g.x, 99);
      expect(g.y, 88);
    });
  });
}
