import 'package:fledge_ecs/fledge_ecs.dart';

/// Event published when two entities collide.
///
/// Collision events are:
/// - **Bidirectional**: A single event carries both entities. Consumers
///   should not expect two events for a given pair.
/// - **Frame-scoped**: The events queue is double-buffered by
///   `world.updateEvents()` (driven by `App.tick`), so consumers see
///   only the previous frame's collisions.
/// - **Filtered by layer**: Only generated when layer/mask compatibility
///   passes on both sides.
///
/// Consume events via [World.eventReader]:
///
/// ```dart
/// for (final evt in world.eventReader<CollisionEvent>().read()) {
///   // evt.entityA collided with evt.entityB this frame.
/// }
/// ```
///
/// To respond to collisions involving a specific component (e.g. Player),
/// look the component up on either side:
///
/// ```dart
/// for (final evt in world.eventReader<CollisionEvent>().read()) {
///   final player = world.get<Player>(evt.entityA) ??
///       world.get<Player>(evt.entityB);
///   if (player == null) continue;
///   // Handle player collision...
/// }
/// ```
class CollisionEvent {
  /// The first entity in the collision pair.
  final Entity entityA;

  /// The second entity in the collision pair.
  final Entity entityB;

  /// Creates a collision event for the given pair of entities.
  const CollisionEvent({required this.entityA, required this.entityB});

  /// Returns the "other" entity given one side of the pair, or `null` if
  /// [entity] isn't part of this collision.
  ///
  /// Handy when a system already has one entity in hand and just wants
  /// the partner:
  ///
  /// ```dart
  /// for (final evt in reader.read()) {
  ///   final other = evt.otherOf(playerEntity);
  ///   if (other == null) continue;
  ///   // ...
  /// }
  /// ```
  Entity? otherOf(Entity entity) {
    if (entity == entityA) return entityB;
    if (entity == entityB) return entityA;
    return null;
  }

  /// Whether [entity] is either side of this collision.
  bool involves(Entity entity) => entity == entityA || entity == entityB;

  @override
  String toString() => 'CollisionEvent(entityA: $entityA, entityB: $entityB)';
}
