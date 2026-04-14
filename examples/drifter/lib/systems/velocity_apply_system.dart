import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_physics/fledge_physics.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';

/// Integrates `Velocity` into `Transform2D` once per frame.
///
/// `fledge_physics` clamps components of the `Velocity` component in
/// its `CollisionResolutionSystem` (so the player can't walk into a
/// wall) but does not itself integrate velocity into position — that's
/// left to the game. We declare `after: ['collision_resolution']`
/// (matching the actual registered system name, which is snake_case
/// and not the class name) so we integrate the clamped value, not the
/// pre-clamp one.
class VelocityApplySystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'VelocityApplySystem',
        reads: {ComponentId.of<Velocity>()},
        writes: {ComponentId.of<Transform2D>()},
        resourceReads: {Time},
        // Explicit ordering: run after both physics systems. Detection
        // reads Transform2D and we write it, so on paper either order
        // works — but detection expects pre-integration positions, so
        // we integrate AFTER it. Consequence: collision events land
        // one frame later than the position that caused them. That's
        // fine for pickups; games that need tighter timing can split
        // integrate into a separate stage.
        after: const ['collision_resolution', 'collision_detection'],
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) async {
    final time = world.getResource<Time>();
    if (time == null) return;
    final dt = time.delta;
    if (dt <= 0) return;

    // Match the "per-frame at 60fps" convention used by
    // `CollisionResolutionSystem` (`moveX = velocity.x * dt / 0.01667`)
    // so we integrate the same value it clamped.
    final timeScale = dt / 0.01667;
    for (final (_, transform, velocity)
        in world.query2<Transform2D, Velocity>().iter()) {
      if (!velocity.isMoving) continue;
      transform.translation.x += velocity.x * timeScale;
      transform.translation.y += velocity.y * timeScale;
    }
  }
}
