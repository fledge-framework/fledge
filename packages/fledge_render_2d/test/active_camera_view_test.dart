import 'dart:ui' show Offset, Rect, Size;

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

  group('ActiveCameraView zoom and coordinate helpers', () {
    const size = Size(400, 300);

    test('zoom defaults to 1 with or without a camera view', () {
      expect(activeCameraZoom(World(), size), 1);
      final world = World()..insertResource(ActiveCameraView());
      expect(activeCameraZoom(world, size), 1);
    });

    test('zoomFor scales the offset around the camera position', () {
      final world = World()
        ..insertResource(ActiveCameraView(x: 10, y: 20, zoomFor: (_) => 2));
      expect(activeCameraZoom(world, size), 2);
      // Camera centre lands on the widget centre: offset + cam * zoom.
      final offset = activeCameraCanvasOffset(world, size)!;
      expect(offset, const Offset(200 - 20, 150 - 40));
    });

    test('non-positive or non-finite zoom falls back to 1', () {
      for (final bad in [0.0, -1.0, double.nan, double.infinity]) {
        final world = World()
          ..insertResource(ActiveCameraView(zoomFor: (_) => bad));
        expect(activeCameraZoom(world, size), 1, reason: '$bad');
      }
    });

    test('screenToWorld and worldToScreen round-trip', () {
      final world = World()
        ..insertResource(ActiveCameraView(x: 50, y: -30, zoomFor: (_) => 3));
      // The widget centre is the camera position.
      expect(
        activeCameraScreenToWorld(world, size, const Offset(200, 150)),
        const Offset(50, -30),
      );
      // One zoomed step right/down is one world unit.
      expect(
        activeCameraScreenToWorld(world, size, const Offset(203, 156)),
        const Offset(51, -28),
      );
      const p = Offset(12.5, 40);
      final back = activeCameraScreenToWorld(
        world,
        size,
        activeCameraWorldToScreen(world, size, p),
      );
      expect(back.dx, closeTo(p.dx, 1e-9));
      expect(back.dy, closeTo(p.dy, 1e-9));
    });

    test('without a camera view the mapping is identity', () {
      final world = World();
      const p = Offset(7, 9);
      expect(activeCameraScreenToWorld(world, size, p), p);
      expect(activeCameraWorldToScreen(world, size, p), p);
      expect(
        activeCameraVisibleWorldRect(world, size),
        const Rect.fromLTWH(0, 0, 400, 300),
      );
    });

    test('visible world rect shrinks with zoom', () {
      final world = World()
        ..insertResource(ActiveCameraView(x: 0, y: 0, zoomFor: (_) => 2));
      expect(
        activeCameraVisibleWorldRect(world, size),
        const Rect.fromLTRB(-100, -75, 100, 75),
      );
    });
  });
}
