import 'package:fledge_audio/src/systems/spatial_audio_system.dart';
import 'package:flutter_test/flutter_test.dart';

double _att(double d, {double ref = 1, double max = 10, double rolloff = 1}) =>
    SpatialAudioSystem.calculateAttenuation(d, ref, max, rolloff);

void main() {
  group('SpatialAudioSystem attenuation', () {
    test('full volume inside the reference distance', () {
      expect(_att(0), 1.0);
      expect(_att(0.5), 1.0);
      expect(_att(1.0), 1.0);
    });

    test('silence at or beyond max distance', () {
      expect(_att(10), 0.0);
      expect(_att(999), 0.0);
    });

    test('linear falloff between ref and max', () {
      // ref=1, max=10 → range = 9.  At d=5.5 (halfway), attenuation = 0.5.
      expect(_att(5.5), closeTo(0.5, 1e-9));
      expect(_att(3.25), closeTo(0.75, 1e-9));
    });

    test('rolloff < 1 flattens the curve', () {
      // At the halfway point, rolloff=0.5 gives attenuation 0.75 instead of 0.5.
      expect(_att(5.5, rolloff: 0.5), closeTo(0.75, 1e-9));
    });

    test('rolloff > 1 is clamped at 0', () {
      // Aggressive rolloff can drive the formula negative; result must clamp.
      expect(_att(5.5, rolloff: 10), 0.0);
    });

    test('never returns outside [0, 1]', () {
      for (final d in [0.0, 1.0, 2.5, 5.5, 9.5, 10.0, 15.0]) {
        for (final r in [0.1, 1.0, 5.0]) {
          final v = _att(d, rolloff: r);
          expect(
            v,
            inInclusiveRange(0.0, 1.0),
            reason: 'd=$d rolloff=$r produced $v',
          );
        }
      }
    });
  });
}
