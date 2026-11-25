import 'dart:ui' show Offset, Size;

import 'package:fledge_camera_2d/fledge_camera_2d.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

/// `Camera2D.screenToWorld` / `worldToScreen` must agree with the widget
/// render path (`activeCameraScreenToWorld` / `activeCameraWorldToScreen`,
/// which `FledgeRenderView` draws with) and invert each other.
void main() {
  const size = RenderSize(800, 600);

  GlobalTransform2D at(double x, double y) =>
      GlobalTransform2D(Transform2D.from(x, y).toMatrix());

  /// Publishes [camera] at ([x], [y]) the way `CameraPlugin` does.
  World worldFor(Camera2D camera, double x, double y) {
    final world = World();
    world.spawn()
      ..insert(at(x, y))
      ..insert(camera);
    const ActiveCameraViewSystem().run(world);
    return world;
  }

  final cameras = <String, Camera2D Function()>{
    '1:1': () => Camera2D(),
    'scaled': () => Camera2D(
      scaleWidgetView: true,
      projection: OrthographicProjection(viewportHeight: 150),
    ),
    'pixel-perfect scaled': () => Camera2D(
      scaleWidgetView: true,
      pixelPerfect: true,
      projection: OrthographicProjection(viewportHeight: 270),
    ),
  };

  for (final MapEntry(key: label, value: make) in cameras.entries) {
    group('Camera2D screen mapping ($label)', () {
      test('screenToWorld matches activeCameraScreenToWorld', () {
        final camera = make();
        final world = worldFor(camera, 120.3, -45.7);
        for (final screen in const [
          Offset.zero,
          Offset(400, 300),
          Offset(13, 590),
          Offset(799, 1),
        ]) {
          final expected = activeCameraScreenToWorld(
            world,
            const Size(800, 600),
            screen,
          );
          final actual = camera.screenToWorld(
            Vector2(screen.dx, screen.dy),
            at(120.3, -45.7),
            size,
          );
          expect(actual.x, closeTo(expected.dx, 1e-3));
          expect(actual.y, closeTo(expected.dy, 1e-3));
        }
      });

      test('worldToScreen matches activeCameraWorldToScreen', () {
        final camera = make();
        final world = worldFor(camera, 120.3, -45.7);
        final expected = activeCameraWorldToScreen(
          world,
          const Size(800, 600),
          const Offset(150, -20),
        );
        final actual = camera.worldToScreen(
          Vector2(150, -20),
          at(120.3, -45.7),
          size,
        );
        expect(actual.x, closeTo(expected.dx, 1e-3));
        expect(actual.y, closeTo(expected.dy, 1e-3));
      });

      test('the two round-trip', () {
        final camera = make();
        final transform = at(-33, 71);
        final point = Vector2(12.5, -8.25);
        final back = camera.screenToWorld(
          camera.worldToScreen(point, transform, size),
          transform,
          size,
        );
        expect(back.x, closeTo(point.x, 1e-3));
        expect(back.y, closeTo(point.y, 1e-3));
      });
    });
  }

  test('the camera position is the viewport centre and y grows downward', () {
    final camera = Camera2D();
    final transform = at(100, 50);
    final centre = camera.screenToWorld(Vector2(400, 300), transform, size);
    expect(centre.x, closeTo(100, 1e-9));
    expect(centre.y, closeTo(50, 1e-9));
    final below = camera.worldToScreen(Vector2(100, 60), transform, size);
    expect(below.y, closeTo(310, 1e-9));
  });
}
