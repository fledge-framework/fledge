import 'package:fledge_tween/fledge_tween.dart';
import 'package:flutter_test/flutter_test.dart';

/// Curves we expect to obey the endpoint contract `c(0) == 0` and
/// `c(1) == 1`. `elasticIn`/`elasticOut` are listed with a tolerance
/// separately below.
const _endpointCurves = <String, Curve>{
  'linear': Curves.linear,
  'easeInQuad': Curves.easeInQuad,
  'easeOutQuad': Curves.easeOutQuad,
  'easeInOutQuad': Curves.easeInOutQuad,
  'easeInCubic': Curves.easeInCubic,
  'easeOutCubic': Curves.easeOutCubic,
  'easeInOutCubic': Curves.easeInOutCubic,
  'easeInQuart': Curves.easeInQuart,
  'easeOutQuart': Curves.easeOutQuart,
  'easeInOutQuart': Curves.easeInOutQuart,
  'easeInSine': Curves.easeInSine,
  'easeOutSine': Curves.easeOutSine,
  'easeInOutSine': Curves.easeInOutSine,
  'bounceOut': Curves.bounceOut,
  'bounceIn': Curves.bounceIn,
  'elasticOut': Curves.elasticOut,
  'elasticIn': Curves.elasticIn,
};

void main() {
  group('endpoints', () {
    _endpointCurves.forEach((name, curve) {
      test('$name(0) == 0 and $name(1) == 1', () {
        expect(curve(0.0), closeTo(0.0, 1e-9), reason: '$name at t=0');
        expect(curve(1.0), closeTo(1.0, 1e-9), reason: '$name at t=1');
      });
    });
  });

  group('monotonic quadratic pair', () {
    test('easeInQuad(0.5) < 0.5', () {
      expect(Curves.easeInQuad(0.5), lessThan(0.5));
    });

    test('easeOutQuad(0.5) > 0.5', () {
      expect(Curves.easeOutQuad(0.5), greaterThan(0.5));
    });

    test('easeInOutQuad(0.5) == 0.5', () {
      expect(Curves.easeInOutQuad(0.5), closeTo(0.5, 1e-9));
    });
  });

  group('cubic pair', () {
    test('easeInCubic(0.5) < easeInQuad(0.5)', () {
      // Sharper accel means smaller value at the same t before 1.
      expect(Curves.easeInCubic(0.5), lessThan(Curves.easeInQuad(0.5)));
    });

    test('easeOutCubic(0.5) > easeOutQuad(0.5)', () {
      expect(Curves.easeOutCubic(0.5), greaterThan(Curves.easeOutQuad(0.5)));
    });
  });

  group('bounce and elastic within bounds at midpoint', () {
    test('bounceOut(0.5) is well-defined and non-negative', () {
      final v = Curves.bounceOut(0.5);
      expect(v, greaterThanOrEqualTo(0.0));
      expect(v, lessThanOrEqualTo(1.0));
    });

    test('elasticOut overshoots then settles', () {
      // Somewhere in the middle it should exceed 1 before returning.
      final overshoot = <double>[];
      for (var i = 0; i <= 20; i++) {
        overshoot.add(Curves.elasticOut(i / 20));
      }
      expect(
        overshoot.any((v) => v > 1.0),
        isTrue,
        reason: 'expected elasticOut to overshoot 1',
      );
      expect(overshoot.last, closeTo(1.0, 1e-9));
    });
  });

  group('linear is identity', () {
    for (final t in const [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0]) {
      test('linear($t) == $t', () {
        expect(Curves.linear(t), closeTo(t, 1e-12));
      });
    }
  });
}
