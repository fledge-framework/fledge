import 'package:fledge_debug/fledge_debug.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FrameStats', () {
    test('records deltas into the history buffer', () {
      final stats = FrameStats(historyCap: 3);
      stats.recordFrame(1 / 60);
      stats.recordFrame(1 / 60);
      stats.recordFrame(1 / 60);
      expect(stats.sampleCount, 3);
      // Oldest sample drops when the buffer overflows.
      stats.recordFrame(1 / 30);
      expect(stats.sampleCount, 3);
      expect(stats.maxFrameSeconds, closeTo(1 / 30, 1e-9));
    });

    test('ignores non-positive deltas', () {
      final stats = FrameStats();
      stats.recordFrame(-1.0);
      stats.recordFrame(0.0);
      expect(stats.sampleCount, 0);
      expect(stats.smoothedFps, 0.0);
    });

    test('smoothed FPS converges toward the instantaneous FPS', () {
      // With a constant 60Hz delta the exponential smoothing has to
      // land within 0.05 of the true value after a modest run — the
      // whole point of the smoothing is to avoid oscillation, so
      // convergence is guaranteed.
      final stats = FrameStats(smoothingFactor: 0.2);
      for (var i = 0; i < 200; i++) {
        stats.recordFrame(1 / 60);
      }
      expect(stats.smoothedFps, closeTo(60.0, 0.05));
    });

    test('p99 tracks the slow frame in the window', () {
      final stats = FrameStats(historyCap: 100);
      for (var i = 0; i < 99; i++) {
        stats.recordFrame(1 / 60);
      }
      stats.recordFrame(0.100); // 100ms stutter
      expect(stats.p99FrameSeconds, closeTo(0.100, 1e-9));
      // The average is roughly the 60Hz baseline plus one stutter
      // amortised across the 100-sample window — a hair above 60Hz.
      const expectedAvg = (99 * (1 / 60) + 0.100) / 100;
      expect(stats.avgFrameSeconds, closeTo(expectedAvg, 1e-9));
      // maxFrameSeconds surfaces the single slow frame verbatim.
      expect(stats.maxFrameSeconds, closeTo(0.100, 1e-9));
    });

    test('FrameStatsSystem pulls delta from WallTime', () async {
      final app = App()..addPlugin(const WallTimePlugin());
      app.insertResource(FrameStats());
      app.addSystem(const FrameStatsSystem(), schedule: Schedules.first);

      await app.tick();
      await Future.delayed(const Duration(milliseconds: 5));
      await app.tick();
      await Future.delayed(const Duration(milliseconds: 5));
      await app.tick();

      final stats = app.world.getResource<FrameStats>()!;
      // At least one non-zero delta made it through — the exact
      // number depends on OS scheduling, but a real host will give us
      // a positive sample after two frames.
      expect(stats.sampleCount, greaterThan(0));
    });
  });
}
