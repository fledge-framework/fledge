import 'dart:math' as math;

import 'package:fledge_camera_2d/fledge_camera_2d.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart' show RenderSize;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  const size = RenderSize(800, 600);

  group('OrthographicProjection.worldToScreenPoint', () {
    test('origin maps to screen centre', () {
      final proj = OrthographicProjection(viewportHeight: 20);
      final s = proj.worldToScreenPoint(Vector2.zero(), size);
      expect(s.x, closeTo(400, 1e-6));
      expect(s.y, closeTo(300, 1e-6));
    });

    test('positive Y maps to upper half of screen', () {
      // viewportHeight=20 → world Y in [-10, 10] maps to screen Y in
      // [600, 0] (with our convention that +Y is up in world space).
      final proj = OrthographicProjection(viewportHeight: 20);
      final s = proj.worldToScreenPoint(Vector2(0, 5), size);
      expect(s.y, closeTo(150, 1e-6));
    });
  });

  group('IsometricProjection.worldToIso', () {
    test('origin maps to origin', () {
      final proj = IsometricProjection();
      final s = proj.worldToIso(Vector2.zero());
      expect(s.x, 0);
      expect(s.y, 0);
    });

    test('point (1, 0) maps to (1, 0.5) in iso space', () {
      final proj = IsometricProjection();
      final s = proj.worldToIso(Vector2(1, 0));
      expect(s.x, closeTo(1, 1e-9));
      expect(s.y, closeTo(0.5, 1e-9));
    });

    test('point (0, 1) maps to (-1, 0.5) in iso space', () {
      final proj = IsometricProjection();
      final s = proj.worldToIso(Vector2(0, 1));
      expect(s.x, closeTo(-1, 1e-9));
      expect(s.y, closeTo(0.5, 1e-9));
    });

    test('point (1, 1) maps to (0, 1) — the classic diamond', () {
      final proj = IsometricProjection();
      final s = proj.worldToIso(Vector2(1, 1));
      expect(s.x, closeTo(0, 1e-9));
      expect(s.y, closeTo(1, 1e-9));
    });
  });

  group('ObliqueProjection.worldToOblique', () {
    test('origin maps to origin', () {
      final proj = ObliqueProjection();
      final s = proj.worldToOblique(Vector2.zero());
      expect(s.x, 0);
      expect(s.y, 0);
    });

    test('45° cabinet: (0, 2) shifts x by 2 * cos(45) * 0.5', () {
      final proj = ObliqueProjection(
        angleRadians: math.pi / 4,
        depthFactor: 0.5,
      );
      final s = proj.worldToOblique(Vector2(0, 2));
      final expectedX = 2 * math.cos(math.pi / 4) * 0.5;
      final expectedY = 2 * math.sin(math.pi / 4) * 0.5;
      // vector_math's Vector2 is Float32-backed, so we allow a small
      // absolute tolerance rather than the 1e-9 we get with doubles.
      expect(s.x, closeTo(expectedX, 1e-6));
      expect(s.y, closeTo(expectedY, 1e-6));
    });

    test('foreshortening depthFactor = 0 flattens Y', () {
      final proj = ObliqueProjection(depthFactor: 0);
      final s = proj.worldToOblique(Vector2(5, 10));
      expect(s.x, closeTo(5, 1e-9));
      expect(s.y, closeTo(0, 1e-9));
    });
  });
}
