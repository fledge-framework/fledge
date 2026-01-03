/// Cardinal direction for 2D character orientation.
///
/// Used to track which direction a character is facing for
/// sprite selection and animation.
enum Direction {
  /// Facing right (+X).
  right,

  /// Facing up (-Y in screen coordinates).
  up,

  /// Facing left (-X).
  left,

  /// Facing down (+Y in screen coordinates).
  down;

  /// Get direction from velocity components.
  ///
  /// Returns the dominant direction based on which axis has greater magnitude.
  /// If velocity is zero, returns null.
  static Direction? fromVelocity(double vx, double vy) {
    if (vx == 0 && vy == 0) return null;

    // Determine dominant axis
    if (vx.abs() >= vy.abs()) {
      return vx > 0 ? Direction.right : Direction.left;
    } else {
      return vy > 0 ? Direction.down : Direction.up;
    }
  }

  /// Get the opposite direction.
  Direction get opposite {
    switch (this) {
      case Direction.right:
        return Direction.left;
      case Direction.left:
        return Direction.right;
      case Direction.up:
        return Direction.down;
      case Direction.down:
        return Direction.up;
    }
  }

  /// Get direction as a suffix string (e.g., "_right", "_up").
  String get suffix => '_$name';
}

/// Component tracking which direction an entity is facing.
///
/// Used by animation systems to select the appropriate directional
/// sprite or animation.
///
/// Example:
/// ```dart
/// world.spawn()
///   ..insert(Orientation(Direction.down))
///   ..insert(AnimationPlayer(...));
/// ```
class Orientation {
  /// Current facing direction.
  Direction direction;

  /// Creates an orientation component.
  Orientation([this.direction = Direction.down]);

  /// Update direction from velocity, if velocity is non-zero.
  ///
  /// Returns true if direction changed.
  bool updateFromVelocity(double vx, double vy) {
    final newDir = Direction.fromVelocity(vx, vy);
    if (newDir != null && newDir != direction) {
      direction = newDir;
      return true;
    }
    return false;
  }

  @override
  String toString() => 'Orientation($direction)';
}
