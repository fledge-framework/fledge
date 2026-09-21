import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_tween/fledge_tween.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sets [WallTime.delta] each frame to the requested value.
///
/// WallTimePlugin uses a real stopwatch, so tests inject their own
/// [WallTime] resource and this system to feed it a deterministic
/// delta.
class _FixedDeltaSystem implements System {
  final double deltaSeconds;
  _FixedDeltaSystem(this.deltaSeconds);

  @override
  SystemMeta get meta =>
      const SystemMeta(name: 'fixedDelta', resourceWrites: {WallTime});

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    world.getResource<WallTime>()!.delta = deltaSeconds;
    return Future.value();
  }
}

App _appWithFixedDelta(double deltaSeconds) {
  final app = App()..insertResource(WallTime());
  // Prime delta before TweenSystem runs by putting the fixed-delta
  // writer in `first`.
  app.addSystem(_FixedDeltaSystem(deltaSeconds), schedule: Schedules.first);
  app.addPlugin(const TweenPlugin());
  return app;
}

void main() {
  group('TweenSystem — once mode', () {
    test('advances tween and samples the expected value each frame', () async {
      final samples = <double>[];
      final app = _appWithFixedDelta(0.5);

      app.world.spawn().insert(
        Tweener(
          tween: Tween<double>(
            from: 0,
            to: 100,
            duration: const Duration(seconds: 1),
            lerp: lerpDouble,
          ),
          onSample: (v) => samples.add(v as double),
        ),
      );

      // Frame 1: elapsed becomes 0.5s → sample == 50.
      await app.tick();
      expect(samples, [50]);

      // Frame 2: elapsed becomes 1.0s → sample == 100, completion fires.
      await app.tick();
      expect(samples.length, 2);
      expect(samples.last, 100);
    });

    test('onComplete fires exactly once and component is removed', () async {
      var completeCount = 0;
      final app = _appWithFixedDelta(0.5);

      final entity = app.world.spawnWith([
        Tweener(
          tween: Tween<double>(
            from: 0,
            to: 1,
            duration: const Duration(seconds: 1),
            lerp: lerpDouble,
          ),
          onSample: (_) {},
          onComplete: () => completeCount++,
        ),
      ]);

      await app.tick(); // elapsed = 0.5
      expect(completeCount, 0);
      expect(app.world.get<Tweener>(entity), isNotNull);

      await app.tick(); // elapsed = 1.0 → complete
      expect(completeCount, 1);
      expect(app.world.get<Tweener>(entity), isNull);

      // Ticking again shouldn't retrigger completion — the component is
      // gone, so onComplete must not fire.
      await app.tick();
      await app.tick();
      expect(completeCount, 1);
    });
  });

  group('TweenSystem — loop mode', () {
    test(
      'resets elapsed after each cycle and never fires onComplete',
      () async {
        var completeCount = 0;
        final samples = <double>[];
        final app = _appWithFixedDelta(0.6);

        app.world.spawn().insert(
          Tweener(
            tween: Tween<double>(
              from: 0,
              to: 1,
              duration: const Duration(seconds: 1),
              lerp: lerpDouble,
            ),
            onSample: (v) => samples.add(v as double),
            onComplete: () => completeCount++,
            loop: TweenLoopMode.loop,
          ),
        );

        // Frame 1: elapsed = 0.6 → sample ~ 0.6.
        await app.tick();
        // Frame 2: elapsed = 1.2 → clamps to 1.0, sampled value == 1.0,
        // then elapsed resets to 0.
        await app.tick();
        // Frame 3: elapsed = 0.6 again after reset → sample ~ 0.6.
        await app.tick();

        expect(completeCount, 0);
        expect(samples.length, 3);
        expect(samples[0], closeTo(0.6, 1e-9));
        expect(samples[1], closeTo(1.0, 1e-9));
        expect(samples[2], closeTo(0.6, 1e-9));
      },
    );
  });

  group('TweenSystem — pingPong mode', () {
    test('swaps direction and never fires onComplete', () async {
      var completeCount = 0;
      final samples = <double>[];
      final app = _appWithFixedDelta(0.6);

      app.world.spawn().insert(
        Tweener(
          tween: Tween<double>(
            from: 0,
            to: 1,
            duration: const Duration(seconds: 1),
            lerp: lerpDouble,
          ),
          onSample: (v) => samples.add(v as double),
          onComplete: () => completeCount++,
          loop: TweenLoopMode.pingPong,
        ),
      );

      // Frame 1: forward, elapsed 0.6 → ~0.6.
      await app.tick();
      // Frame 2: elapsed 1.2 → clamps at 1.0, sample == 1.0, then
      // direction flips to (from=1, to=0) with elapsed reset.
      await app.tick();
      // Frame 3: reverse, elapsed 0.6 → linear from 1 → 0 at t=0.6
      // gives 0.4.
      await app.tick();

      expect(completeCount, 0);
      expect(samples[0], closeTo(0.6, 1e-9));
      expect(samples[1], closeTo(1.0, 1e-9));
      expect(samples[2], closeTo(0.4, 1e-9));
    });
  });
}
