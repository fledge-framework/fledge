import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_physics/fledge_physics.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';

/// A 10x10 wall as a child of a root at (100, 40), itself offset (5, 0)
/// from it, as a tilemap spawns its colliders under the map root.
(World, Entity) _world() {
  final world = World()
    ..insertResource(FixedTimestep())
    ..events.register<CollisionEvent>()
    ..events.register<ContactYieldStarted>()
    ..events.register<ContactYieldEnded>();
  final root = world.spawn()..insert(Transform2D.from(100, 40));
  final wall = world.spawnChild(root.entity)
    ..insert(Transform2D.from(5, 0))
    ..insert(
      Collider.single(const RectangleShape(x: 0, y: 0, width: 10, height: 10)),
    );
  return (world, wall.entity);
}

bool _hits(World world, Entity wall, double x, double y) {
  final probe = world.spawn()
    ..insert(Transform2D.from(x, y))
    ..insert(
      Collider.single(const RectangleShape(x: 0, y: 0, width: 2, height: 2)),
    );
  world.updateEvents();
  const CollisionDetectionSystem().run(world);
  world.updateEvents();
  final hit = world.eventReader<CollisionEvent>().read().any(
    (e) =>
        (e.entityA == probe.entity && e.entityB == wall) ||
        (e.entityB == probe.entity && e.entityA == wall),
  );
  world.despawn(probe.entity);
  return hit;
}

void main() {
  test('a child collider is detected where its parents put it', () {
    final (world, wall) = _world();
    expect(_hits(world, wall, 108, 44), isTrue);
    // Not at its local offset from the parent.
    expect(_hits(world, wall, 8, 4), isFalse);
  });

  test('a child collider blocks movers where its parents put it', () {
    final (world, _) = _world();
    final mover = world.spawn()
      ..insert(Transform2D.from(102, 44))
      ..insert(
        Collider.single(const RectangleShape(x: 0, y: 0, width: 2, height: 2)),
      )
      ..insert(Velocity(4, 0));
    const CollisionResolutionSystem.fixed().run(world);
    expect(world.get<Velocity>(mover.entity)!.x, 0);
  });
}
