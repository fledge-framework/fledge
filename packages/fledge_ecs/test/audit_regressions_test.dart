import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_ecs/src/entity.dart' show EntityLocation;
import 'package:test/test.dart';

// Regressions found by the 2026-11-26 audit: each test pins one fix.

class A {
  A(this.v);
  int v;
}

enum Mode { a, b }

void main() {
  setUp(ComponentId.resetRegistry);

  test('a handle held across World.clear stays dead', () {
    final world = World();
    final old = world.spawn().insert(A(1)).entity;
    world.clear();
    final fresh = world.spawn().insert(A(2)).entity;
    expect(world.isAlive(old), isFalse);
    expect(world.isAlive(fresh), isTrue);
    expect(world.get<A>(old), isNull);
  });

  test('reserve never frees a live id', () {
    final entities = Entities();
    final live = [for (var i = 0; i < 10; i++) entities.spawn()];
    for (final e in live) {
      entities.setLocation(e, EntityLocation(0, 0));
    }
    entities.despawn(live[3]);
    entities.despawn(live[7]);
    entities.reserve(5);
    final spawned = [for (var i = 0; i < 7; i++) entities.spawn()];
    final aliveIds = {
      for (final e in live)
        if (entities.isAlive(e)) e.id,
    };
    for (final e in spawned) {
      expect(aliveIds, isNot(contains(e.id)), reason: 'id ${e.id}');
    }
    expect(spawned.map((e) => e.id).toSet(), hasLength(spawned.length));
  });

  test('a query iterable walked again after a despawn reads the world as '
      'it is', () {
    final world = World();
    final es = [for (var i = 0; i < 3; i++) world.spawn().insert(A(i)).entity];
    final rows = world.query1<A>().iter();
    expect(rows.map((r) => r.$2.v).toList(), [0, 1, 2]);
    world.despawn(es[1]);
    expect(rows.map((r) => r.$2.v).toList(), [0, 2]);
  });

  test('setting the current state again cancels a pending transition', () {
    final state = State(Mode.a)
      ..set(Mode.b)
      ..set(Mode.a);
    state.applyTransition();
    expect(state.current, Mode.a);
  });

  test('a parent cycle is refused', () {
    final world = World();
    final a = world.spawn().entity;
    final b = world.spawn().entity;
    world.setParent(b, a);
    world.setParent(a, b); // would make a cycle
    world.setParent(a, a); // and so would this
    expect(world.getParent(a), isNull);
    expect(world.root(b), a);
  });

  test('an observer registered then unregistered leaves none behind', () {
    final world = World();
    final observer = Observer<A>.onAdd((w, e, c) {});
    world.observers.register(observer);
    expect(world.observers.hasObservers, isTrue);
    world.observers.unregister(observer);
    expect(world.observers.hasObservers, isFalse);
  });

  test("a set's run condition is checked once a tick per member", () async {
    var checks = 0;
    final app = App()
      ..configureSet(
        'gated',
        (set) => set.runIf((world) {
          checks++;
          return true;
        }),
      )
      ..addSystemToSet(FunctionSystem('member', run: (_) {}), 'gated');
    await app.tick();
    expect(checks, 1);
  });
}
