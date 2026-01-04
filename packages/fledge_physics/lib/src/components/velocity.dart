/// Component representing an entity's velocity.
///
/// Used by [CollisionResolutionSystem] to identify dynamic entities
/// and resolve collisions before movement is applied.
///
/// Entities with [Velocity] are considered dynamic (can move).
/// Entities without [Velocity] are considered static (obstacles).
///
/// Example:
/// ```dart
/// world.spawn()
///   ..insert(Transform2D.from(100, 100))
///   ..insert(Velocity(0, 0, maxSpeed: 5))
///   ..insert(Collider.single(RectangleShape(x: 0, y: 0, width: 32, height: 32)));
/// ```
class Velocity {
  /// Horizontal velocity (pixels per frame at 60fps).
  double x;

  /// Vertical velocity (pixels per frame at 60fps).
  double y;

  /// Maximum speed (pixels per frame at 60fps).
  final double max;

  /// Creates a velocity with optional initial values.
  Velocity(this.x, this.y, [this.max = 4]);

  /// Creates a stationary velocity with the given max speed.
  Velocity.stationary({this.max = 4})
      : x = 0,
        y = 0;

  /// Returns true if the entity is moving.
  bool get isMoving => x != 0 || y != 0;

  /// Resets velocity to zero.
  void reset() {
    x = 0;
    y = 0;
  }

  @override
  String toString() => 'Velocity($x, $y, max: $max)';
}
