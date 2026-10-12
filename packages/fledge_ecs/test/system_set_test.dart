import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:test/test.dart';

void main() {
  setUp(() {
    ComponentId.resetRegistry();
  });

  group('SystemSet', () {
    test('has name', () {
      final set = SystemSet('physics');
      expect(set.name, equals('physics'));
    });

    test('after adds ordering constraint', () {
      final set = SystemSet('physics')..after('input');
      expect(set.afterList, equals(['input']));
    });

    test('before adds ordering constraint', () {
      final set = SystemSet('physics')..before('render');
      expect(set.beforeList, equals(['render']));
    });

    test('runIf sets condition', () {
      bool condition(World world) => true;
      final set = SystemSet('physics')..runIf(condition);
      expect(set.runCondition, equals(condition));
    });

    test('chaining works', () {
      final set = SystemSet('physics')
        ..after('input')
        ..before('render')
        ..runIf((world) => true);

      expect(set.afterList, equals(['input']));
      expect(set.beforeList, equals(['render']));
      expect(set.runCondition, isNotNull);
    });

    test('multiple after constraints', () {
      final set = SystemSet('physics')
        ..after('input')
        ..after('time');

      expect(set.afterList, equals(['input', 'time']));
    });

    test('multiple before constraints', () {
      final set = SystemSet('physics')
        ..before('render')
        ..before('ui');

      expect(set.beforeList, equals(['render', 'ui']));
    });
  });

  group('SystemSetRegistry', () {
    test('configure creates set', () {
      final registry = SystemSetRegistry();
      registry.configure('physics', (s) => s.after('input'));

      expect(registry.contains('physics'), isTrue);
      expect(registry.get('physics')?.afterList, equals(['input']));
    });

    test('configure updates existing set', () {
      final registry = SystemSetRegistry();
      registry.configure('physics', (s) => s.after('input'));
      registry.configure('physics', (s) => s.before('render'));

      final set = registry.get('physics')!;
      expect(set.afterList, equals(['input']));
      expect(set.beforeList, equals(['render']));
    });

    test('get returns null for missing set', () {
      final registry = SystemSetRegistry();
      expect(registry.get('missing'), isNull);
    });

    test('getOrCreate creates set if missing', () {
      final registry = SystemSetRegistry();
      final set = registry.getOrCreate('physics');

      expect(set.name, equals('physics'));
      expect(registry.contains('physics'), isTrue);
    });

    test('getOrCreate returns existing set', () {
      final registry = SystemSetRegistry();
      registry.configure('physics', (s) => s.after('input'));

      final set = registry.getOrCreate('physics');
      expect(set.afterList, equals(['input']));
    });
  });

  group('SetConfiguredSystem', () {
    test('applies set after constraints', () {
      final set = SystemSet('physics')..after('input');
      final inner = FunctionSystem('gravity', run: (_) {});
      final wrapped = SetConfiguredSystem(inner, set);

      expect(wrapped.meta.after, contains('input'));
    });

    test('applies set before constraints', () {
      final set = SystemSet('physics')..before('render');
      final inner = FunctionSystem('gravity', run: (_) {});
      final wrapped = SetConfiguredSystem(inner, set);

      expect(wrapped.meta.before, contains('render'));
    });

    test('combines set and system ordering', () {
      final set = SystemSet('physics')
        ..after('input')
        ..before('render');
      final inner = FunctionSystem(
        'gravity',
        after: ['time'],
        before: ['collision'],
        run: (_) {},
      );
      final wrapped = SetConfiguredSystem(inner, set);

      expect(wrapped.meta.after, containsAll(['input', 'time']));
      expect(wrapped.meta.before, containsAll(['render', 'collision']));
    });

    test('uses set runCondition', () {
      var conditionCalled = false;
      final set = SystemSet('physics')
        ..runIf((world) {
          conditionCalled = true;
          return true;
        });
      final inner = FunctionSystem('gravity', run: (_) {});
      final wrapped = SetConfiguredSystem(inner, set);

      wrapped.shouldRun(World());
      expect(conditionCalled, isTrue);
    });

    test('combines set and system runCondition with AND', () {
      var setCalled = false;
      var systemCalled = false;

      final set = SystemSet('physics')
        ..runIf((world) {
          setCalled = true;
          return true;
        });
      final inner = FunctionSystem(
        'gravity',
        runIf: (world) {
          systemCalled = true;
          return true;
        },
        run: (_) {},
      );
      final wrapped = SetConfiguredSystem(inner, set);

      final result = wrapped.shouldRun(World());
      expect(result, isTrue);
      expect(setCalled, isTrue);
      expect(systemCalled, isTrue);
    });

    test('combined runCondition returns false if set condition fails', () {
      final set = SystemSet('physics')..runIf((world) => false);
      final inner = FunctionSystem(
        'gravity',
        runIf: (world) => true,
        run: (_) {},
      );
      final wrapped = SetConfiguredSystem(inner, set);

      expect(wrapped.shouldRun(World()), isFalse);
    });

    test('combined runCondition returns false if system condition fails', () {
      final set = SystemSet('physics')..runIf((world) => true);
      final inner = FunctionSystem(
        'gravity',
        runIf: (world) => false,
        run: (_) {},
      );
      final wrapped = SetConfiguredSystem(inner, set);

      expect(wrapped.shouldRun(World()), isFalse);
    });

    test('preserves system meta fields', () {
      final set = SystemSet('physics');
      final inner = FunctionSystem(
        'gravity',
        reads: {ComponentId.of<_Position>()},
        writes: {ComponentId.of<_Velocity>()},
        exclusive: false,
        run: (_) {},
      );
      final wrapped = SetConfiguredSystem(inner, set);

      expect(wrapped.meta.name, equals('gravity'));
      expect(wrapped.meta.reads, contains(ComponentId.of<_Position>()));
      expect(wrapped.meta.writes, contains(ComponentId.of<_Velocity>()));
      expect(wrapped.meta.exclusive, isFalse);
    });

    test('runs inner system', () async {
      var ran = false;
      final set = SystemSet('physics');
      final inner = FunctionSystem('gravity', run: (_) => ran = true);
      final wrapped = SetConfiguredSystem(inner, set);

      await wrapped.run(World());
      expect(ran, isTrue);
    });
  });

  group('App system sets', () {
    test('configureSet creates and configures set', () async {
      final order = <String>[];
      final app = App();

      app.configureSet('physics', (s) => s.after('input'));

      app.addSystem(FunctionSystem('input', run: (_) => order.add('input')));

      app.addSystemToSet(
        FunctionSystem('gravity', run: (_) => order.add('gravity')),
        'physics',
      );

      await app.tick();

      expect(order, equals(['input', 'gravity']));
    });

    test('addSystemToSet applies set ordering', () async {
      final order = <String>[];
      final app = App();

      app.addSystem(FunctionSystem('input', run: (_) => order.add('input')));
      app.addSystem(FunctionSystem('render', run: (_) => order.add('render')));

      app.configureSet('physics', (s) => s.after('input').before('render'));

      app.addSystemToSet(
        FunctionSystem('gravity', run: (_) => order.add('gravity')),
        'physics',
      );

      app.addSystemToSet(
        FunctionSystem('collision', run: (_) => order.add('collision')),
        'physics',
      );

      await app.tick();

      // Physics systems should run after input and before render
      expect(order.indexOf('input'), lessThan(order.indexOf('gravity')));
      expect(order.indexOf('input'), lessThan(order.indexOf('collision')));
      expect(order.indexOf('gravity'), lessThan(order.indexOf('render')));
      expect(order.indexOf('collision'), lessThan(order.indexOf('render')));
    });

    test('addSystemToSet applies set run condition', () async {
      var physicsRan = false;
      var shouldRunPhysics = false;

      final app = App();

      app.configureSet('physics', (s) => s.runIf((world) => shouldRunPhysics));

      app.addSystemToSet(
        FunctionSystem('gravity', run: (_) => physicsRan = true),
        'physics',
      );

      // First tick - condition is false
      await app.tick();
      expect(physicsRan, isFalse);

      // Second tick - condition is true
      shouldRunPhysics = true;
      await app.tick();
      expect(physicsRan, isTrue);
    });

    test('addSystemToSet works without prior configureSet', () async {
      var ran = false;
      final app = App();

      // Add system to set that wasn't pre-configured
      app.addSystemToSet(
        FunctionSystem('gravity', run: (_) => ran = true),
        'physics',
      );

      await app.tick();
      expect(ran, isTrue);
    });

    test('multiple systems in set share configuration', () async {
      final order = <String>[];
      final app = App();

      app.addSystem(FunctionSystem('input', run: (_) => order.add('input')));

      app.configureSet('physics', (s) => s.after('input'));

      // Add multiple systems to set
      app.addSystemToSet(
        FunctionSystem('sys1', run: (_) => order.add('sys1')),
        'physics',
      );
      app.addSystemToSet(
        FunctionSystem('sys2', run: (_) => order.add('sys2')),
        'physics',
      );
      app.addSystemToSet(
        FunctionSystem('sys3', run: (_) => order.add('sys3')),
        'physics',
      );

      await app.tick();

      // All physics systems should run after input
      for (final sys in ['sys1', 'sys2', 'sys3']) {
        expect(
          order.indexOf('input'),
          lessThan(order.indexOf(sys)),
          reason: '$sys should run after input',
        );
      }
    });
  });

  group('Set-based ordering', () {
    FunctionSystem logSys(
      String name,
      List<String> order, {
      Set<Type> resourceWrites = const {},
      List<String> before = const [],
      List<String> after = const [],
      List<String> sets = const [],
    }) => FunctionSystem(
      name,
      resourceWrites: resourceWrites,
      before: before,
      after: after,
      sets: sets,
      run: (_) => order.add(name),
    );

    test('original repro: set after set runs in declared order', () async {
      final order = <String>[];
      final app = App();
      app.configureSet('late', (s) => s.after('early'));
      app.addSystemToSet(logSys('b', order, resourceWrites: {_Res}), 'late');
      app.addSystemToSet(logSys('a', order, resourceWrites: {_Res}), 'early');

      await app.tick();

      expect(order, equals(['a', 'b']));
      expect(app.checkScheduleOrdering(), isEmpty);
    });

    for (final membersFirst in [true, false]) {
      final when = membersFirst ? 'members first' : 'members last';

      test('system after: naming a set runs after members ($when)', () async {
        final order = <String>[];
        final app = App();
        void addMembers() {
          app.addSystemToSet(
            logSys('m1', order, resourceWrites: {_Res}),
            'physics',
          );
          app.addSystemToSet(logSys('m2', order), 'physics');
        }

        void addFollower() {
          app.addSystem(
            logSys(
              'follower',
              order,
              resourceWrites: {_Res},
              after: ['physics'],
            ),
          );
        }

        if (membersFirst) {
          addMembers();
          addFollower();
        } else {
          addFollower();
          addMembers();
        }

        await app.tick();

        expect(order.last, 'follower');
        expect(app.checkScheduleOrdering(), isEmpty);
      });

      test('system before: naming a set runs before members ($when)', () async {
        final order = <String>[];
        final app = App();
        void addMembers() {
          app.addSystemToSet(
            logSys('m1', order, resourceWrites: {_Res}),
            'physics',
          );
          app.addSystemToSet(logSys('m2', order), 'physics');
        }

        void addLeader() {
          app.addSystem(
            logSys(
              'leader',
              order,
              resourceWrites: {_Res},
              before: ['physics'],
            ),
          );
        }

        if (membersFirst) {
          addMembers();
          addLeader();
        } else {
          addLeader();
          addMembers();
        }

        await app.tick();

        expect(order.first, 'leader');
        expect(app.checkScheduleOrdering(), isEmpty);
      });
    }

    test('set -> set edges hold and silence member conflicts', () async {
      final order = <String>[];
      final app = App();
      app.configureSet('render', (s) => s.after('physics'));
      app.configureSet('physics', (s) => s.after('input'));
      // Register against the desired order.
      app.addSystemToSet(
        logSys('draw', order, resourceWrites: {_Res}),
        'render',
      );
      app.addSystemToSet(
        logSys('collide', order, resourceWrites: {_Res}),
        'physics',
      );
      app.addSystemToSet(
        logSys('keys', order, resourceWrites: {_Res}),
        'input',
      );

      await app.tick();

      expect(order, equals(['keys', 'collide', 'draw']));
      expect(app.checkScheduleOrdering(), isEmpty);
    });

    test('empty middle set bridges a chain', () async {
      final order = <String>[];
      final app = App();
      app.configureSet('A', (s) => s.before('B'));
      app.configureSet('B', (s) => s.before('C'));
      app.addSystemToSet(logSys('c', order, resourceWrites: {_Res}), 'C');
      app.addSystemToSet(logSys('a', order, resourceWrites: {_Res}), 'A');

      await app.tick();

      expect(order, equals(['a', 'c']));
      expect(app.checkScheduleOrdering(), isEmpty);
    });

    test('configureSet after addSystemToSet is honoured', () async {
      final order = <String>[];
      final app = App();
      app.addSystemToSet(logSys('b', order, resourceWrites: {_Res}), 'late');
      app.addSystemToSet(logSys('a', order, resourceWrites: {_Res}), 'early');
      expect(app.checkScheduleOrdering(), hasLength(1));

      app.configureSet('late', (s) => s.after('early'));

      await app.tick();

      expect(order, equals(['a', 'b']));
      expect(app.checkScheduleOrdering(), isEmpty);
    });

    test('FunctionSystem(sets:) joins a set without a wrapper', () async {
      final order = <String>[];
      final app = App();
      app.configureSet('late', (s) => s.after('early'));
      app.addSystem(logSys('b', order, resourceWrites: {_Res}, sets: ['late']));
      app.addSystem(
        logSys('a', order, resourceWrites: {_Res}, sets: ['early']),
      );

      await app.tick();

      expect(order, equals(['a', 'b']));
      expect(app.checkScheduleOrdering(), isEmpty);
    });

    test('FunctionSystem and AsyncFunctionSystem pass sets to meta', () {
      expect(
        FunctionSystem('x', sets: ['s'], run: (_) {}).meta.sets,
        equals(['s']),
      );
      expect(
        AsyncFunctionSystem('x', sets: ['s'], run: (_) async {}).meta.sets,
        equals(['s']),
      );
      expect(const SystemMeta(name: 'x').sets, isEmpty);
    });

    test('SetConfiguredSystem records set membership', () {
      final wrapped = SetConfiguredSystem(
        FunctionSystem('g', sets: ['inner'], run: (_) {}),
        SystemSet('physics'),
      );
      expect(wrapped.meta.sets, equals(['physics', 'inner']));
    });

    test('cycle through sets errors with system and set names', () async {
      final app = App();
      app.configureSet('A', (s) => s.before('B'));
      app.addSystemToSet(FunctionSystem('a1', run: (_) {}), 'A');
      app.addSystemToSet(FunctionSystem('b1', run: (_) {}), 'B');

      expect(
        () => app.configureSet('B', (s) => s.before('A')),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('Cycle detected'),
              contains('a1'),
              contains('b1'),
              contains('[A]'),
              contains('[B]'),
            ),
          ),
        ),
      );
      // Rejected configuration is rolled back.
      expect(app.scheduler.sets.get('B')?.beforeList ?? const [], isEmpty);
      await app.tick();
    });

    test('cycle through sets at addSystem time fails fast', () {
      final app = App();
      app.configureSet('A', (s) => s.before('B'));
      app.addSystemToSet(FunctionSystem('a1', run: (_) {}), 'A');
      expect(
        () => app.addSystemToSet(
          FunctionSystem('b1', before: ['a1'], run: (_) {}),
          'B',
        ),
        throwsA(isA<StateError>()),
      );
      // The offending system was rolled back.
      expect(app.scheduler.getStage(Schedules.update.name)!.length, 1);
    });

    test('set configuration survives resetToSessionCheckpoint', () async {
      final order = <String>[];
      final app = App();
      app.configureSet('late', (s) => s.after('early'));
      app.markSessionCheckpoint();
      void gamePlugin(App a) {
        a.addSystemToSet(logSys('b', order, resourceWrites: {_Res}), 'late');
        a.addSystemToSet(logSys('a', order, resourceWrites: {_Res}), 'early');
      }

      app.addPlugin(_FnPlugin(gamePlugin));
      app.resetToSessionCheckpoint();
      expect(app.scheduler.systemCount, 0);
      expect(app.scheduler.sets.get('late')!.afterList, equals(['early']));

      app.addPlugin(_FnPlugin(gamePlugin));
      await app.tick();
      expect(order, equals(['a', 'b']));
    });

    test('Scheduler.clear keeps set configuration', () {
      final scheduler = Scheduler();
      scheduler.configureSet('late', (s) => s.after('early'));
      scheduler.addSystem(FunctionSystem('x', sets: ['late'], run: (_) {}));
      scheduler.clear();
      expect(scheduler.systemCount, 0);
      expect(scheduler.sets.contains('late'), isTrue);
    });

    test('SystemSet before/after do not store duplicates', () {
      final set = SystemSet('s')
        ..after('a')
        ..after('a')
        ..before('b')
        ..before('b');
      expect(set.afterList, equals(['a']));
      expect(set.beforeList, equals(['b']));
    });
  });
}

class _Res {}

class _FnPlugin extends Plugin {
  final void Function(App) _build;
  _FnPlugin(this._build);

  @override
  void build(App app) => _build(app);
}

// Test components
class _Position {
  double x, y;
  _Position(this.x, this.y);
}

class _Velocity {
  double dx, dy;
  _Velocity(this.dx, this.dy);
}
