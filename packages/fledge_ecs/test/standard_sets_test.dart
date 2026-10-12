import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:test/test.dart';

class _Shared {}

class _Plugin implements Plugin {
  final List<System> systems;
  _Plugin(this.systems);

  @override
  void build(App app) {
    for (final s in systems) {
      app.addSystem(s, schedule: Schedules.first);
    }
  }

  @override
  void cleanup() {}
}

void main() {
  setUp(ComponentId.resetRegistry);

  group('FirstSets', () {
    test('chain lists the phases in order', () {
      expect(FirstSets.chain, [
        FirstSets.frameStart,
        FirstSets.platform,
        FirstSets.input,
        FirstSets.content,
      ]);
    });

    test('Scheduler() configures the chain', () {
      final scheduler = Scheduler();
      for (var i = 0; i + 1 < FirstSets.chain.length; i++) {
        final set = scheduler.sets.get(FirstSets.chain[i]);
        expect(set, isNotNull, reason: FirstSets.chain[i]);
        expect(set!.beforeList, [FirstSets.chain[i + 1]]);
      }
      expect(scheduler.sets.contains(FirstSets.content), isTrue);
    });

    test('Scheduler.empty() configures no sets', () {
      final scheduler = Scheduler.empty();
      expect(scheduler.sets.all, isEmpty);
    });

    test('chain survives Scheduler.clear and resetToSessionCheckpoint', () {
      final scheduler = Scheduler()..clear();
      expect(scheduler.sets.get(FirstSets.frameStart)!.beforeList, [
        FirstSets.platform,
      ]);

      final app = App()..markSessionCheckpoint();
      app.resetToSessionCheckpoint();
      for (var i = 0; i + 1 < FirstSets.chain.length; i++) {
        expect(app.scheduler.sets.get(FirstSets.chain[i])!.beforeList, [
          FirstSets.chain[i + 1],
        ]);
      }
    });

    test('later phases run after earlier phases regardless of '
        'registration order', () async {
      final order = <String>[];
      FunctionSystem phased(String name, String set) => FunctionSystem(
        name,
        sets: [set],
        resourceWrites: {_Shared},
        run: (_) => order.add(name),
      );

      // Register in reverse phase order.
      final app = App()
        ..insertResource(_Shared())
        ..addSystem(
          phased('content', FirstSets.content),
          schedule: Schedules.first,
        )
        ..addSystem(phased('input', FirstSets.input), schedule: Schedules.first)
        ..addSystem(
          phased('platform', FirstSets.platform),
          schedule: Schedules.first,
        )
        ..addSystem(
          phased('frameStart', FirstSets.frameStart),
          schedule: Schedules.first,
        );

      await app.tick();
      expect(order, ['frameStart', 'platform', 'input', 'content']);
      expect(app.checkScheduleOrdering(), isEmpty);
    });

    test(
      'phase order holds after reset (systems re-registered by plugin)',
      () async {
        final order = <String>[];
        FunctionSystem phased(String name, String set) => FunctionSystem(
          name,
          sets: [set],
          resourceWrites: {_Shared},
          run: (_) => order.add(name),
        );
        final app = App()
          ..insertResource(_Shared())
          ..addPlugin(
            _Plugin([
              phased('input', FirstSets.input),
              phased('frameStart', FirstSets.frameStart),
            ]),
          )
          ..markSessionCheckpoint();
        app.resetToSessionCheckpoint();
        await app.tick();
        expect(order, ['frameStart', 'input']);
      },
    );

    test('exclusive system in content is unambiguous with other phases', () {
      final app = App()
        ..addSystem(
          FunctionSystem(
            'spawn',
            exclusive: true,
            sets: [FirstSets.content],
            run: (_) {},
          ),
          schedule: Schedules.first,
        )
        ..addSystem(
          FunctionSystem(
            'poll',
            sets: [FirstSets.input],
            resourceWrites: {_Shared},
            run: (_) {},
          ),
          schedule: Schedules.first,
        )
        ..addSystem(
          FunctionSystem(
            'window',
            sets: [FirstSets.platform],
            resourceWrites: {_Shared},
            run: (_) {},
          ),
          schedule: Schedules.first,
        )
        ..addSystem(const WallTimeUpdateSystem(), schedule: Schedules.first);

      expect(app.checkScheduleOrdering(), isEmpty);
    });

    test('unphased exclusive system in first is still reported', () {
      final app = App()
        ..addSystem(const WallTimeUpdateSystem(), schedule: Schedules.first)
        ..addSystem(
          FunctionSystem('rogue', exclusive: true, run: (_) {}),
          schedule: Schedules.first,
        );

      final issues = app.checkScheduleOrdering();
      expect(issues, hasLength(1));
      expect(
        {issues.single.systemA, issues.single.systemB},
        {'rogue', WallTimeUpdateSystem.systemName},
      );
    });

    test('built-in frameStart systems join FirstSets.frameStart', () {
      expect(const WallTimeUpdateSystem().meta.sets, [FirstSets.frameStart]);
      expect(FrameStartSystem().meta.sets, [FirstSets.frameStart]);
    });
  });
}
