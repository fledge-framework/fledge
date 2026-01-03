import 'package:fledge_ecs/src/archetype/archetype_id.dart';
import 'package:fledge_ecs/src/component.dart';
import 'package:test/test.dart';

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

  group('ArchetypeId', () {
    test('empty archetype has no components', () {
      final archetype = ArchetypeId.empty();

      expect(archetype.isEmpty, isTrue);
      expect(archetype.length, equals(0));
    });

    test('creates archetype from component ids', () {
      final posId = ComponentId.of<Position>();
      final velId = ComponentId.of<Velocity>();

      final archetype = ArchetypeId.of([posId, velId]);

      expect(archetype.length, equals(2));
      expect(archetype.contains(posId), isTrue);
      expect(archetype.contains(velId), isTrue);
    });

    test('components are sorted', () {
      final velId = ComponentId.of<Velocity>(); // id 0
      final posId = ComponentId.of<Position>(); // id 1

      final archetype = ArchetypeId.of([posId, velId]);

      expect(archetype.components[0], equals(velId));
      expect(archetype.components[1], equals(posId));
    });

    test('equality ignores insertion order', () {
      final posId = ComponentId.of<Position>();
      final velId = ComponentId.of<Velocity>();

      final a1 = ArchetypeId.of([posId, velId]);
      final a2 = ArchetypeId.of([velId, posId]);

      expect(a1, equals(a2));
      expect(a1.hashCode, equals(a2.hashCode));
    });

    test('withComponent adds a component', () {
      final posId = ComponentId.of<Position>();
      final velId = ComponentId.of<Velocity>();

      final a1 = ArchetypeId.of([posId]);
      final a2 = a1.withComponent(velId);

      expect(a1.length, equals(1));
      expect(a2.length, equals(2));
      expect(a2.contains(posId), isTrue);
      expect(a2.contains(velId), isTrue);
    });

    test('withComponent returns same archetype if already contains', () {
      final posId = ComponentId.of<Position>();

      final a1 = ArchetypeId.of([posId]);
      final a2 = a1.withComponent(posId);

      expect(identical(a1, a2), isTrue);
    });

    test('withoutComponent removes a component', () {
      final posId = ComponentId.of<Position>();
      final velId = ComponentId.of<Velocity>();

      final a1 = ArchetypeId.of([posId, velId]);
      final a2 = a1.withoutComponent(velId);

      expect(a2.length, equals(1));
      expect(a2.contains(posId), isTrue);
      expect(a2.contains(velId), isFalse);
    });

    test('withoutComponent returns same archetype if not present', () {
      final posId = ComponentId.of<Position>();
      final velId = ComponentId.of<Velocity>();

      final a1 = ArchetypeId.of([posId]);
      final a2 = a1.withoutComponent(velId);

      expect(identical(a1, a2), isTrue);
    });

    test('containsAll checks for subset', () {
      final posId = ComponentId.of<Position>();
      final velId = ComponentId.of<Velocity>();
      final spriteId = ComponentId.of<Sprite>();

      final full = ArchetypeId.of([posId, velId, spriteId]);
      final partial = ArchetypeId.of([posId, velId]);
      final other = ArchetypeId.of([posId, spriteId]);

      expect(full.containsAll(partial), isTrue);
      expect(partial.containsAll(full), isFalse);
      expect(full.containsAll(other), isTrue);
    });

    test('containsAny checks for intersection', () {
      final posId = ComponentId.of<Position>();
      final velId = ComponentId.of<Velocity>();
      final spriteId = ComponentId.of<Sprite>();

      final a1 = ArchetypeId.of([posId, velId]);
      final a2 = ArchetypeId.of([velId, spriteId]);
      final a3 = ArchetypeId.of([spriteId]);

      expect(a1.containsAny(a2), isTrue);
      expect(a1.containsAny(a3), isFalse);
    });
  });
}
