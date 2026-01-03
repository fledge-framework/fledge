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
      final condition = (World world) => true;
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

      app.configureSet(
          'physics', (s) => s.runIf((world) => shouldRunPhysics));

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
