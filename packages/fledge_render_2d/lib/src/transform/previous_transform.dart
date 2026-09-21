import 'package:vector_math/vector_math.dart';

import 'transform2d.dart';

/// Opt-in snapshot of an entity's `Transform2D` from the previous
/// fixed step. Used by render extractors and `CameraFollowSystem` to
/// smooth movement between simulation ticks.
///
/// ## When to attach
///
/// Attach `PreviousTransform2D` to any entity whose `Transform2D` is
/// written on a fixed cadence (typically inside
/// `Schedules.fixedUpdate` via `VelocityIntegrationSystem`) and whose
/// visible position should stay smooth on displays running faster
/// than the fixed step.
///
/// ```dart
/// world.spawn()
///   ..insert(Transform2D.from(0, 0))
///   ..insert(GlobalTransform2D())
///   ..insert(PreviousTransform2D())
///   ..insert(Velocity(4, 0));
/// ```
///
/// The snapshot is populated by [SnapshotPreviousTransformSystem] at
/// the top of every fixed step, so its initial value doesn't need to
/// match the entity's spawn position — the first fixed step captures
/// it. Extraction then interpolates translation between the snapshot
/// and the live `Transform2D` using `FixedTimestep.alpha`.
///
/// ## Teleports
///
/// After a hard-set — a door transition, a spawn point placement,
/// physics puppet warp — call [snapTo] so the next frame's
/// interpolation doesn't smear across the jump.
///
/// ## Root-entity assumption
///
/// The interpolation is applied in local space. When an entity has
/// no parent (the common case for player / NPC / projectile) the
/// interpolation is world-correct. Hierarchical entities need the
/// snapshot on the root; interpolating a leaf inside a moving parent
/// is not supported by this component.
class PreviousTransform2D {
  /// Snapshot of `Transform2D.translation` from the previous fixed step.
  final Vector2 translation;

  /// Snapshot of `Transform2D.rotation` from the previous fixed step.
  double rotation;

  /// Snapshot of `Transform2D.scale` from the previous fixed step.
  final Vector2 scale;

  /// Creates a snapshot. Fields default to the identity transform;
  /// [SnapshotPreviousTransformSystem] overwrites them on the first
  /// fixed step so the initial values do not need to match anything.
  PreviousTransform2D({
    Vector2? translation,
    this.rotation = 0,
    Vector2? scale,
  })  : translation = translation ?? Vector2.zero(),
        scale = scale ?? Vector2(1, 1);

  /// Copy [current] into this snapshot. Called from
  /// [SnapshotPreviousTransformSystem] at the top of each fixed step.
  void copyFrom(Transform2D current) {
    translation.setFrom(current.translation);
    rotation = current.rotation;
    scale.setFrom(current.scale);
  }

  /// Force the snapshot to equal [current]. After a teleport (hard
  /// warp of the entity's `Transform2D`) call this so the next
  /// extraction produces alpha = 1 output — no visible smear across
  /// the jump.
  void snapTo(Transform2D current) => copyFrom(current);
}
