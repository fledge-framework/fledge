import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';

import '../components/velocity.dart';
import '../physics_mode.dart';
import 'collision_resolution.dart';

/// Advances `Transform2D` by `Velocity` scaled to real time.
///
/// Runs after [CollisionResolutionSystem] has clamped `Velocity` for
/// the current step so blocked axes stay pinned to zero.
///
/// The dt source depends on [PhysicsMode]:
///
/// - [PhysicsMode.variable] reads `WallTime.delta`. Schedule in
///   `Schedules.update`.
/// - [PhysicsMode.fixed] reads `FixedTimestep.stepSeconds`. Schedule
///   in `Schedules.fixedUpdate` alongside the paired resolution
///   system.
///
/// Velocity is interpreted as pixels per 60 Hz frame, so
/// `Velocity(0, 4)` produces 240 px/s in either mode.
class VelocityIntegrationSystem implements System {
  /// Which clock this system reads.
  final PhysicsMode mode;

  /// Creates a variable-timestep integration system.
  const VelocityIntegrationSystem() : mode = PhysicsMode.variable;

  /// Creates a fixed-timestep integration system.
  const VelocityIntegrationSystem.fixed() : mode = PhysicsMode.fixed;

  /// The `SystemMeta.name` of [VelocityIntegrationSystem]. Games that
  /// order their own systems relative to this one use it in
  /// `before:` / `after:`.
  static const String systemName = 'velocity_integration';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    reads: {ComponentId.of<Velocity>()},
    writes: {ComponentId.of<Transform2D>()},
    after: const [CollisionResolutionSystem.systemName],
    resourceReads: mode == PhysicsMode.fixed ? {FixedTimestep} : {WallTime},
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) async {
    final double dt;
    if (mode == PhysicsMode.fixed) {
      final ft = world.getResource<FixedTimestep>();
      if (ft == null) return;
      dt = ft.stepSeconds;
    } else {
      final wt = world.getResource<WallTime>();
      if (wt == null || wt.delta == 0) return;
      dt = wt.delta;
    }
    if (dt <= 0) return;

    final scale = dt / physicsReferenceFrameSeconds;

    for (final (_, transform, velocity)
        in world.query2<Transform2D, Velocity>().iter()) {
      if (!velocity.isMoving) continue;
      transform.translation.x += velocity.x * scale;
      transform.translation.y += velocity.y * scale;
    }
  }
}
