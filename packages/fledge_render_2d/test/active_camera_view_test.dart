import 'dart:ui' show Size;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ActiveCameraView / activeCameraCanvasOffset', () {
    test('null when no resource is installed (world = screen fallback)', () {
      final world = World();
      expect(activeCameraCanvasOffset(world, const Size(400, 300)), isNull);
    });

    test(
      'when camera is at origin, offset places world origin at widget centre',
      () {
        final world = World()..insertResource(ActiveCameraView());
        final offset = activeCameraCanvasOffset(world, const Size(400, 300));
        expect(offset, isNotNull);
        expect(offset!.dx, 200);
        expect(offset.dy, 150);
      },
    );

    test(
      'when camera moves right, world content translates left on canvas',
      () {
        final world = World()..insertResource(ActiveCameraView(x: 100, y: 50));
        final offset = activeCameraCanvasOffset(world, const Size(400, 300));
        // widget centre - camera pos = (200 - 100, 150 - 50) = (100, 100).
        // Content at world (100, 50) then draws at canvas (200, 150).
        expect(offset!.dx, 100);
        expect(offset.dy, 100);
      },
    );

    test('ActiveCameraView.set overwrites both coordinates', () {
      final view = ActiveCameraView();
      view.set(12.5, -7);
      expect(view.x, 12.5);
      expect(view.y, -7);
    });

    test('pixelPerfect rounds the offset to whole pixels '
        '(regression for Batch 6 #24)', () {
      // Odd viewport width, camera at a half-pixel: without
      // pixelPerfect the offset is fractional.
      final world = World()
        ..insertResource(ActiveCameraView(x: 100.5, y: 50.5));
      final unsnapped = activeCameraCanvasOffset(world, const Size(401, 301))!;
      expect(unsnapped.dx, closeTo(100.0, 1e-9));
      expect(unsnapped.dy, closeTo(100.0, 1e-9));
      // With pixelPerfect set, both coordinates round.
      world.getResource<ActiveCameraView>()!.pixelPerfect = true;
      final snapped = activeCameraCanvasOffset(world, const Size(401, 301))!;
      expect(snapped.dx.roundToDouble(), snapped.dx);
      expect(snapped.dy.roundToDouble(), snapped.dy);
    });
  });
}
