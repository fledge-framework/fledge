import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:test/test.dart';

void main() {
  setUp(() {
    ComponentId.resetRegistry();
  });

  group('System ordering', () {
    test('after constraint orders systems', () async {
      final order = <String>[];
      final schedule = Scheduler();

      schedule.addSystem(
        FunctionSystem('first', run: (_) => order.add('first')),
      );

      schedule.addSystem(
        FunctionSystem(
          'second',
          after: ['first'],
          run: (_) => order.add('second'),
        ),
      );

      await schedule.run(World());

      expect(order, equals(['first', 'second']));
    });

    test('before constraint orders systems', () async {
      final order = <String>[];
      final schedule = Scheduler();

      schedule.addSystem(
        FunctionSystem(
          'first',
          before: ['second'],
          run: (_) => order.add('first'),
        ),
      );

      schedule.addSystem(
        FunctionSystem('second', run: (_) => order.add('second')),
      );

      await schedule.run(World());

      expect(order, equals(['first', 'second']));
    });

    test('before constraint works when added in reverse order', () async {
      final order = <String>[];
      final schedule = Scheduler();

      // Add second first
      schedule.addSystem(
        FunctionSystem('second', run: (_) => order.add('second')),
      );

      // Add first with before constraint - should still work
      schedule.addSystem(
        FunctionSystem(
          'first',
          before: ['second'],
          run: (_) => order.add('first'),
        ),
      );

      await schedule.run(World());

      expect(order, equals(['first', 'second']));
    });

    test('after constraint ignores missing systems', () async {
      final order = <String>[];
      final schedule = Scheduler();

      // System with after constraint for non-existent system
      schedule.addSystem(
        FunctionSystem(
          'lonely',
          after: ['nonexistent'],
          run: (_) => order.add('lonely'),
        ),
      );

      await schedule.run(World());

      expect(order, equals(['lonely']));
    });

    test('multiple after constraints', () async {
      final order = <String>[];
      final schedule = Scheduler();

      schedule.addSystem(
        FunctionSystem('first', run: (_) => order.add('first')),
      );

      schedule.addSystem(
        FunctionSystem('second', run: (_) => order.add('second')),
      );

      schedule.addSystem(
        FunctionSystem(
          'third',
          after: ['first', 'second'],
          run: (_) => order.add('third'),
        ),
      );

      await schedule.run(World());

      // Third must come after both first and second
      expect(order.indexOf('third'), greaterThan(order.indexOf('first')));
      expect(order.indexOf('third'), greaterThan(order.indexOf('second')));
    });

    test('multiple before constraints', () async {
      final order = <String>[];
      final schedule = Scheduler();

      schedule.addSystem(
        FunctionSystem(
          'first',
          before: ['second', 'third'],
          run: (_) => order.add('first'),
        ),
      );

      schedule.addSystem(
        FunctionSystem('second', run: (_) => order.add('second')),
      );

      schedule.addSystem(
        FunctionSystem('third', run: (_) => order.add('third')),
      );

      await schedule.run(World());

      // First must come before both second and third
      expect(order.indexOf('first'), lessThan(order.indexOf('second')));
      expect(order.indexOf('first'), lessThan(order.indexOf('third')));
    });

    test('chained ordering', () async {
      final order = <String>[];
      final schedule = Scheduler();

      schedule.addSystem(
        FunctionSystem('first', run: (_) => order.add('first')),
      );

      schedule.addSystem(
        FunctionSystem(
          'second',
          after: ['first'],
          run: (_) => order.add('second'),
        ),
      );

      schedule.addSystem(
        FunctionSystem(
          'third',
          after: ['second'],
          run: (_) => order.add('third'),
        ),
      );

      await schedule.run(World());

      expect(order, equals(['first', 'second', 'third']));
    });

    test('ordering combined with conflict detection', () async {
      final order = <String>[];
      final schedule = Scheduler();

      schedule.addSystem(
        FunctionSystem(
          'reader1',
          reads: {ComponentId.of<_Position>()},
          run: (_) => order.add('reader1'),
        ),
      );

      schedule.addSystem(
        FunctionSystem(
          'writer',
          writes: {ComponentId.of<_Position>()},
          after: ['reader1'],
          run: (_) => order.add('writer'),
        ),
      );

      schedule.addSystem(
        FunctionSystem(
          'reader2',
          reads: {ComponentId.of<_Position>()},
          after: ['writer'],
          run: (_) => order.add('reader2'),
        ),
      );

      await schedule.run(World());

      // Must maintain explicit ordering
      expect(order.indexOf('reader1'), lessThan(order.indexOf('writer')));
      expect(order.indexOf('writer'), lessThan(order.indexOf('reader2')));
    });

    test('independent systems run in any order', () async {
      final order = <String>[];
      final schedule = Scheduler();

      schedule.addSystem(FunctionSystem('a', run: (_) => order.add('a')));

      schedule.addSystem(FunctionSystem('b', run: (_) => order.add('b')));

      schedule.addSystem(FunctionSystem('c', run: (_) => order.add('c')));

      await schedule.run(World());

      // All systems ran
      expect(order.length, equals(3));
      expect(order.toSet(), equals({'a', 'b', 'c'}));
    });

    test('bidirectional constraints', () async {
      final order = <String>[];
      final schedule = Scheduler();

      schedule.addSystem(
        FunctionSystem(
          'first',
          before: ['middle'],
          run: (_) => order.add('first'),
        ),
      );

      schedule.addSystem(
        FunctionSystem(
          'middle',
          after: ['first'],
          before: ['last'],
          run: (_) => order.add('middle'),
        ),
      );

      schedule.addSystem(
        FunctionSystem(
          'last',
          after: ['middle'],
          run: (_) => order.add('last'),
        ),
      );

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
      final system = FunctionSystem('test', before: ['other'], run: (_) {});
      expect(system.meta.before, equals(['other']));
    });

    test('FunctionSystem passes after to meta', () {
      final system = FunctionSystem('test', after: ['other'], run: (_) {});
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

  group('Explicit ordering wins over conflict edges', () {
    test(
      'B declared before: A wins when A is registered first and B conflicts',
      () async {
        final order = <String>[];
        final schedule = Scheduler();

        schedule.addSystem(
          FunctionSystem(
            'A',
            writes: {ComponentId.of<_Position>()},
            run: (_) => order.add('A'),
          ),
        );

        schedule.addSystem(
          FunctionSystem(
            'B',
            writes: {ComponentId.of<_Position>()},
            before: ['A'],
            run: (_) => order.add('B'),
          ),
        );

        await schedule.run(World());

        expect(order, equals(['B', 'A']));
      },
    );

    test(
      'A declared after: B wins when A is registered first and B conflicts',
      () async {
        final order = <String>[];
        final schedule = Scheduler();

        schedule.addSystem(
          FunctionSystem(
            'A',
            writes: {ComponentId.of<_Position>()},
            after: ['B'],
            run: (_) => order.add('A'),
          ),
        );

        schedule.addSystem(
          FunctionSystem(
            'B',
            writes: {ComponentId.of<_Position>()},
            run: (_) => order.add('B'),
          ),
        );

        await schedule.run(World());

        expect(order, equals(['B', 'A']));
      },
    );

    test('pending before: on a not-yet-registered system wins', () async {
      final order = <String>[];
      final schedule = Scheduler();

      // B is added first, declaring `before: A`. A doesn't exist yet so
      // this goes through the pending-before path.
      schedule.addSystem(
        FunctionSystem(
          'B',
          writes: {ComponentId.of<_Position>()},
          before: ['A'],
          run: (_) => order.add('B'),
        ),
      );

      // A conflicts with B, but the pending-before entry must beat the
      // conflict-driven `A depends on B` that would otherwise be added.
      schedule.addSystem(
        FunctionSystem(
          'A',
          writes: {ComponentId.of<_Position>()},
          run: (_) => order.add('A'),
        ),
      );

      await schedule.run(World());

      expect(order, equals(['B', 'A']));
    });

    test('pending after: on a not-yet-registered system wins', () async {
      final order = <String>[];
      final schedule = Scheduler();

      // B declares `after: A` before A exists.
      schedule.addSystem(
        FunctionSystem(
          'B',
          writes: {ComponentId.of<_Position>()},
          after: ['A'],
          run: (_) => order.add('B'),
        ),
      );

      // Registering A must not add a `B depends on A` edge (from the
      // pending-after) and simultaneously an `A depends on B` conflict
      // edge; that would deadlock.
      schedule.addSystem(
        FunctionSystem(
          'A',
          writes: {ComponentId.of<_Position>()},
          run: (_) => order.add('A'),
        ),
      );

      await schedule.run(World());

      expect(order, equals(['A', 'B']));
    });

    test('real cycle in explicit ordering throws a clear error', () {
      final schedule = Scheduler();

      schedule.addSystem(FunctionSystem('A', before: ['B'], run: (_) {}));

      expect(
        () =>
            schedule.addSystem(FunctionSystem('B', before: ['A'], run: (_) {})),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('Cycle detected'), contains('A'), contains('B')),
          ),
        ),
      );
    });
  });

  group('App with system ordering', () {
    test('systems respect ordering in App', () async {
      final order = <String>[];
      final app = App();

      app.addSystem(
        FunctionSystem(
          'last',
          after: ['middle'],
          run: (_) => order.add('last'),
        ),
      );

      app.addSystem(
        FunctionSystem(
          'middle',
          after: ['first'],
          run: (_) => order.add('middle'),
        ),
      );

      app.addSystem(FunctionSystem('first', run: (_) => order.add('first')));

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
