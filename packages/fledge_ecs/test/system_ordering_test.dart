import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:test/test.dart';

void main() {
  setUp(() {
    ComponentId.resetRegistry();
  });

  group('System ordering', () {
    test('after constraint orders systems', () async {
      final order = <String>[];
      final schedule = Schedule();

      schedule.addSystem(FunctionSystem(
        'first',
        run: (_) => order.add('first'),
      ));

      schedule.addSystem(FunctionSystem(
        'second',
        after: ['first'],
        run: (_) => order.add('second'),
      ));

      await schedule.run(World());

      expect(order, equals(['first', 'second']));
    });

    test('before constraint orders systems', () async {
      final order = <String>[];
      final schedule = Schedule();

      schedule.addSystem(FunctionSystem(
        'first',
        before: ['second'],
        run: (_) => order.add('first'),
      ));

      schedule.addSystem(FunctionSystem(
        'second',
        run: (_) => order.add('second'),
      ));

      await schedule.run(World());

      expect(order, equals(['first', 'second']));
    });

    test('before constraint works when added in reverse order', () async {
      final order = <String>[];
      final schedule = Schedule();

      // Add second first
      schedule.addSystem(FunctionSystem(
        'second',
        run: (_) => order.add('second'),
      ));

      // Add first with before constraint - should still work
      schedule.addSystem(FunctionSystem(
        'first',
        before: ['second'],
        run: (_) => order.add('first'),
      ));

      await schedule.run(World());

      expect(order, equals(['first', 'second']));
    });

    test('after constraint ignores missing systems', () async {
      final order = <String>[];
      final schedule = Schedule();

      // System with after constraint for non-existent system
      schedule.addSystem(FunctionSystem(
        'lonely',
        after: ['nonexistent'],
        run: (_) => order.add('lonely'),
      ));

      await schedule.run(World());

      expect(order, equals(['lonely']));
    });

    test('multiple after constraints', () async {
      final order = <String>[];
      final schedule = Schedule();

      schedule.addSystem(FunctionSystem(
        'first',
        run: (_) => order.add('first'),
      ));

      schedule.addSystem(FunctionSystem(
        'second',
        run: (_) => order.add('second'),
      ));

      schedule.addSystem(FunctionSystem(
        'third',
        after: ['first', 'second'],
        run: (_) => order.add('third'),
      ));

      await schedule.run(World());

      // Third must come after both first and second
      expect(order.indexOf('third'), greaterThan(order.indexOf('first')));
      expect(order.indexOf('third'), greaterThan(order.indexOf('second')));
    });

    test('multiple before constraints', () async {
      final order = <String>[];
      final schedule = Schedule();

      schedule.addSystem(FunctionSystem(
        'first',
        before: ['second', 'third'],
        run: (_) => order.add('first'),
      ));

      schedule.addSystem(FunctionSystem(
        'second',
        run: (_) => order.add('second'),
      ));

      schedule.addSystem(FunctionSystem(
        'third',
        run: (_) => order.add('third'),
      ));

      await schedule.run(World());

      // First must come before both second and third
      expect(order.indexOf('first'), lessThan(order.indexOf('second')));
      expect(order.indexOf('first'), lessThan(order.indexOf('third')));
    });

    test('chained ordering', () async {
      final order = <String>[];
      final schedule = Schedule();

      schedule.addSystem(FunctionSystem(
        'first',
        run: (_) => order.add('first'),
      ));

      schedule.addSystem(FunctionSystem(
        'second',
        after: ['first'],
        run: (_) => order.add('second'),
      ));

      schedule.addSystem(FunctionSystem(
        'third',
        after: ['second'],
        run: (_) => order.add('third'),
      ));

      await schedule.run(World());

      expect(order, equals(['first', 'second', 'third']));
    });

    test('ordering combined with conflict detection', () async {
      final order = <String>[];
      final schedule = Schedule();

      schedule.addSystem(FunctionSystem(
        'reader1',
        reads: {ComponentId.of<_Position>()},
        run: (_) => order.add('reader1'),
      ));

      schedule.addSystem(FunctionSystem(
        'writer',
        writes: {ComponentId.of<_Position>()},
        after: ['reader1'],
        run: (_) => order.add('writer'),
      ));

      schedule.addSystem(FunctionSystem(
        'reader2',
        reads: {ComponentId.of<_Position>()},
        after: ['writer'],
        run: (_) => order.add('reader2'),
      ));

      await schedule.run(World());

      // Must maintain explicit ordering
      expect(order.indexOf('reader1'), lessThan(order.indexOf('writer')));
      expect(order.indexOf('writer'), lessThan(order.indexOf('reader2')));
    });

    test('independent systems run in any order', () async {
      final order = <String>[];
      final schedule = Schedule();

      schedule.addSystem(FunctionSystem(
        'a',
        run: (_) => order.add('a'),
      ));

      schedule.addSystem(FunctionSystem(
        'b',
        run: (_) => order.add('b'),
      ));

      schedule.addSystem(FunctionSystem(
        'c',
        run: (_) => order.add('c'),
      ));

      await schedule.run(World());

      // All systems ran
      expect(order.length, equals(3));
      expect(order.toSet(), equals({'a', 'b', 'c'}));
    });

    test('bidirectional constraints', () async {
      final order = <String>[];
      final schedule = Schedule();

      schedule.addSystem(FunctionSystem(
        'first',
        before: ['middle'],
        run: (_) => order.add('first'),
      ));

      schedule.addSystem(FunctionSystem(
        'middle',
        after: ['first'],
        before: ['last'],
        run: (_) => order.add('middle'),
      ));

      schedule.addSystem(FunctionSystem(
        'last',
        after: ['middle'],
        run: (_) => order.add('last'),
      ));

      await schedule.run(World());

      expect(order, equals(['first', 'middle', 'last']));
    });
  });

  group('SystemMeta ordering fields', () {
    test('before defaults to empty', () {
      const meta = SystemMeta(name: 'test');
      expect(meta.before, isEmpty);
    });

    test('after defaults to empty', () {
      const meta = SystemMeta(name: 'test');
      expect(meta.after, isEmpty);
    });

    test('FunctionSystem passes before to meta', () {
      final system = FunctionSystem(
        'test',
        before: ['other'],
        run: (_) {},
      );
      expect(system.meta.before, equals(['other']));
    });

    test('FunctionSystem passes after to meta', () {
      final system = FunctionSystem(
        'test',
        after: ['other'],
        run: (_) {},
      );
      expect(system.meta.after, equals(['other']));
    });

    test('AsyncFunctionSystem passes before to meta', () {
      final system = AsyncFunctionSystem(
        'test',
        before: ['other'],
        run: (_) async {},
      );
      expect(system.meta.before, equals(['other']));
    });

    test('AsyncFunctionSystem passes after to meta', () {
      final system = AsyncFunctionSystem(
        'test',
        after: ['other'],
        run: (_) async {},
      );
      expect(system.meta.after, equals(['other']));
    });
  });

  group('App with system ordering', () {
    test('systems respect ordering in App', () async {
      final order = <String>[];
      final app = App();

      app.addSystem(FunctionSystem(
        'last',
        after: ['middle'],
        run: (_) => order.add('last'),
      ));

      app.addSystem(FunctionSystem(
        'middle',
        after: ['first'],
        run: (_) => order.add('middle'),
      ));

      app.addSystem(FunctionSystem(
        'first',
        run: (_) => order.add('first'),
      ));

      await app.tick();

      expect(order, equals(['first', 'middle', 'last']));
    });
  });
}

// Test component
class _Position {
  double x, y;
  _Position(this.x, this.y);
}
