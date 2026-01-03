import 'package:fledge_ecs/src/archetype/archetype_id.dart';
import 'package:fledge_ecs/src/archetype/table.dart';
import 'package:fledge_ecs/src/component.dart';
import 'package:fledge_ecs/src/entity.dart';
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
  late ComponentId posId;
  late ComponentId velId;

  setUp(() {
    ComponentId.resetRegistry();
    posId = ComponentId.of<Position>();
    velId = ComponentId.of<Velocity>();
  });

  group('Table', () {
    test('starts empty', () {
      final archetype = ArchetypeId.of([posId, velId]);
      final table = Table(archetype);

      expect(table.isEmpty, isTrue);
      expect(table.length, equals(0));
    });

    test('add inserts entity and components', () {
      final archetype = ArchetypeId.of([posId, velId]);
      final table = Table(archetype);

      const entity = Entity(0, 0);
      final pos = Position(1, 2);
      final vel = Velocity(3, 4);

      final row = table.add(entity, {posId: pos, velId: vel});

      expect(row, equals(0));
      expect(table.length, equals(1));
      expect(table.entityAt(0), equals(entity));
    });

    test('getComponent retrieves stored component', () {
      final archetype = ArchetypeId.of([posId, velId]);
      final table = Table(archetype);

      const entity = Entity(0, 0);
      final pos = Position(1, 2);
      final vel = Velocity(3, 4);

      table.add(entity, {posId: pos, velId: vel});

      final retrievedPos = table.getComponent<Position>(0, posId);
      final retrievedVel = table.getComponent<Velocity>(0, velId);

      expect(retrievedPos, same(pos));
      expect(retrievedVel, same(vel));
    });

    test('getComponent returns null for missing component type', () {
      final archetype = ArchetypeId.of([posId]);
      final table = Table(archetype);

      const entity = Entity(0, 0);
      table.add(entity, {posId: Position(0, 0)});

      expect(table.getComponent<Velocity>(0, velId), isNull);
    });

    test('setComponent updates component value', () {
      final archetype = ArchetypeId.of([posId]);
      final table = Table(archetype);

      const entity = Entity(0, 0);
      table.add(entity, {posId: Position(0, 0)});

      final newPos = Position(10, 20);
      table.setComponent(0, posId, newPos);

      expect(table.getComponent<Position>(0, posId), same(newPos));
    });

    test('swapRemove removes last row without swap', () {
      final archetype = ArchetypeId.of([posId]);
      final table = Table(archetype);

      const e1 = Entity(0, 0);
      const e2 = Entity(1, 0);

      table.add(e1, {posId: Position(0, 0)});
      table.add(e2, {posId: Position(1, 1)});

      final moved = table.swapRemove(1);

      expect(moved, isNull);
      expect(table.length, equals(1));
      expect(table.entityAt(0), equals(e1));
    });

    test('swapRemove swaps with last row', () {
      final archetype = ArchetypeId.of([posId]);
      final table = Table(archetype);

      const e1 = Entity(0, 0);
      const e2 = Entity(1, 0);
      const e3 = Entity(2, 0);

      table.add(e1, {posId: Position(0, 0)});
      table.add(e2, {posId: Position(1, 1)});
      table.add(e3, {posId: Position(2, 2)});

      final moved = table.swapRemove(0);

      expect(moved, equals(e3));
      expect(table.length, equals(2));
      expect(table.entityAt(0), equals(e3));
      expect(table.entityAt(1), equals(e2));
    });

    test('extractRow returns all components', () {
      final archetype = ArchetypeId.of([posId, velId]);
      final table = Table(archetype);

      final pos = Position(1, 2);
      final vel = Velocity(3, 4);
      table.add(const Entity(0, 0), {posId: pos, velId: vel});

      final extracted = table.extractRow(0);

      expect(extracted[posId], same(pos));
      expect(extracted[velId], same(vel));
    });

    test('getColumn returns component column', () {
      final archetype = ArchetypeId.of([posId]);
      final table = Table(archetype);

      final pos1 = Position(1, 2);
      final pos2 = Position(3, 4);

      table.add(const Entity(0, 0), {posId: pos1});
      table.add(const Entity(1, 0), {posId: pos2});

      final column = table.getColumn(posId);

      expect(column, isNotNull);
      expect(column!.length, equals(2));
      expect(column[0], same(pos1));
      expect(column[1], same(pos2));
    });

    test('clear removes all entities', () {
      final archetype = ArchetypeId.of([posId]);
      final table = Table(archetype);

      table.add(const Entity(0, 0), {posId: Position(0, 0)});
      table.add(const Entity(1, 0), {posId: Position(1, 1)});

      table.clear();

      expect(table.isEmpty, isTrue);
    });
  });
}
