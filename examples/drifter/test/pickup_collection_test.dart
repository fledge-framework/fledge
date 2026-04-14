import 'package:drifter_example/game_app.dart';
import 'package:drifter_example/resources.dart';
import 'package:drifter_example/components.dart';
import 'package:fledge_physics/fledge_physics.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_tiled/fledge_tiled.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit test for [PickupCollectionSystem] — drives the physics plugin
/// directly (no Flutter widgets, no rendering) and asserts the ECS-side
/// state transitions.
void main() {
  testWidgets('player overlapping a pickup collects it and bumps the score',
      (tester) async {
    final app = buildApp()..tick(); // first tick lets plugins warm up
    await tester.pump();

    // Wipe the default-spawned scene; place a single pickup right on top
    // of a freshly-spawned player to deterministically trigger a collision.
    clearScene(app);
    final world = app.world;

    world.spawn()
      ..insert(Transform2D.from(50, 50))
      ..insert(Velocity.stationary())
      ..insert(Collider.single(
        RectangleShape(x: -10, y: -10, width: 20, height: 20),
      ))
      ..insert(const CollisionConfig(
        layer: Layers.player,
        mask: Layers.solid | Layers.pickup,
      ))
      ..insert(const Player());

    final pickupEntity = world.spawn()
      ..insert(Transform2D.from(50, 50))
      ..insert(Collider.single(
        RectangleShape(x: -8, y: -8, width: 16, height: 16),
      ))
      ..insert(const CollisionConfig(
        layer: Layers.pickup,
        mask: Layers.player,
        isSensor: true,
      ))
      ..insert(const Pickup());

    expect(world.getResource<RunScore>()!.value, 0);
    expect(world.isAlive(pickupEntity.entity), isTrue);

    // One tick: detection fires a CollisionEvent on the player,
    // PickupCollectionSystem consumes it and despawns the pickup.
    await app.tick();

    expect(world.isAlive(pickupEntity.entity), isFalse,
        reason: 'collected pickup should be despawned');
    expect(world.getResource<RunScore>()!.value, 1);
    expect(world.getResource<HighScore>()!.value, 1,
        reason: 'high score should track run score when it rises');
  });

  testWidgets(
      'high score persists run-to-run but run score resets on spawnScene',
      (tester) async {
    final app = buildApp()..tick();
    await tester.pump();

    // Pretend the player collected three pickups.
    app.world.getResource<RunScore>()!.value = 3;
    app.world.getResource<HighScore>()!.value = 3;

    clearScene(app);
    spawnScene(app);

    expect(app.world.getResource<RunScore>()!.value, 0,
        reason: 'spawnScene starts a fresh run');
    expect(app.world.getResource<HighScore>()!.value, 3,
        reason: 'HighScore is persisted across scenes');
  });
}
