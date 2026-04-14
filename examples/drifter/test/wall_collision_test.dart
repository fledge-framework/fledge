import 'package:drifter_example/components.dart';
import 'package:drifter_example/game_app.dart';
import 'package:fledge_ecs/fledge_ecs.dart' hide State;
import 'package:fledge_input/fledge_input.dart';
import 'package:fledge_physics/fledge_physics.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_tiled/fledge_tiled.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression test: a player running at a solid wall must not pass
/// through it. Earlier builds had `InputMovementSystem` registered in
/// `CoreStage.update` alongside physics, which meant the scheduler ran
/// `CollisionResolutionSystem` on last frame's velocity while input's
/// new velocity landed too late to be clamped — and the player walked
/// straight through walls. This test pins the current ordering down.
void main() {
  testWidgets('player velocity is clamped by a solid wall in its path',
      (tester) async {
    final app = buildApp();
    await app.tick(); // warm up plugins
    clearScene(app);

    final world = app.world;

    // Spawn the player a bit to the left of a centred wall.
    world.spawn()
      ..insert(Transform2D.from(40, 100))
      ..insert(Velocity.stationary())
      ..insert(Collider.single(
        RectangleShape(x: -10, y: -10, width: 20, height: 20),
      ))
      ..insert(const CollisionConfig(
        layer: Layers.player,
        mask: Layers.solid | Layers.pickup,
      ))
      ..insert(const Player());

    // A solid wall blocking rightward travel.
    world.spawn()
      ..insert(Transform2D.from(80, 60))
      ..insert(Collider.single(
        RectangleShape(x: 0, y: 0, width: 8, height: 80),
      ))
      ..insert(const CollisionConfig.solid())
      ..insert(const Wall());

    // Simulate holding the right arrow — KeyboardState.press() leaves
    // `pressed = true` until release, mirroring a real held key.
    // ActionResolutionSystem then derives Vector2(1, 0) from the
    // composite arrow binding each frame.
    world.getResource<KeyboardState>()!.keyDown(LogicalKeyboardKey.arrowRight);

    final playerTransform = _playerTransform(world);
    final startX = playerTransform.translation.x;

    // Tick enough frames that, unclamped, the player would be well past
    // the wall. With input in preUpdate and physics resolving in update,
    // velocity.x must be clamped to 0 before the player clips past
    // x == 70 (wall.left 80 - player half-size 10).
    for (var i = 0; i < 120; i++) {
      await app.tick();
    }

    final endX = playerTransform.translation.x;
    expect(endX, greaterThan(startX),
        reason: 'player should have moved toward the wall');
    expect(endX, lessThanOrEqualTo(70.0 + 0.5),
        reason: 'player should be stopped at the wall face (wall.left=80 minus '
            'player half-size 10 == 70), not clipped through it');
  });
}

Transform2D _playerTransform(World world) {
  for (final (_, t, _) in world.query2<Transform2D, Player>().iter()) {
    return t;
  }
  throw StateError('no player in world');
}
