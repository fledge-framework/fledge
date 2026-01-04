import 'package:fledge_ecs/fledge_ecs.dart';

/// Component inserted when two entities collide.
///
/// Collision events are:
/// - Bidirectional: Both colliding entities receive an event
/// - Frame-scoped: Removed by [CollisionCleanupSystem] at end of frame
/// - Filtered by layer: Only generated when layer/mask compatibility passes
///
/// Systems can query for entities with [CollisionEvent] to respond
/// to collisions:
///
/// ```dart
/// for (final (entity, event) in world.query1<CollisionEvent>().iter()) {
///   // entity collided with event.other
///   final other = event.other;
///   // Handle collision...
/// }
/// ```
///
/// For more specific collision handling, combine with other components:
///
/// ```dart
/// for (final (entity, event, player)
///     in world.query2<CollisionEvent, Player>().iter()) {
///   // Player collided with something
///   if (world.has<Enemy>(event.other)) {
///     // Player hit an enemy
///   }
/// }
/// ```
class CollisionEvent {
  /// The entity that this entity collided with.
  final Entity other;

  /// Creates a collision event referencing the other colliding entity.
  const CollisionEvent(this.other);

  @override
  String toString() => 'CollisionEvent(other: $other)';
}
