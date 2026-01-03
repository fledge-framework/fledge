import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:test/test.dart';

void main() {
  setUp(() {
    ComponentId.resetRegistry();
  });

  group('Parent component', () {
    test('stores parent entity', () {
      final parent = Entity(1, 0);
      final component = Parent(parent);
      expect(component.entity, equals(parent));
    });

    test('equality works', () {
      final parent = Entity(1, 0);
      expect(Parent(parent), equals(Parent(parent)));
      expect(Parent(parent), isNot(equals(Parent(Entity(2, 0)))));
    });

    test('hashCode is consistent', () {
      final parent = Entity(1, 0);
      expect(Parent(parent).hashCode, equals(Parent(parent).hashCode));
    });

    test('toString includes entity', () {
      final parent = Entity(1, 0);
      expect(Parent(parent).toString(), contains('1'));
    });
  });

  group('Children component', () {
    test('starts empty by default', () {
      final children = Children();
      expect(children.isEmpty, isTrue);
      expect(children.length, equals(0));
    });

    test('can be initialized with list', () {
      final e1 = Entity(1, 0);
      final e2 = Entity(2, 0);
      final children = Children([e1, e2]);
      expect(children.length, equals(2));
      expect(children.contains(e1), isTrue);
      expect(children.contains(e2), isTrue);
    });

    test('add adds child', () {
      final children = Children();
      final e1 = Entity(1, 0);
      children.add(e1);
      expect(children.contains(e1), isTrue);
    });

    test('add ignores duplicates', () {
      final children = Children();
      final e1 = Entity(1, 0);
      children.add(e1);
      children.add(e1);
      expect(children.length, equals(1));
    });

    test('remove removes child', () {
      final children = Children();
      final e1 = Entity(1, 0);
      children.add(e1);
      expect(children.remove(e1), isTrue);
      expect(children.contains(e1), isFalse);
    });

    test('remove returns false for missing child', () {
      final children = Children();
      expect(children.remove(Entity(1, 0)), isFalse);
    });

    test('list returns unmodifiable view', () {
      final children = Children();
      children.add(Entity(1, 0));
      expect(() => children.list.add(Entity(2, 0)), throwsUnsupportedError);
    });

    test('isNotEmpty returns true when has children', () {
      final children = Children();
      expect(children.isNotEmpty, isFalse);
      children.add(Entity(1, 0));
      expect(children.isNotEmpty, isTrue);
    });
  });

  group('World hierarchy extension', () {
    test('setParent adds Parent component to child', () {
      final world = World();
      final parent = world.spawn().entity;
      final child = world.spawn().entity;

      world.setParent(child, parent);

      expect(world.get<Parent>(child)?.entity, equals(parent));
    });

    test('setParent adds Children component to parent', () {
      final world = World();
      final parent = world.spawn().entity;
      final child = world.spawn().entity;

      world.setParent(child, parent);

      final children = world.get<Children>(parent);
      expect(children, isNotNull);
      expect(children!.contains(child), isTrue);
    });

    test('setParent handles multiple children', () {
      final world = World();
      final parent = world.spawn().entity;
      final child1 = world.spawn().entity;
      final child2 = world.spawn().entity;

      world.setParent(child1, parent);
      world.setParent(child2, parent);

      final children = world.get<Children>(parent);
      expect(children!.length, equals(2));
      expect(children.contains(child1), isTrue);
      expect(children.contains(child2), isTrue);
    });

    test('setParent removes from old parent', () {
      final world = World();
      final parent1 = world.spawn().entity;
      final parent2 = world.spawn().entity;
      final child = world.spawn().entity;

      world.setParent(child, parent1);
      world.setParent(child, parent2);

      // Child should be removed from parent1
      expect(world.get<Children>(parent1), isNull);
      // Child should be in parent2
      expect(world.get<Children>(parent2)!.contains(child), isTrue);
    });

    test('removeParent removes Parent component', () {
      final world = World();
      final parent = world.spawn().entity;
      final child = world.spawn().entity;

      world.setParent(child, parent);
      world.removeParent(child);

      expect(world.get<Parent>(child), isNull);
    });

    test('removeParent removes from parent Children', () {
      final world = World();
      final parent = world.spawn().entity;
      final child = world.spawn().entity;

      world.setParent(child, parent);
      world.removeParent(child);

      // Empty Children component is removed
      expect(world.get<Children>(parent), isNull);
    });

    test('getParent returns parent entity', () {
      final world = World();
      final parent = world.spawn().entity;
      final child = world.spawn().entity;

      world.setParent(child, parent);

      expect(world.getParent(child), equals(parent));
    });

    test('getParent returns null for entities without parent', () {
      final world = World();
      final entity = world.spawn().entity;
      expect(world.getParent(entity), isNull);
    });

    test('getChildren returns child entities', () {
      final world = World();
      final parent = world.spawn().entity;
      final child1 = world.spawn().entity;
      final child2 = world.spawn().entity;

      world.setParent(child1, parent);
      world.setParent(child2, parent);

      final children = world.getChildren(parent).toList();
      expect(children, containsAll([child1, child2]));
    });

    test('getChildren returns empty for entities without children', () {
      final world = World();
      final entity = world.spawn().entity;
      expect(world.getChildren(entity), isEmpty);
    });

    test('hasParent returns true for parented entities', () {
      final world = World();
      final parent = world.spawn().entity;
      final child = world.spawn().entity;

      expect(world.hasParent(child), isFalse);
      world.setParent(child, parent);
      expect(world.hasParent(child), isTrue);
    });

    test('hasChildren returns true for parents', () {
      final world = World();
      final parent = world.spawn().entity;
      final child = world.spawn().entity;

      expect(world.hasChildren(parent), isFalse);
      world.setParent(child, parent);
      expect(world.hasChildren(parent), isTrue);
    });

    test('root returns entity itself for root entities', () {
      final world = World();
      final entity = world.spawn().entity;
      expect(world.root(entity), equals(entity));
    });

    test('root returns root ancestor', () {
      final world = World();
      final grandparent = world.spawn().entity;
      final parent = world.spawn().entity;
      final child = world.spawn().entity;

      world.setParent(parent, grandparent);
      world.setParent(child, parent);

      expect(world.root(child), equals(grandparent));
      expect(world.root(parent), equals(grandparent));
    });

    test('ancestors yields all ancestors', () {
      final world = World();
      final grandparent = world.spawn().entity;
      final parent = world.spawn().entity;
      final child = world.spawn().entity;

      world.setParent(parent, grandparent);
      world.setParent(child, parent);

      final ancestors = world.ancestors(child).toList();
      expect(ancestors, equals([parent, grandparent]));
    });

    test('ancestors yields empty for root entities', () {
      final world = World();
      final entity = world.spawn().entity;
      expect(world.ancestors(entity), isEmpty);
    });

    test('descendants yields all descendants', () {
      final world = World();
      final grandparent = world.spawn().entity;
      final parent1 = world.spawn().entity;
      final parent2 = world.spawn().entity;
      final child1 = world.spawn().entity;
      final child2 = world.spawn().entity;

      world.setParent(parent1, grandparent);
      world.setParent(parent2, grandparent);
      world.setParent(child1, parent1);
      world.setParent(child2, parent1);

      final descendants = world.descendants(grandparent).toList();
      expect(descendants.length, equals(4));
      expect(descendants, containsAll([parent1, parent2, child1, child2]));
    });

    test('descendants yields empty for leaf entities', () {
      final world = World();
      final entity = world.spawn().entity;
      expect(world.descendants(entity), isEmpty);
    });

    test('despawnRecursive despawns entity and descendants', () {
      final world = World();
      final grandparent = world.spawn().entity;
      final parent = world.spawn().entity;
      final child = world.spawn().entity;

      world.setParent(parent, grandparent);
      world.setParent(child, parent);

      world.despawnRecursive(grandparent);

      expect(world.isAlive(grandparent), isFalse);
      expect(world.isAlive(parent), isFalse);
      expect(world.isAlive(child), isFalse);
    });

    test('despawnRecursive removes from parent', () {
      final world = World();
      final grandparent = world.spawn().entity;
      final parent = world.spawn().entity;
      final child = world.spawn().entity;

      world.setParent(parent, grandparent);
      world.setParent(child, parent);

      world.despawnRecursive(parent);

      expect(world.isAlive(grandparent), isTrue);
      expect(world.isAlive(parent), isFalse);
      expect(world.isAlive(child), isFalse);
      expect(world.getChildren(grandparent), isEmpty);
    });

    test('despawnRecursive handles deep hierarchies', () {
      final world = World();
      final entities = <Entity>[];

      // Create a chain of 10 entities
      entities.add(world.spawn().entity);
      for (int i = 1; i < 10; i++) {
        final child = world.spawn().entity;
        world.setParent(child, entities[i - 1]);
        entities.add(child);
      }

      world.despawnRecursive(entities.first);

      for (final e in entities) {
        expect(world.isAlive(e), isFalse);
      }
    });

    test('spawnChild creates entity with parent', () {
      final world = World();
      final parent = world.spawn().entity;

      final childCommands = world.spawnChild(parent);
      final child = childCommands.entity;

      expect(world.getParent(child), equals(parent));
      expect(world.getChildren(parent).contains(child), isTrue);
    });

    test('spawnChild allows adding components', () {
      final world = World();
      final parent = world.spawn().entity;

      final childCommands = world.spawnChild(parent)..insert(_Position(10, 20));
      final child = childCommands.entity;

      expect(world.get<_Position>(child)?.x, equals(10));
    });
  });

  group('Commands hierarchy', () {
    test('despawnRecursive queues recursive despawn', () {
      final world = World();
      final commands = Commands();

      final parent = world.spawn().entity;
      final child = world.spawn().entity;
      world.setParent(child, parent);

      commands.despawnRecursive(parent);
      commands.apply(world);

      expect(world.isAlive(parent), isFalse);
      expect(world.isAlive(child), isFalse);
    });

    test('spawnChild queues child spawn', () {
      final world = World();
      final commands = Commands();

      final parent = world.spawn().entity;
      final spawnCmd = commands.spawnChild(parent)..insert(_Position(5, 10));

      commands.apply(world);

      final child = spawnCmd.entity!;
      expect(world.getParent(child), equals(parent));
      expect(world.get<_Position>(child)?.x, equals(5));
    });

    test('spawnChild does nothing if parent is dead', () {
      final world = World();
      final commands = Commands();

      final parent = world.spawn().entity;
      world.despawn(parent);

      final spawnCmd = commands.spawnChild(parent);
      commands.apply(world);

      expect(spawnCmd.entity, isNull);
    });
  });
}

// Test component
class _Position {
  double x, y;
  _Position(this.x, this.y);
}
