import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:test/test.dart';

class _Position {
  double x = 0;
  double y = 0;
}

class _Velocity {
  double x = 0;
  double y = 0;
}

class _Time {
  double delta = 0;
}

class _NoopSystem implements System {
  @override
  final SystemMeta meta;
  _NoopSystem(this.meta);

  @override
  RunCondition? get runCondition => null;
  @override
  bool shouldRun(World world) => true;
  @override
  void run(World world) {}
}

class ClampSystem implements System {
  static const String systemName = 'clamp';

  @override
  SystemMeta get meta =>
      SystemMeta(name: systemName, writes: {ComponentId.of<_Velocity>()});
  @override
  RunCondition? get runCondition => null;
  @override
  bool shouldRun(World world) => true;
  @override
  void run(World world) {}
}

class SteerSystem implements System {
  static const String systemName = 'steer';

  @override
  SystemMeta get meta =>
      SystemMeta(name: systemName, writes: {ComponentId.of<_Velocity>()});
  @override
  RunCondition? get runCondition => null;
  @override
  bool shouldRun(World world) => true;
  @override
  void run(World world) {}
}

void main() {
  group('OrderingAmbiguity suggestion', () {
    test('names the systemName constants of class-based systems', () {
      final schedule = Scheduler()
        ..addSystem(SteerSystem())
        ..addSystem(ClampSystem());

      final issue = schedule.checkOrderingAmbiguities().single;
      expect(issue.systemAClass, 'SteerSystem');
      expect(issue.systemBClass, 'ClampSystem');
      expect(issue.suggestion, contains('before: [ClampSystem.systemName]'));
      expect(issue.suggestion, contains('after: [SteerSystem.systemName]'));
      expect(issue.toString(), isNot(contains("'clamp'")));
    });

    test('looks through set wrappers', () {
      final app = App()
        ..addSystem(SteerSystem())
        ..addSystemToSet(ClampSystem(), 'limits');

      final issue = app.checkScheduleOrdering().single;
      expect(issue.suggestion, contains('before: [ClampSystem.systemName]'));
    });

    test('describes the constant when the class is not known', () {
      final schedule = Scheduler()
        ..addSystem(
          FunctionSystem(
            'steer',
            writes: {ComponentId.of<_Velocity>()},
            run: (_) {},
          ),
        )
        ..addSystem(
          FunctionSystem(
            'clamp',
            writes: {ComponentId.of<_Velocity>()},
            run: (_) {},
          ),
        );

      final issue = schedule.checkOrderingAmbiguities().single;
      expect(issue.systemBClass, isNull);
      expect(issue.suggestion, contains("before: [<clamp's systemName>]"));
      expect(issue.toString(), isNot(contains("['clamp']")));
    });
  });

  group('Schedule.checkOrderingAmbiguities', () {
    test('no conflicts → no ambiguities', () {
      final schedule = Scheduler();
      schedule.addSystem(_NoopSystem(const SystemMeta(name: 'a')));
      schedule.addSystem(_NoopSystem(const SystemMeta(name: 'b')));
      expect(schedule.checkOrderingAmbiguities(), isEmpty);
    });

    test('two systems in different stages never conflict here', () {
      final schedule = Scheduler();
      schedule.addSystem(
        _NoopSystem(
          SystemMeta(name: 'a', writes: {ComponentId.of<_Velocity>()}),
        ),
        stage: CoreStage.preUpdate,
      );
      schedule.addSystem(
        _NoopSystem(
          SystemMeta(name: 'b', writes: {ComponentId.of<_Velocity>()}),
        ),
        stage: CoreStage.update,
      );
      expect(schedule.checkOrderingAmbiguities(), isEmpty);
    });

    test(
      'same-stage shared component write without explicit order is flagged',
      () {
        final schedule = Scheduler();
        schedule.addSystem(
          _NoopSystem(
            SystemMeta(name: 'resolve', writes: {ComponentId.of<_Velocity>()}),
          ),
        );
        schedule.addSystem(
          _NoopSystem(
            SystemMeta(name: 'input', writes: {ComponentId.of<_Velocity>()}),
          ),
        );

        final issues = schedule.checkOrderingAmbiguities();
        expect(issues, hasLength(1));
        expect(issues.single.stage, CoreStage.update.name);
        expect(issues.single.systemA, 'resolve');
        expect(issues.single.systemB, 'input');
        expect(issues.single.reasons.single, contains('both write component'));
        expect(
          issues.single.toString(),
          contains('by registration order only'),
        );
      },
    );

    test('explicit `before` silences the warning', () {
      final schedule = Scheduler();
      schedule.addSystem(
        _NoopSystem(
          SystemMeta(name: 'resolve', writes: {ComponentId.of<_Velocity>()}),
        ),
      );
      schedule.addSystem(
        _NoopSystem(
          SystemMeta(
            name: 'input',
            writes: {ComponentId.of<_Velocity>()},
            before: const ['resolve'],
          ),
        ),
      );
      expect(schedule.checkOrderingAmbiguities(), isEmpty);
    });

    test('explicit `after` silences the warning', () {
      final schedule = Scheduler();
      schedule.addSystem(
        _NoopSystem(
          SystemMeta(name: 'resolve', writes: {ComponentId.of<_Velocity>()}),
        ),
      );
      schedule.addSystem(
        _NoopSystem(
          SystemMeta(
            name: 'integrate',
            writes: {ComponentId.of<_Velocity>()},
            after: const ['resolve'],
          ),
        ),
      );
      expect(schedule.checkOrderingAmbiguities(), isEmpty);
    });

    test('resource write/read conflict is flagged and described', () {
      final schedule = Scheduler();
      schedule.addSystem(
        _NoopSystem(const SystemMeta(name: 'writer', resourceWrites: {_Time})),
      );
      schedule.addSystem(
        _NoopSystem(const SystemMeta(name: 'reader', resourceReads: {_Time})),
      );
      final issues = schedule.checkOrderingAmbiguities();
      expect(issues, hasLength(1));
      expect(issues.single.reasons.single, contains('resource'));
      expect(issues.single.reasons.single, contains('_Time'));
    });

    test('component write-read conflict is flagged in the right direction', () {
      final schedule = Scheduler();
      schedule.addSystem(
        _NoopSystem(
          SystemMeta(name: 'writer', writes: {ComponentId.of<_Position>()}),
        ),
      );
      schedule.addSystem(
        _NoopSystem(
          SystemMeta(name: 'reader', reads: {ComponentId.of<_Position>()}),
        ),
      );
      final issues = schedule.checkOrderingAmbiguities();
      expect(issues, hasLength(1));
      expect(
        issues.single.reasons.single,
        equals('_Position: writer writes, reader reads'),
      );
    });

    test('App exposes the check', () {
      final app = App();
      // Reuse the ambiguity scenario via addSystem on App:
      app.addSystem(
        _NoopSystem(
          SystemMeta(name: 'a', writes: {ComponentId.of<_Velocity>()}),
        ),
      );
      app.addSystem(
        _NoopSystem(
          SystemMeta(name: 'b', writes: {ComponentId.of<_Velocity>()}),
        ),
      );
      expect(app.checkScheduleOrdering(), hasLength(1));
    });
  });
}
