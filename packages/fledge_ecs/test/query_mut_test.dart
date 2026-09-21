// Verifies that QueryMut is runtime-identical to Query.
//
// The QueryMut* types exist only as a nominal marker for the code generator
// (see @system docs). At runtime they must iterate the same tuples in the
// same order and yield the same live references as their read-only twins.

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

void main() {
  setUp(() {
    ComponentId.resetRegistry();
  });

  group('QueryMut runtime parity', () {
    test('queryMut2<A, B>().iter() yields the same tuples as query2<A, B>', () {
      final world = World();
      world.spawnWith([Position(1, 2), Velocity(3, 4)]);
      world.spawnWith([Position(5, 6), Velocity(7, 8)]);
      world.spawnWith([Position(9, 10), Velocity(11, 12)]);

      final ro = world
          .query2<Position, Velocity>()
          .iter()
          .map((r) => (r.$1, r.$2.x, r.$2.y, r.$3.dx, r.$3.dy))
          .toList();
      final rw = world
          .queryMut2<Position, Velocity>()
          .iter()
          .map((r) => (r.$1, r.$2.x, r.$2.y, r.$3.dx, r.$3.dy))
          .toList();

      expect(rw, equals(ro));
    });

    test('QueryMut1<A> and Query1<A> return identical (entity, component) '
        'sequences, and both yield live mutable references', () {
      final world = World();
      world.spawnWith([Position(0, 0)]);
      world.spawnWith([Position(1, 1)]);

      final ro = world.query1<Position>().iter().toList();
      final rw = world.queryMut1<Position>().iter().toList();

      expect(rw.length, equals(ro.length));
      for (var i = 0; i < ro.length; i++) {
        expect(rw[i].$1, equals(ro[i].$1));
        // Both queries hand out references to the same stored Position, so
        // mutating through either must be visible via a fresh query.
        expect(
          identical(rw[i].$2, ro[i].$2),
          isTrue,
          reason: 'QueryMut1 must return the same stored instance as Query1',
        );
      }

      // Mutation via QueryMut1 is visible on a subsequent read via Query1 —
      // this is the runtime property the code generator is relying on.
      for (final (_, pos) in world.queryMut1<Position>().iter()) {
        pos.x += 100;
      }
      final xs = world.query1<Position>().iter().map((r) => r.$2.x).toList();
      expect(xs, equals(<double>[100.0, 101.0]));
    });
  });
}
