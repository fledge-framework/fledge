import 'dart:ui' show Color;

import 'package:fledge_lighting_2d/fledge_lighting_2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('Light2D.point', () {
    test('has LightType.point', () {
      final light = Light2D.point(color: const Color(0xFFFFFFFF));
      expect(light.type, LightType.point);
    });

    test('honours radius / innerRadius / intensity', () {
      final light = Light2D.point(
        color: const Color(0xFFFFAA00),
        intensity: 0.75,
        radius: 200,
        innerRadius: 40,
      );
      expect(light.radius, 200);
      expect(light.innerRadius, 40);
      expect(light.intensity, 0.75);
      expect(light.color, const Color(0xFFFFAA00));
    });
  });

  group('Light2D.directional', () {
    test('has LightType.directional', () {
      final light = Light2D.directional(
        color: const Color(0xFFFFFFFF),
        direction: Vector2(1, 0),
      );
      expect(light.type, LightType.directional);
    });

    test('normalizes non-unit direction', () {
      final light = Light2D.directional(
        color: const Color(0xFFFFFFFF),
        direction: Vector2(3, 4),
      );
      // `vector_math` uses single-precision floats; a tolerance
      // tighter than ~1e-6 will trip on the length of a normalized
      // vector.
      expect(light.direction.length, closeTo(1.0, 1e-6));
      expect(light.direction.x, closeTo(0.6, 1e-6));
      expect(light.direction.y, closeTo(0.8, 1e-6));
    });

    test('radius is infinite', () {
      final light = Light2D.directional(
        color: const Color(0xFFFFFFFF),
        direction: Vector2(0, 1),
      );
      expect(light.radius, double.infinity);
    });
  });

  group('Light2D.spot', () {
    test('has LightType.spot', () {
      final light = Light2D.spot(
        color: const Color(0xFFFFFFFF),
        direction: Vector2(1, 0),
        angle: 0.3,
      );
      expect(light.type, LightType.spot);
    });

    test('normalizes direction and preserves angle', () {
      final light = Light2D.spot(
        color: const Color(0xFFFFFFFF),
        direction: Vector2(0, 2),
        angle: 0.4,
      );
      expect(light.direction.length, closeTo(1.0, 1e-6));
      expect(light.angle, 0.4);
    });
  });

  test('castsShadow defaults to false (reserved)', () {
    final light = Light2D.point(color: const Color(0xFFFFFFFF));
    expect(light.castsShadow, isFalse);
  });
}
