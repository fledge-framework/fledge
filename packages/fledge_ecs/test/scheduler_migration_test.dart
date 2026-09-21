import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:test/test.dart';

/// A trivial system that increments a counter each run. Used to verify
/// scheduling parity between the legacy `stage:` and new `schedule:`
/// parameters.
class _CounterSystem implements System {
  int count = 0;
  @override
  final SystemMeta meta;

  _CounterSystem(String name) : meta = SystemMeta(name: name);

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) async {
    count++;
  }
}

void main() {
  group('Scheduler migration', () {
    test(
        'legacy stage: CoreStage.update targets the same schedule as '
        'schedule: Schedules.update', () async {
      final legacy = _CounterSystem('legacy');
      final modern = _CounterSystem('modern');
      final app = App()
        // ignore: deprecated_member_use_from_same_package
        ..addSystem(legacy, stage: CoreStage.update)
        ..addSystem(modern, schedule: Schedules.update);

      // Both end up in the same stage.
      final updateStage = app.scheduler.getStage(Schedules.update.name);
      expect(updateStage, isNotNull);
      expect(updateStage!.length, equals(2));

      await app.tick();
      expect(legacy.count, equals(1));
      expect(modern.count, equals(1));
    });

    test('schedule: Schedules.foo runs in the corresponding per-frame stage',
        () async {
      final firstSys = _CounterSystem('first');
      final lastSys = _CounterSystem('last');
      final app = App()
        ..addSystem(firstSys, schedule: Schedules.first)
        ..addSystem(lastSys, schedule: Schedules.last);

      await app.tick();
      expect(firstSys.count, equals(1));
      expect(lastSys.count, equals(1));
    });

    test('passing both stage: and schedule: throws ArgumentError', () {
      final app = App();
      expect(
        // ignore: deprecated_member_use_from_same_package
        () => app.addSystem(_CounterSystem('boom'),
            stage: CoreStage.update, schedule: Schedules.update),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('custom Schedule via scheduler.addSchedule + addSystemToSchedule',
        () async {
      const custom = Schedule('post_physics');
      final sys = _CounterSystem('physics_step');
      final app = App()..scheduler.addSchedule(custom);
      app.scheduler.addSystemToSchedule(sys, custom);

      // Custom schedules aren't driven by the per-frame loop in Phase 1a,
      // but you can still invoke them manually via runSchedule.
      await app.scheduler.runSchedule(custom, app.world);
      expect(sys.count, equals(1));
    });

    test('addSystemToSchedule throws when the schedule is not registered', () {
      final scheduler = Scheduler.empty();
      expect(
        () => scheduler.addSystemToSchedule(
          _CounterSystem('orphan'),
          const Schedule('unregistered'),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('startup schedule auto-runs on the first tick, exactly once',
        () async {
      final startupSys = _CounterSystem('bootstrap');
      final app = App()..addSystem(startupSys, schedule: Schedules.startup);

      await app.tick();
      expect(startupSys.count, equals(1),
          reason: 'startup should auto-run on first tick (Phase 1c)');

      // Subsequent ticks and manual runStartup calls are idempotent.
      await app.tick();
      await app.runStartup();
      expect(startupSys.count, equals(1),
          reason: 'startup should not re-run after the first tick');
    });

    test('deprecated App.schedule getter still returns the scheduler', () {
      final app = App();
      // ignore: deprecated_member_use_from_same_package
      expect(identical(app.schedule, app.scheduler), isTrue);
    });
  });
}
