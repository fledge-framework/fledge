import 'package:fledge_lighting_2d/fledge_lighting_2d.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('linearAttenuation', () {
    test('is 1.0 at the center', () {
      expect(linearAttenuation(0, 0, 100), 1.0);
    });

    test('is 0.5 at the midpoint of a 0..radius band', () {
      expect(linearAttenuation(50, 0, 100), closeTo(0.5, 1e-9));
    });

    test('is 0.0 at radius', () {
      expect(linearAttenuation(100, 0, 100), 0.0);
    });

    test('is 0.0 past radius', () {
      expect(linearAttenuation(150, 0, 100), 0.0);
    });

    test('respects innerRadius (full intensity inside)', () {
      expect(linearAttenuation(20, 40, 100), 1.0);
      expect(linearAttenuation(40, 40, 100), 1.0);
    });

    test('falloff starts at innerRadius', () {
      // 70 is halfway between 40 and 100 → 0.5
      expect(linearAttenuation(70, 40, 100), closeTo(0.5, 1e-9));
    });

    test('collapses to hard cutoff when innerRadius >= radius', () {
      expect(linearAttenuation(90, 100, 100), 1.0);
      expect(linearAttenuation(100, 100, 100), 0.0);
      expect(linearAttenuation(50, 100, 50), 0.0);
    });
  });
}
