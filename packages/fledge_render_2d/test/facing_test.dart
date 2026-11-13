import 'dart:math' as math;

import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('facingViewIndex', () {
    test('view 0 faces +x and indices advance clockwise (toward +y)', () {
      expect(facingViewIndex(0, 8), 0); // right
      expect(facingViewIndex(math.pi / 4, 8), 1); // down-right
      expect(facingViewIndex(math.pi / 2, 8), 2); // down
      expect(facingViewIndex(math.pi, 8), 4); // left
      expect(facingViewIndex(3 * math.pi / 2, 8), 6); // up
    });

    test('wraps negative and large angles', () {
      expect(facingViewIndex(-math.pi / 2, 8), 6);
      expect(facingViewIndex(-0.01, 16), 0);
      expect(facingViewIndex(2 * math.pi - 0.01, 16), 0);
      expect(facingViewIndex(5 * math.pi, 4), 2);
    });

    test('rounds to the nearest view; boundaries go clockwise', () {
      const step = 2 * math.pi / 16;
      expect(facingViewIndex(step * 0.49, 16), 0);
      expect(facingViewIndex(step * 0.51, 16), 1);
      expect(facingViewIndex(step * 3.5, 16), 4);
    });

    test('works for any N >= 1', () {
      for (final n in [1, 2, 3, 5, 8, 16, 32]) {
        for (var i = 0; i < n; i++) {
          expect(facingViewIndex(facingViewAngle(i, n), n), i, reason: 'n=$n');
        }
      }
      expect(facingViewIndex(1.234, 1), 0);
    });

    test('rejects views < 1 and tolerates non-finite angles', () {
      expect(() => facingViewIndex(0, 0), throwsRangeError);
      expect(() => facingViewAngle(0, 0), throwsRangeError);
      expect(facingViewIndex(double.nan, 8), 0);
      expect(facingViewIndex(double.infinity, 8), 0);
    });
  });

  group('normalizeFacingAngle', () {
    test('wraps into [0, 2π)', () {
      expect(
        normalizeFacingAngle(-math.pi / 2),
        closeTo(3 * math.pi / 2, 1e-9),
      );
      expect(normalizeFacingAngle(2 * math.pi), closeTo(0, 1e-9));
      expect(normalizeFacingAngle(7), closeTo(7 - 2 * math.pi, 1e-9));
    });
  });

  group('Facing', () {
    test('defaults to down, like Orientation', () {
      expect(Facing().angle, Facing.down);
      expect(Facing().direction, Direction.down);
      expect(Orientation().direction, Facing().direction);
    });

    test('fromVector / updateFromVector follow atan2 in y-down space', () {
      expect(Facing.fromVector(0, 1).viewIndex(4), 1);
      expect(Facing.fromVector(-1, 0).direction, Direction.left);
      expect(Facing.fromVector(0, 0).angle, Facing.down);

      final f = Facing(Facing.right);
      expect(f.updateFromVector(0, -2), isTrue);
      expect(f.direction, Direction.up);
      // Below the dead zone: keeps the last facing.
      expect(f.updateFromVector(0.1, 0, minLength: 0.5), isFalse);
      expect(f.updateFromVector(0, 0), isFalse);
      expect(f.direction, Direction.up);
      // Same angle again: no change reported.
      expect(f.updateFromVector(0, -5), isFalse);
    });

    test('round-trips cardinal directions', () {
      for (final d in Direction.values) {
        expect(Facing.fromDirection(d).direction, d);
      }
    });

    test('matches Transform2D rotation of the local +x axis', () {
      for (final rotation in [0.0, 0.7, 2.0, -1.2]) {
        final m = Transform2D(rotation: rotation).toMatrix();
        // Local +x mapped to world.
        final dx = m.storage[0];
        final dy = m.storage[1];
        expect(
          Facing.fromVector(dx, dy).viewIndex(16),
          Facing(rotation).viewIndex(16),
        );
        expect(
          GlobalTransform2D(m).rotation,
          closeTo(math.atan2(math.sin(rotation), math.cos(rotation)), 1e-6),
        );
      }
    });
  });
}
