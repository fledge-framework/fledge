import 'dart:ui' show Offset, Size;

import 'package:fledge_camera_2d/fledge_camera_2d.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';

Future<World> publish(Camera2D camera, {double x = 0, double y = 0}) async {
  final world = World();
  world.spawn()
    ..insert(GlobalTransform2D()..matrix.setValues(1, 0, 0, 0, 1, 0, x, y, 1))
    ..insert(camera);
  const ActiveCameraViewSystem().run(world);
  return world;
}

void main() {
  group('Camera2D.widgetZoom', () {
    test('is 1 unless scaleWidgetView is on', () {
      final camera = Camera2D(
        projection: OrthographicProjection(viewportHeight: 270),
      );
      expect(camera.widgetZoom(const Size(1000, 540)), 1);
    });

    test('fills the widget height with the projection height', () {
      final camera = Camera2D(
        projection: OrthographicProjection(viewportHeight: 270),
        scaleWidgetView: true,
      );
      expect(camera.widgetZoom(const Size(1000, 540)), 2);
      expect(camera.widgetZoom(const Size(1000, 675)), 2.5);
    });

    test('fixedWidth projections fill the widget width', () {
      final camera = Camera2D(
        projection: OrthographicProjection(
          scalingMode: ScalingMode.fixedWidth,
          viewportWidth: 200,
        ),
        scaleWidgetView: true,
      );
      expect(camera.widgetZoom(const Size(800, 300)), closeTo(4, 1e-9));
    });

    test('pixelPerfect rounds down to a whole zoom, but not below 1', () {
      final camera = Camera2D(
        projection: OrthographicProjection(viewportHeight: 270),
        scaleWidgetView: true,
        pixelPerfect: true,
      );
      expect(camera.widgetZoom(const Size(1000, 675)), 2);
      expect(camera.widgetZoom(const Size(1000, 135)), 0.5);
    });

    test('pixelPerfect puts a world unit on whole physical pixels under '
        'display scaling', () {
      final camera = Camera2D(
        projection: OrthographicProjection(viewportHeight: 540),
        scaleWidgetView: true,
        pixelPerfect: true,
      );
      // 1080p at 125 %: 864 logical pixels high. A whole logical zoom (1)
      // would be 1.25 physical pixels a unit; this is 2 physical (1.6
      // logical), which still fits the 540-unit height.
      expect(
        camera.widgetZoom(const Size(1536, 864), devicePixelRatio: 1.25),
        closeTo(1.6, 1e-9),
      );
      // 4K at 125 %: 3.2 logical = 4 physical, not 3 logical = 3.75.
      expect(
        camera.widgetZoom(const Size(3072, 1728), devicePixelRatio: 1.25),
        closeTo(3.2, 1e-9),
      );
      // 1440p at 150 %: 960 logical, 2.67 physical a unit: 2 physical.
      expect(
        camera.widgetZoom(const Size(1707, 960), devicePixelRatio: 1.5),
        closeTo(2 / 1.5, 1e-9),
      );
      // At 100 % nothing changes.
      expect(camera.widgetZoom(const Size(1920, 1080)), 2);
      for (final (size, dpr) in [
        (const Size(1536, 864), 1.25),
        (const Size(3072, 1728), 1.25),
        (const Size(2133, 1200), 1.75),
      ]) {
        final physical = camera.widgetZoom(size, devicePixelRatio: dpr) * dpr;
        expect(physical, closeTo(physical.roundToDouble(), 1e-9));
        expect(
          camera.widgetZoom(size, devicePixelRatio: dpr) * 540,
          lessThanOrEqualTo(size.height + 1e-9),
        );
      }
    });

    test('the published zoom follows the painting widget\'s scaling', () async {
      final world = await publish(
        Camera2D(
          projection: OrthographicProjection(viewportHeight: 540),
          scaleWidgetView: true,
          pixelPerfect: true,
        ),
      );
      final view = world.getResource<ActiveCameraView>()!;
      expect(view.zoomFor!(const Size(1536, 864)), 1);
      view.devicePixelRatio = 1.25;
      expect(view.zoomFor!(const Size(1536, 864)), closeTo(1.6, 1e-9));
    });

    test('degenerate sizes fall back to 1', () {
      final camera = Camera2D(scaleWidgetView: true);
      expect(camera.widgetZoom(Size.zero), 1);
    });
  });

  group('ActiveCameraViewSystem publishes the zoom', () {
    test('no zoom by default (backwards compatible)', () async {
      final world = await publish(Camera2D());
      expect(world.getResource<ActiveCameraView>()!.zoomFor, isNull);
    });

    test('scaleWidgetView cameras drive the widget mapping', () async {
      final world = await publish(
        Camera2D(
          projection: OrthographicProjection(viewportHeight: 270),
          scaleWidgetView: true,
        ),
        x: 100,
        y: 50,
      );
      const size = Size(960, 540);
      expect(activeCameraZoom(world, size), 2);
      expect(
        activeCameraScreenToWorld(world, size, const Offset(480, 270)),
        const Offset(100, 50),
      );
      expect(
        activeCameraScreenToWorld(world, size, Offset.zero),
        const Offset(100 - 240, 50 - 135),
      );
    });

    test('subpixelScroll is published, and the mapping stays exact', () async {
      final world = await publish(
        Camera2D(
          projection: OrthographicProjection(viewportHeight: 270),
          scaleWidgetView: true,
          pixelPerfect: true,
          subpixelScroll: true,
        ),
        x: 100.25,
        y: 50,
      );
      expect(world.getResource<ActiveCameraView>()!.subpixelScroll, isTrue);
      const size = Size(960, 540);
      // Not rounded to a whole pixel: pointers land where the shifted frame
      // shows them.
      expect(
        activeCameraScreenToWorld(world, size, const Offset(480, 270)),
        const Offset(100.25, 50),
      );
    });

    test('turning scaleWidgetView off clears the zoom', () async {
      final camera = Camera2D(scaleWidgetView: true);
      final world = await publish(camera);
      expect(world.getResource<ActiveCameraView>()!.zoomFor, isNotNull);
      camera.scaleWidgetView = false;
      const ActiveCameraViewSystem().run(world);
      expect(world.getResource<ActiveCameraView>()!.zoomFor, isNull);
    });
  });
}
