import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:test/test.dart';

void main() {
  group('WallTime.frameIntervalFor', () {
    test('a rate just off a standard one counts as the standard rate', () {
      expect(
        WallTime.frameIntervalFor(59),
        const Duration(microseconds: 16667),
      );
      expect(WallTime.frameIntervalFor(59.94), WallTime.frameIntervalFor(60));
      expect(WallTime.frameIntervalFor(119), WallTime.frameIntervalFor(120));
      expect(WallTime.frameIntervalFor(143.9), WallTime.frameIntervalFor(144));
    });

    test('other rates are used as they are; unknown counts as 60 Hz', () {
      expect(
        WallTime.frameIntervalFor(85),
        const Duration(microseconds: 11765),
      );
      expect(WallTime.frameIntervalFor(0), WallTime.frameIntervalFor(60));
    });
  });

  group('WallTime.useClock', () {
    test('delta and elapsed follow the clock, from zero', () {
      var now = const Duration(seconds: 100);
      final time = WallTime()..useClock(() => now);

      now += const Duration(microseconds: 16667);
      time.update();
      expect(time.delta, closeTo(0.016667, 1e-9));
      expect(time.elapsed, closeTo(0.016667, 1e-9));

      now += const Duration(microseconds: 33333);
      time.update();
      expect(time.delta, closeTo(0.033333, 1e-9));
      expect(time.elapsed, closeTo(0.05, 1e-9));
      expect(time.frameCount, 2);
    });

    test('a clock that stands still or steps back adds no time', () {
      var now = const Duration(seconds: 1);
      final time = WallTime()..useClock(() => now);
      time.update();
      expect(time.delta, 0);
      now -= const Duration(milliseconds: 5);
      time.update();
      expect(time.delta, 0);
    });

    test('a frame interval rounds delta to whole refreshes', () {
      var now = Duration.zero;
      final time = WallTime()
        ..useClock(
          () => now,
          frameInterval: const Duration(microseconds: 16667),
        );
      // Wobbling timestamps: 15.1 and 18.3 ms apart, then a missed frame.
      for (final step in [15100, 18300, 33400, 16700]) {
        now += Duration(microseconds: step);
        time.update();
      }
      expect(time.delta, closeTo(0.016667, 1e-9));
      expect(time.elapsed, closeTo(0.016667 * 5, 1e-9));

      now += const Duration(microseconds: 15100);
      time.update();
      expect(time.delta, closeTo(0.016667, 1e-9));
      now += const Duration(microseconds: 33400);
      time.update();
      expect(time.delta, closeTo(0.033334, 1e-9));
      // A clock that didn't move still adds nothing.
      time.update();
      expect(time.delta, 0);
    });

    WallTime clocked(Duration Function() now, {double hz = 60}) =>
        WallTime()..useClock(now, frameInterval: WallTime.frameIntervalFor(hz));

    test('an early frame adds no time and hands it to the next', () {
      var now = Duration.zero;
      final time = clocked(() => now);
      final deltas = <double>[];
      // 16.7 ms frames with an extra one 7 ms after a refresh, then the
      // next 16 ms after that.
      for (final step in [16700, 16700, 7000, 16000, 16700, 16700]) {
        now += Duration(microseconds: step);
        time.update();
        deltas.add(time.delta);
      }
      expect(deltas[2], 0);
      for (final i in [0, 1, 3, 4, 5]) {
        expect(deltas[i], closeTo(1 / 60, 1e-6));
      }
      // Five refreshes' worth, not six.
      expect(time.elapsed, closeTo(5 / 60, 1e-5));
    });

    test('the interval is measured from the clock, whatever was reported', () {
      var now = Duration.zero;
      // The display says 60 Hz; it's really 144 Hz (moved to another
      // monitor), with a little wobble.
      final time = clocked(() => now);
      final wobble = [6600, 7300, 6900, 7000];
      for (var i = 0; i < 40; i++) {
        now += Duration(microseconds: wobble[i % wobble.length]);
        time.update();
      }
      expect(time.frameInterval, closeTo(1 / 144, 1e-6));
      expect(time.delta, closeTo(1 / 144, 1e-6));
    });

    test('a 59.9 Hz display is measured as 60 Hz', () {
      var now = Duration.zero;
      final time = clocked(() => now, hz: 59);
      for (var i = 0; i < 40; i++) {
        now += const Duration(microseconds: 16707);
        time.update();
      }
      expect(time.frameInterval, closeTo(1 / 60, 1e-6));
    });

    test('dropped frames still count, so a slow game keeps real time', () {
      var now = Duration.zero;
      final time = clocked(() => now);
      // Every other refresh missed.
      for (var i = 0; i < 40; i++) {
        now += const Duration(microseconds: 33333);
        time.update();
      }
      expect(time.elapsed, closeTo(40 * 0.033333, 0.001));
    });

    test('reset starts again from the clock\'s current reading', () {
      var now = Duration.zero;
      final time = WallTime()..useClock(() => now);
      now = const Duration(seconds: 5);
      time.update();
      time.reset();
      now += const Duration(milliseconds: 20);
      time.update();
      expect(time.delta, closeTo(0.02, 1e-9));
      expect(time.elapsed, closeTo(0.02, 1e-9));
    });
  });
}
