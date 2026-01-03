import 'package:fledge_ecs/src/entity.dart';
import 'package:test/test.dart';

void main() {
  group('Entity', () {
    test('equality compares id and generation', () {
      const e1 = Entity(1, 0);
      const e2 = Entity(1, 0);
      const e3 = Entity(1, 1);
      const e4 = Entity(2, 0);

      expect(e1, equals(e2));
      expect(e1, isNot(equals(e3)));
      expect(e1, isNot(equals(e4)));
    });

    test('hashCode is consistent with equality', () {
      const e1 = Entity(1, 0);
      const e2 = Entity(1, 0);

      expect(e1.hashCode, equals(e2.hashCode));
    });

    test('placeholder entity has id -1', () {
      expect(Entity.placeholder.id, equals(-1));
      expect(Entity.placeholder.isPlaceholder, isTrue);
    });

    test('normal entities are not placeholders', () {
      const entity = Entity(0, 0);
      expect(entity.isPlaceholder, isFalse);
    });

    test('toString includes id and generation', () {
      const entity = Entity(5, 3);
      expect(entity.toString(), equals('Entity(5:3)'));
    });
  });

  group('EntityLocation', () {
    test('stores archetype index and row', () {
      final location = EntityLocation(2, 5);

      expect(location.archetypeIndex, equals(2));
      expect(location.row, equals(5));
    });

    test('row is mutable', () {
      final location = EntityLocation(2, 5);
      location.row = 10;

      expect(location.row, equals(10));
    });
  });

  group('EntityMeta', () {
    test('tracks generation and location', () {
      final meta = EntityMeta(3, EntityLocation(1, 2));

      expect(meta.generation, equals(3));
      expect(meta.isAlive, isTrue);
      expect(meta.location?.archetypeIndex, equals(1));
    });

    test('isAlive is false when location is null', () {
      final meta = EntityMeta(0);

      expect(meta.isAlive, isFalse);
    });
  });
}
