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

  group('Observer', () {
    test('onAdd creates observer with correct trigger', () {
      final observer = Observer<Position>.onAdd((w, e, p) {});
      expect(observer.trigger, equals(TriggerKind.onAdd));
      expect(observer.componentType, equals(Position));
    });

    test('onRemove creates observer with correct trigger', () {
      final observer = Observer<Position>.onRemove((w, e, p) {});
      expect(observer.trigger, equals(TriggerKind.onRemove));
      expect(observer.componentType, equals(Position));
    });

    test('onChange creates observer with correct trigger', () {
      final observer = Observer<Position>.onChange((w, e, p) {});
      expect(observer.trigger, equals(TriggerKind.onChange));
      expect(observer.componentType, equals(Position));
    });

    test('invoke calls callback with correct parameters', () {
      Entity? capturedEntity;
      Position? capturedComponent;

      final observer = Observer<Position>.onAdd((w, e, p) {
        capturedEntity = e;
        capturedComponent = p;
      });

      final world = World();
      const entity = Entity(1, 0);
      final position = Position(10, 20);

      observer.invoke(world, entity, position);

      expect(capturedEntity, equals(entity));
      expect(capturedComponent, same(position));
    });

    test('toString includes type and trigger', () {
      final observer = Observer<Position>.onAdd((w, e, p) {});
      expect(observer.toString(), contains('Position'));
      expect(observer.toString(), contains('onAdd'));
    });
  });

  group('Observers registry', () {
    test('register adds observer', () {
      final observers = Observers();
      final observer = Observer<Position>.onAdd((w, e, p) {});

      observers.register(observer);

      expect(observers.hasObservers, isTrue);
      expect(observers.hasObserversFor<Position>(), isTrue);
      expect(observers.count, equals(1));
    });

    test('can register multiple observers for same type', () {
      final observers = Observers();
      observers.register(Observer<Position>.onAdd((w, e, p) {}));
      observers.register(Observer<Position>.onRemove((w, e, p) {}));

      expect(observers.count, equals(2));
    });

    test('can register observers for different types', () {
      final observers = Observers();
      observers.register(Observer<Position>.onAdd((w, e, p) {}));
      observers.register(Observer<Velocity>.onAdd((w, e, v) {}));

      expect(observers.count, equals(2));
      expect(observers.hasObserversFor<Position>(), isTrue);
      expect(observers.hasObserversFor<Velocity>(), isTrue);
    });

    test('unregister removes observer', () {
      final observers = Observers();
      final observer = Observer<Position>.onAdd((w, e, p) {});

      observers.register(observer);
      expect(observers.count, equals(1));

      final result = observers.unregister(observer);
      expect(result, isTrue);
      expect(observers.count, equals(0));
    });

    test('unregister returns false for unregistered observer', () {
      final observers = Observers();
      final observer = Observer<Position>.onAdd((w, e, p) {});

      final result = observers.unregister(observer);
      expect(result, isFalse);
    });

    test('clear removes all observers', () {
      final observers = Observers();
      observers.register(Observer<Position>.onAdd((w, e, p) {}));
      observers.register(Observer<Velocity>.onAdd((w, e, v) {}));

      observers.clear();

      expect(observers.hasObservers, isFalse);
      expect(observers.count, equals(0));
    });

    test('triggerOnAdd calls onAdd observers', () {
      var called = false;
      final observers = Observers();
      observers.register(Observer<Position>.onAdd((w, e, p) {
        called = true;
      }));

      observers.triggerOnAdd<Position>(
          World(), const Entity(1, 0), Position(0, 0));

      expect(called, isTrue);
    });

    test('triggerOnRemove calls onRemove observers', () {
      var called = false;
      final observers = Observers();
      observers.register(Observer<Position>.onRemove((w, e, p) {
        called = true;
      }));

      observers.triggerOnRemove<Position>(
          World(), const Entity(1, 0), Position(0, 0));

      expect(called, isTrue);
    });

    test('triggerOnChange calls onChange observers', () {
      var called = false;
      final observers = Observers();
      observers.register(Observer<Position>.onChange((w, e, p) {
        called = true;
      }));

      observers.triggerOnChange<Position>(
          World(), const Entity(1, 0), Position(0, 0));

      expect(called, isTrue);
    });

    test('triggers only matching observers', () {
      var addCalled = false;
      var removeCalled = false;
      final observers = Observers();

      observers.register(Observer<Position>.onAdd((w, e, p) {
        addCalled = true;
      }));
      observers.register(Observer<Position>.onRemove((w, e, p) {
        removeCalled = true;
      }));

      observers.triggerOnAdd<Position>(
          World(), const Entity(1, 0), Position(0, 0));

      expect(addCalled, isTrue);
      expect(removeCalled, isFalse);
    });

    test('triggers only matching component type', () {
      var positionCalled = false;
      var velocityCalled = false;
      final observers = Observers();

      observers.register(Observer<Position>.onAdd((w, e, p) {
        positionCalled = true;
      }));
      observers.register(Observer<Velocity>.onAdd((w, e, v) {
        velocityCalled = true;
      }));

      observers.triggerOnAdd<Position>(
          World(), const Entity(1, 0), Position(0, 0));

      expect(positionCalled, isTrue);
      expect(velocityCalled, isFalse);
    });
  });

  group('World observer integration', () {
    test('insert triggers onAdd observer for new component', () {
      Entity? capturedEntity;
      Position? capturedPosition;

      final world = World();
      world.observers.register(Observer<Position>.onAdd((w, e, p) {
        capturedEntity = e;
        capturedPosition = p;
      }));

      final entity = world.spawn().entity;
      world.insert(entity, Position(10, 20));

      expect(capturedEntity, equals(entity));
      expect(capturedPosition?.x, equals(10));
      expect(capturedPosition?.y, equals(20));
    });

    test('insert triggers onChange observer for existing component', () {
      var changeCalled = false;
      var addCalled = false;

      final world = World();
      world.observers.register(Observer<Position>.onAdd((w, e, p) {
        addCalled = true;
      }));
      world.observers.register(Observer<Position>.onChange((w, e, p) {
        changeCalled = true;
      }));

      final entity = world.spawn().entity;
      world.insert(entity, Position(10, 20));

      expect(addCalled, isTrue);
      expect(changeCalled, isFalse);

      addCalled = false;

      // Insert again (replace)
      world.insert(entity, Position(30, 40));

      expect(addCalled, isFalse);
      expect(changeCalled, isTrue);
    });

    test('remove triggers onRemove observer', () {
      Entity? capturedEntity;
      Position? capturedPosition;

      final world = World();
      world.observers.register(Observer<Position>.onRemove((w, e, p) {
        capturedEntity = e;
        capturedPosition = p;
      }));

      final entity = world.spawn().entity;
      world.insert(entity, Position(10, 20));
      world.remove<Position>(entity);

      expect(capturedEntity, equals(entity));
      expect(capturedPosition?.x, equals(10));
      expect(capturedPosition?.y, equals(20));
    });

    test('observer receives correct world reference', () {
      World? capturedWorld;

      final world = World();
      world.observers.register(Observer<Position>.onAdd((w, e, p) {
        capturedWorld = w;
      }));

      final entity = world.spawn().entity;
      world.insert(entity, Position(10, 20));

      expect(capturedWorld, same(world));
    });

    test('observer can access other components', () {
      Velocity? velocityFromObserver;

      final world = World();
      world.observers.register(Observer<Position>.onAdd((w, e, p) {
        velocityFromObserver = w.get<Velocity>(e);
      }));

      final entity = world.spawn().entity;
      world.insert(entity, Velocity(1, 2));
      world.insert(entity, Position(10, 20));

      expect(velocityFromObserver?.dx, equals(1));
      expect(velocityFromObserver?.dy, equals(2));
    });

    test('observer can spawn entities', () {
      var spawnedCount = 0;

      final world = World();
      world.observers.register(Observer<Position>.onAdd((w, e, p) {
        w.spawn();
        spawnedCount++;
      }));

      world.spawn().insert(Position(0, 0));

      expect(spawnedCount, equals(1));
      expect(world.entityCount, equals(2));
    });

    test('no observers means no overhead', () {
      final world = World();
      final entity = world.spawn().entity;

      // Should not throw or have issues with empty observer registry
      world.insert(entity, Position(10, 20));
      world.remove<Position>(entity);
    });

    test('health death observer example', () {
      final deathEvents = <Entity>[];

      final world = World();
      world.registerEvent<Entity>();

      world.observers.register(Observer<Health>.onRemove((w, e, h) {
        // Send death event when health is removed
        w.eventWriter<Entity>().send(e);
      }));

      final entity = world.spawn().entity;
      world.insert(entity, Health(100));

      // Simulate death by removing health
      world.remove<Health>(entity);

      world.updateEvents();
      for (final dead in world.eventReader<Entity>().read()) {
        deathEvents.add(dead);
      }

      expect(deathEvents, contains(entity));
    });
  });

  group('Observers dynamic triggers', () {
    test('triggerOnAddDynamic works', () {
      var called = false;
      final observers = Observers();
      observers.register(Observer<Position>.onAdd((w, e, p) {
        called = true;
      }));

      observers.triggerOnAddDynamic(
        World(),
        const Entity(1, 0),
        ComponentId.of<Position>(),
        Position(0, 0),
      );

      expect(called, isTrue);
    });

    test('triggerOnRemoveDynamic works', () {
      var called = false;
      final observers = Observers();
      observers.register(Observer<Position>.onRemove((w, e, p) {
        called = true;
      }));

      observers.triggerOnRemoveDynamic(
        World(),
        const Entity(1, 0),
        ComponentId.of<Position>(),
        Position(0, 0),
      );

      expect(called, isTrue);
    });

    test('triggerOnChangeDynamic works', () {
      var called = false;
      final observers = Observers();
      observers.register(Observer<Position>.onChange((w, e, p) {
        called = true;
      }));

      observers.triggerOnChangeDynamic(
        World(),
        const Entity(1, 0),
        ComponentId.of<Position>(),
        Position(0, 0),
      );

      expect(called, isTrue);
    });
  });
}
