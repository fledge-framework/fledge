import 'dart:math' as math;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_input/fledge_input.dart';
import 'package:fledge_physics/fledge_physics.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';

import '../actions.dart';
import '../components.dart';

/// Reads [ActionState] and drives the player's [Velocity].
///
/// Registered in [CoreStage.preUpdate] (in `buildApp`), one stage before
/// the physics plugin's update-stage systems, so the velocity we write
/// here is what `CollisionResolutionSystem` sees when it clamps against
/// walls.
///
/// Registering this alongside the physics systems in [CoreStage.update]
/// looks innocent but is a subtle bug: the scheduler orders within a
/// stage by conflict + insertion order, and the physics plugin is added
/// first, so resolution would run on *last frame's* velocity while the
/// input system's new velocity lands too late to be clamped — and the
/// player walks through walls.
class InputMovementSystem implements System {
  /// Player movement speed in pixels-per-frame-at-60fps. This matches
  /// the convention used by `fledge_physics.CollisionResolutionSystem`
  /// (`moveX = velocity.x * (time.delta / 0.01667)`), so we can feed
  /// the same value into both resolution and our own integration
  /// without unit gymnastics.
  final double speed;

  const InputMovementSystem({this.speed = 2.5});

  @override
  SystemMeta get meta => SystemMeta(
        name: 'InputMovementSystem',
        reads: {ComponentId.of<Player>(), ComponentId.of<Transform2D>()},
        writes: {ComponentId.of<Velocity>()},
        resourceReads: {ActionState},
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) async {
    final actions = world.getResource<ActionState>();
    if (actions == null) return;

    final (mx, my) =
        actions.vector2Value(ActionId.fromEnum(DrifterAction.move));

    // Normalise so diagonal speed matches orthogonal speed.
    final mag = math.sqrt(mx * mx + my * my);
    final nx = mag > 1e-6 ? mx / mag : 0.0;
    final ny = mag > 1e-6 ? my / mag : 0.0;

    for (final (_, _, velocity) in world.query2<Player, Velocity>().iter()) {
      velocity.x = nx * speed;
      velocity.y = ny * speed;
    }
  }
}
