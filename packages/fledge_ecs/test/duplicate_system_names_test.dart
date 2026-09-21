import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:test/test.dart';

/// Regression coverage for Batch 4 #20 — two systems that share a
/// name must both participate in name-based ordering, and any
/// `after:` / `before:` targeting that name must fan out to every
/// match.
void main() {
  setUp(() {
    ComponentId.resetRegistry();
  });

  group('Duplicate system names in one schedule', () {
    test('two systems with the same name can coexist without dropping one',
        () async {
      final order = <String>[];
      final schedule = Scheduler();
      // Two independent systems named "propagate". Both should run.
      schedule.addSystem(
        FunctionSystem('propagate', run: (_) => order.add('propagate#1')),
      );
      schedule.addSystem(
        FunctionSystem('propagate', run: (_) => order.add('propagate#2')),
      );
      await schedule.run(World());
      expect(order.length, 2);
      expect(order.toSet(), {'propagate#1', 'propagate#2'});
    });

    test(
      'after: [name] runs downstream of EVERY registered system with that name',
      () async {
        final order = <String>[];
        final schedule = Scheduler();
        schedule.addSystem(
          FunctionSystem('propagate', run: (_) => order.add('p1')),
        );
        schedule.addSystem(
          FunctionSystem('propagate', run: (_) => order.add('p2')),
        );
        schedule.addSystem(
          FunctionSystem(
            'follow',
            after: ['propagate'],
            run: (_) => order.add('follow'),
          ),
        );
        await schedule.run(World());
        // Both propagate instances must land before follow, in some order.
        final pIndices = [order.indexOf('p1'), order.indexOf('p2')];
        expect(order.indexOf('follow'),
            greaterThan(pIndices[0].compareTo(pIndices[1]) < 0 ? pIndices[1] : pIndices[0]));
      },
    );

    test(
      'before: [name] runs upstream of EVERY registered system with that name',
      () async {
        final order = <String>[];
        final schedule = Scheduler();
        schedule.addSystem(
          FunctionSystem(
            'move',
            before: ['propagate'],
            run: (_) => order.add('move'),
          ),
        );
        schedule.addSystem(
          FunctionSystem('propagate', run: (_) => order.add('p1')),
        );
        schedule.addSystem(
          FunctionSystem('propagate', run: (_) => order.add('p2')),
        );
        await schedule.run(World());
        expect(order.indexOf('move'), 0);
        expect(order.indexOf('p1'), greaterThan(0));
        expect(order.indexOf('p2'), greaterThan(0));
      },
    );

    test(
      'ordering-by-name works when the duplicates straddle the ordering system',
      () async {
        // Registration order: propagate#1, follow (after: propagate),
        // propagate#2. Both propagates must run before follow.
        final order = <String>[];
        final schedule = Scheduler();
        schedule.addSystem(
          FunctionSystem('propagate', run: (_) => order.add('p1')),
        );
        schedule.addSystem(
          FunctionSystem(
            'follow',
            after: ['propagate'],
            run: (_) => order.add('follow'),
          ),
        );
        schedule.addSystem(
          FunctionSystem('propagate', run: (_) => order.add('p2')),
        );
        await schedule.run(World());
        // Both p1 and p2 must precede follow.
        expect(order.indexOf('p1'), lessThan(order.indexOf('follow')));
        expect(order.indexOf('p2'), lessThan(order.indexOf('follow')));
      },
    );

    test('checkScheduleOrdering does not misreport duplicate-name pairs', () {
      final app = App();
      // Two systems sharing a name that conflict on the same component.
      app.addSystem(
        FunctionSystem(
          'writer',
          writes: {ComponentId.of<_Marker>()},
          run: (_) {},
        ),
      );
      app.addSystem(
        FunctionSystem(
          'writer',
          writes: {ComponentId.of<_Marker>()},
          run: (_) {},
        ),
      );
      // With no ordering declared between them the pair IS a genuine
      // registration-order ambiguity — expected to be reported.
      final issues = app.checkScheduleOrdering();
      expect(issues, isNotEmpty);
      // Adding an explicit `after:` on either — targeting their shared
      // name — resolves it because ordering fans out to every match.
      // (Exercised in the ordering-by-name tests above.)
    });
  });
}

class _Marker {}
