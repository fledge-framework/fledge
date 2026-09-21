import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:test/test.dart';

/// Records the schedule name each time a spy runs. Used to reason
/// about interleaving between per-frame and fixed schedules.
class _Log {
  final List<String> entries = <String>[];
}

/// Trivial spy system that appends [tag] to the shared [_Log] resource.
class _SpySystem implements System {
  final String tag;
  @override
  final SystemMeta meta;

  _SpySystem(this.tag) : meta = SystemMeta(name: 'spy:$tag');

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) async {
    world.getResource<_Log>()!.entries.add(tag);
  }
}

void main() {
  group('FixedTimestep resource', () {
    test('is inserted by default at 60Hz', () {
      final app = App();
      final ts = app.world.getResource<FixedTimestep>();
      expect(ts, isNotNull);
      expect(ts!.stepDuration, equals(const Duration(microseconds: 16667)));
      expect(ts.maxCatchupSteps, equals(5));
      expect(ts.accumulatorSeconds, equals(0.0));
      expect(ts.stepsThisFrame, equals(0));
    });

    test('user override via insertResource wins', () {
      final app = App()
        ..insertResource(
          FixedTimestep(
            stepDuration: const Duration(milliseconds: 100),
            maxCatchupSteps: 3,
          ),
        );
      final ts = app.world.getResource<FixedTimestep>()!;
      expect(ts.stepDuration, equals(const Duration(milliseconds: 100)));
      expect(ts.maxCatchupSteps, equals(3));
    });
  });

  group('Scheduler.runFixedIfDue', () {
    test('50ms delta with 100ms step yields 0 fixed steps', () async {
      final ts = FixedTimestep(stepDuration: const Duration(milliseconds: 100));
      final scheduler = Scheduler();
      final world = World();

      final steps = await scheduler.runFixedIfDue(ts, 0.050, world);
      expect(steps, equals(0));
      expect(ts.stepsThisFrame, equals(0));
      expect(ts.accumulatorSeconds, closeTo(0.050, 1e-9));
    });

    test('100ms delta with 100ms step yields exactly 1 fixed step', () async {
      final ts = FixedTimestep(stepDuration: const Duration(milliseconds: 100));
      final scheduler = Scheduler();
      final world = World();

      final steps = await scheduler.runFixedIfDue(ts, 0.100, world);
      expect(steps, equals(1));
      expect(ts.stepsThisFrame, equals(1));
      expect(ts.accumulatorSeconds, closeTo(0.0, 1e-9));
    });

    test('250ms delta yields 2 steps and carries 50ms residual', () async {
      final ts = FixedTimestep(stepDuration: const Duration(milliseconds: 100));
      final scheduler = Scheduler();
      final world = World();

      final steps = await scheduler.runFixedIfDue(ts, 0.250, world);
      expect(steps, equals(2));
      expect(ts.accumulatorSeconds, closeTo(0.050, 1e-9));
    });

    test('catchup cap drops residual beyond maxCatchupSteps', () async {
      final ts = FixedTimestep(
        stepDuration: const Duration(milliseconds: 100),
        maxCatchupSteps: 3,
      );
      final scheduler = Scheduler();
      final world = World();

      // 1s / 100ms = 10 steps requested, but cap is 3.
      final steps = await scheduler.runFixedIfDue(ts, 1.0, world);
      expect(steps, equals(3));
      expect(ts.stepsThisFrame, equals(3));
      // Residual dropped to prevent spiral of death.
      expect(ts.accumulatorSeconds, equals(0.0));
    });

    test('each fixed iteration walks the fixed chain in order', () async {
      final ts = FixedTimestep(stepDuration: const Duration(milliseconds: 100));
      final scheduler = Scheduler();
      final world = World()..insertResource(_Log());

      scheduler.addSystemToSchedule(_SpySystem('first'), Schedules.fixedFirst);
      scheduler.addSystemToSchedule(
        _SpySystem('preUpdate'),
        Schedules.fixedPreUpdate,
      );
      scheduler.addSystemToSchedule(
        _SpySystem('update'),
        Schedules.fixedUpdate,
      );
      scheduler.addSystemToSchedule(
        _SpySystem('postUpdate'),
        Schedules.fixedPostUpdate,
      );
      scheduler.addSystemToSchedule(_SpySystem('last'), Schedules.fixedLast);

      // 210ms → 2 fixed iterations.
      final steps = await scheduler.runFixedIfDue(ts, 0.210, world);
      expect(steps, equals(2));

      expect(
        world.getResource<_Log>()!.entries,
        equals(<String>[
          'first',
          'preUpdate',
          'update',
          'postUpdate',
          'last',
          'first',
          'preUpdate',
          'update',
          'postUpdate',
          'last',
        ]),
      );
    });

    test('each fixed iteration advances the world tick counter', () async {
      final ts = FixedTimestep(stepDuration: const Duration(milliseconds: 100));
      final scheduler = Scheduler();
      final world = World();
      final tickBefore = world.tick.value;

      await scheduler.runFixedIfDue(ts, 0.250, world);
      // 2 iterations => 2 tick advances.
      expect(world.tick.value, equals(tickBefore + 2));
    });
  });

  group('App.tick fixed-vs-per-frame ordering', () {
    test('preUpdate → fixedUpdate → update in a single tick', () async {
      final app = App()
        ..insertResource(_Log())
        ..insertResource(
          FixedTimestep(
            stepDuration: const Duration(milliseconds: 1),
            maxCatchupSteps: 5,
          ),
        )
        ..addSystem(_SpySystem('preUpdate'), schedule: Schedules.preUpdate)
        ..addSystem(_SpySystem('fixedUpdate'), schedule: Schedules.fixedUpdate)
        ..addSystem(_SpySystem('update'), schedule: Schedules.update);

      // No Time resource → uses App's internal stopwatch, which returns
      // 0 on its first sample. Warm the clock with one tick, then sleep
      // so tick #2 sees a real delta larger than 1ms.
      await app.tick();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Isolate tick 2's ordering.
      app.world.getResource<_Log>()!.entries.clear();
      await app.tick();

      final log = app.world.getResource<_Log>()!.entries;
      expect(
        log.first,
        equals('preUpdate'),
        reason: 'preUpdate should be the first entry of tick 2',
      );
      expect(
        log.last,
        equals('update'),
        reason: 'update should be the last entry of tick 2',
      );
      expect(
        log,
        contains('fixedUpdate'),
        reason: 'fixed chain should have fired on the second tick',
      );

      final firstFixed = log.indexOf('fixedUpdate');
      final lastFixed = log.lastIndexOf('fixedUpdate');
      expect(firstFixed, greaterThan(log.indexOf('preUpdate')));
      expect(lastFixed, lessThan(log.indexOf('update')));
    });

    test('zero-fixed frame: all per-frame schedules still run', () async {
      final app = App()
        ..insertResource(_Log())
        // Huge step → no fixed iteration will fire on a single tick.
        ..insertResource(
          FixedTimestep(stepDuration: const Duration(seconds: 10)),
        )
        ..addSystem(_SpySystem('first'), schedule: Schedules.first)
        ..addSystem(_SpySystem('preUpdate'), schedule: Schedules.preUpdate)
        ..addSystem(_SpySystem('fixedUpdate'), schedule: Schedules.fixedUpdate)
        ..addSystem(_SpySystem('update'), schedule: Schedules.update)
        ..addSystem(_SpySystem('postUpdate'), schedule: Schedules.postUpdate)
        ..addSystem(_SpySystem('last'), schedule: Schedules.last);

      await app.tick();

      final log = app.world.getResource<_Log>()!.entries;
      expect(log, contains('first'));
      expect(log, contains('preUpdate'));
      expect(log, contains('update'));
      expect(log, contains('postUpdate'));
      expect(log, contains('last'));
      expect(
        log,
        isNot(contains('fixedUpdate')),
        reason: 'delta << 10s so no fixed step should fire',
      );
    });
  });
}
