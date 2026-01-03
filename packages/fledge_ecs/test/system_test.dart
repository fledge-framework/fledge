import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:test/test.dart';

class Position {
  double x, y;
  Position(this.x, this.y);
}

class Velocity {
  double dx, dy;
  Velocity(this.dx, this.dy);
}

class Health {
  int value;
  Health(this.value);
}

void main() {
  setUp(() {
    ComponentId.resetRegistry();
  });

  group('SystemMeta', () {
    test('no conflict when no overlapping access', () {
      final meta1 = SystemMeta(
        name: 'system1',
        reads: {ComponentId.of<Position>()},
      );
      final meta2 = SystemMeta(
        name: 'system2',
        reads: {ComponentId.of<Velocity>()},
      );

      expect(meta1.conflictsWith(meta2), isFalse);
    });

    test('no conflict when both only read same component', () {
      final posId = ComponentId.of<Position>();
      final meta1 = SystemMeta(name: 'system1', reads: {posId});
      final meta2 = SystemMeta(name: 'system2', reads: {posId});

      expect(meta1.conflictsWith(meta2), isFalse);
    });

    test('conflict when both write same component', () {
      final posId = ComponentId.of<Position>();
      final meta1 = SystemMeta(name: 'system1', writes: {posId});
      final meta2 = SystemMeta(name: 'system2', writes: {posId});

      expect(meta1.conflictsWith(meta2), isTrue);
    });

    test('conflict when one writes what other reads', () {
      final posId = ComponentId.of<Position>();
      final meta1 = SystemMeta(name: 'system1', writes: {posId});
      final meta2 = SystemMeta(name: 'system2', reads: {posId});

      expect(meta1.conflictsWith(meta2), isTrue);
      expect(meta2.conflictsWith(meta1), isTrue);
    });

    test('exclusive system conflicts with everything', () {
      const meta1 = SystemMeta(name: 'exclusive', exclusive: true);
      const meta2 = SystemMeta(name: 'normal');

      expect(meta1.conflictsWith(meta2), isTrue);
      expect(meta2.conflictsWith(meta1), isTrue);
    });

    test('resource read-read does not conflict', () {
      const meta1 = SystemMeta(name: 's1', resourceReads: {int});
      const meta2 = SystemMeta(name: 's2', resourceReads: {int});

      expect(meta1.conflictsWith(meta2), isFalse);
    });

    test('resource write-write conflicts', () {
      const meta1 = SystemMeta(name: 's1', resourceWrites: {int});
      const meta2 = SystemMeta(name: 's2', resourceWrites: {int});

      expect(meta1.conflictsWith(meta2), isTrue);
    });

    test('resource read-write conflicts', () {
      const meta1 = SystemMeta(name: 's1', resourceReads: {int});
      const meta2 = SystemMeta(name: 's2', resourceWrites: {int});

      expect(meta1.conflictsWith(meta2), isTrue);
    });
  });

  group('FunctionSystem', () {
    test('runs function on world', () {
      final world = World();
      world.spawnWith([Position(0, 0), Velocity(1, 1)]);

      final system = FunctionSystem(
        'movement',
        writes: {ComponentId.of<Position>()},
        reads: {ComponentId.of<Velocity>()},
        run: (world) {
          for (final (_, pos, vel)
              in world.query2<Position, Velocity>().iter()) {
            pos.x += vel.dx;
            pos.y += vel.dy;
          }
        },
      );

      system.run(world);

      final pos = world.query1<Position>().single()?.$2;
      expect(pos?.x, equals(1));
      expect(pos?.y, equals(1));
    });
  });

  group('Schedule', () {
    test('runs systems in stage order', () async {
      final world = World();
      final order = <String>[];

      final schedule = Schedule()
        ..addSystem(
          FunctionSystem('first', run: (_) => order.add('first')),
          stage: CoreStage.first,
        )
        ..addSystem(
          FunctionSystem('preUpdate', run: (_) => order.add('preUpdate')),
          stage: CoreStage.preUpdate,
        )
        ..addSystem(
          FunctionSystem('update', run: (_) => order.add('update')),
          stage: CoreStage.update,
        )
        ..addSystem(
          FunctionSystem('postUpdate', run: (_) => order.add('postUpdate')),
          stage: CoreStage.postUpdate,
        )
        ..addSystem(
          FunctionSystem('last', run: (_) => order.add('last')),
          stage: CoreStage.last,
        );

      await schedule.run(world);

      expect(order,
          equals(['first', 'preUpdate', 'update', 'postUpdate', 'last']));
    });

    test('runs non-conflicting systems in parallel', () async {
      final world = World();
      final startTimes = <String, DateTime>{};
      final endTimes = <String, DateTime>{};

      // Two systems that read different components
      final schedule = Schedule()
        ..addSystem(AsyncFunctionSystem(
          'system1',
          reads: {ComponentId.of<Position>()},
          run: (_) async {
            startTimes['system1'] = DateTime.now();
            await Future.delayed(const Duration(milliseconds: 50));
            endTimes['system1'] = DateTime.now();
          },
        ))
        ..addSystem(AsyncFunctionSystem(
          'system2',
          reads: {ComponentId.of<Velocity>()},
          run: (_) async {
            startTimes['system2'] = DateTime.now();
            await Future.delayed(const Duration(milliseconds: 50));
            endTimes['system2'] = DateTime.now();
          },
        ));

      await schedule.run(world);

      // Both should have started (parallel execution)
      expect(startTimes.length, equals(2));
      expect(endTimes.length, equals(2));
    });

    test('runs conflicting systems sequentially', () async {
      final world = World();
      final order = <String>[];

      final posId = ComponentId.of<Position>();

      final schedule = Schedule()
        ..addSystem(FunctionSystem(
          'writer1',
          writes: {posId},
          run: (_) => order.add('writer1'),
        ))
        ..addSystem(FunctionSystem(
          'writer2',
          writes: {posId},
          run: (_) => order.add('writer2'),
        ));

      await schedule.run(world);

      // Should run in order due to conflict
      expect(order, equals(['writer1', 'writer2']));
    });

    test('systemCount returns total systems', () {
      final schedule = Schedule()
        ..addSystem(FunctionSystem('s1', run: (_) {}))
        ..addSystem(FunctionSystem('s2', run: (_) {}))
        ..addSystem(FunctionSystem('s3', run: (_) {}), stage: CoreStage.first);

      expect(schedule.systemCount, equals(3));
    });
  });

  group('SystemStage', () {
    test('empty stage runs without error', () async {
      final stage = SystemStage('empty');
      final world = World();

      await stage.run(world);
      // Should complete without error
    });
  });
}
