import 'package:fledge_ecs/src/component.dart';
import 'package:test/test.dart';

// Test components
class Position {
  double x, y;
  Position(this.x, this.y);
}

class Velocity {
  double dx, dy;
  Velocity(this.dx, this.dy);
}

class Sprite {
  String name;
  Sprite(this.name);
}

void main() {
  setUp(() {
    ComponentId.resetRegistry();
  });

  group('ComponentId', () {
    test('of<T>() returns same id for same type', () {
      final id1 = ComponentId.of<Position>();
      final id2 = ComponentId.of<Position>();

      expect(id1, equals(id2));
    });

    test('of<T>() returns different ids for different types', () {
      final posId = ComponentId.of<Position>();
      final velId = ComponentId.of<Velocity>();

      expect(posId, isNot(equals(velId)));
    });

    test('ofType() works with runtime types', () {
      final pos = Position(0, 0);
      final id1 = ComponentId.ofType(pos.runtimeType);
      final id2 = ComponentId.of<Position>();

      expect(id1, equals(id2));
    });

    test('tryOf<T>() returns null for unregistered types', () {
      expect(ComponentId.tryOf<Position>(), isNull);

      ComponentId.of<Position>();
      expect(ComponentId.tryOf<Position>(), isNotNull);
    });

    test('ids are assigned sequentially', () {
      final id1 = ComponentId.of<Position>();
      final id2 = ComponentId.of<Velocity>();
      final id3 = ComponentId.of<Sprite>();

      expect(id1.id, equals(0));
      expect(id2.id, equals(1));
      expect(id3.id, equals(2));
    });

    test('compareTo orders by id', () {
      final id1 = ComponentId.of<Position>();
      final id2 = ComponentId.of<Velocity>();

      expect(id1.compareTo(id2), lessThan(0));
      expect(id2.compareTo(id1), greaterThan(0));
      expect(id1.compareTo(id1), equals(0));
    });

    test('resetRegistry clears all registrations', () {
      ComponentId.of<Position>();
      ComponentId.of<Velocity>();

      ComponentId.resetRegistry();

      final newId = ComponentId.of<Position>();
      expect(newId.id, equals(0));
    });
  });

  group('ComponentDescriptor', () {
    test('creates descriptor with correct id and type', () {
      final descriptor = ComponentDescriptor<Position>();

      expect(descriptor.id, equals(ComponentId.of<Position>()));
      expect(descriptor.type, equals(Position));
    });
  });
}
