import 'package:fledge_tween/fledge_tween.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Tween<double>', () {
    Tween<double> makeLinear() => Tween<double>(
      from: 0,
      to: 100,
      duration: const Duration(seconds: 1),
      lerp: lerpDouble,
    );

    test('sample(0) == from', () {
      final t = makeLinear();
      expect(t.sample(Duration.zero), 0);
    });

    test('sample(duration) == to', () {
      final t = makeLinear();
      expect(t.sample(const Duration(seconds: 1)), 100);
    });

    test('sample(duration/2) is halfway for linear curve', () {
      final t = makeLinear();
      expect(t.sample(const Duration(milliseconds: 500)), closeTo(50, 1e-9));
    });

    test('sample clamps beyond duration', () {
      final t = makeLinear();
      expect(t.sample(const Duration(seconds: 5)), 100);
    });

    test('sample clamps negative to from', () {
      final t = makeLinear();
      expect(t.sample(const Duration(seconds: -1)), 0);
    });

    test('curve is applied', () {
      final t = Tween<double>(
        from: 0,
        to: 1,
        duration: const Duration(seconds: 1),
        curve: Curves.easeInQuad,
        lerp: lerpDouble,
      );
      // Halfway through under easeInQuad should be 0.25.
      expect(t.sample(const Duration(milliseconds: 500)), closeTo(0.25, 1e-9));
    });
  });

  group('Tween<int>', () {
    test('samples round to nearest integer', () {
      final t = Tween<int>(
        from: 0,
        to: 10,
        duration: const Duration(seconds: 1),
        lerp: lerpInt,
      );
      expect(t.sample(const Duration(milliseconds: 500)), 5);
      expect(t.sample(const Duration(milliseconds: 749)), 7);
      expect(t.sample(const Duration(milliseconds: 750)), 8);
    });
  });

  group('Tween<Offset>', () {
    test('samples on the segment between the two offsets', () {
      final t = Tween<Offset>(
        from: Offset.zero,
        to: const Offset(10, 20),
        duration: const Duration(seconds: 1),
        lerp: lerpOffset,
      );
      final mid = t.sample(const Duration(milliseconds: 500));
      expect(mid.dx, closeTo(5, 1e-9));
      expect(mid.dy, closeTo(10, 1e-9));
    });
  });

  group('Tween<Color>', () {
    test('samples blend the two colors', () {
      final t = Tween<Color>(
        from: const Color(0xFF000000),
        to: const Color(0xFFFFFFFF),
        duration: const Duration(seconds: 1),
        lerp: lerpColor,
      );
      final mid = t.sample(const Duration(milliseconds: 500));
      // Mid-grey is somewhere around 127 or 128 depending on interpolation.
      final r = (mid.r * 255).round();
      expect(r, inInclusiveRange(120, 135));
    });
  });

  test('positive duration is required', () {
    expect(
      () => Tween<double>(
        from: 0,
        to: 1,
        duration: Duration.zero,
        lerp: lerpDouble,
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
