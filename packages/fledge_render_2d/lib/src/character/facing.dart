import 'dart:math' as math;

import 'orientation.dart';

const double _tau = 2 * math.pi;

/// Wraps [angle] (radians) into `[0, 2π)`.
///
/// Non-finite input (NaN, ±infinity) maps to `0`.
double normalizeFacingAngle(double angle) {
  if (!angle.isFinite) return 0;
  // Dart's `%` is Euclidean for a positive divisor: never negative.
  final a = angle % _tau;
  return a >= _tau ? 0 : a;
}

/// Index of the view (0 ≤ index < [views]) whose facing is closest to
/// [angle], for a sprite drawn from [views] evenly spaced directions.
///
/// Convention (shared with [Facing] and `Transform2D.rotation`):
///
/// - Angles are radians in world space, where +x is right and +y is
///   **down** (screen convention). `0` faces +x; increasing angles turn
///   toward +y, i.e. **clockwise on screen**.
/// - View `0` faces angle `0` (+x, right). View `i` faces
///   `i * 2π / views`, so indices also advance clockwise. With 8 views:
///   0 = right, 2 = down, 4 = left, 6 = up.
/// - Each view covers the arc of ±`π / views` around its own angle; an
///   angle exactly on a boundary goes to the higher (clockwise) index.
///
/// `views == 1` always returns `0`. Throws [RangeError] for `views < 1`.
int facingViewIndex(double angle, int views) {
  if (views < 1) throw RangeError.range(views, 1, null, 'views');
  if (views == 1) return 0;
  final step = _tau / views;
  return (normalizeFacingAngle(angle) / step).round() % views;
}

/// The facing angle (radians, in `[0, 2π)`) at the centre of view
/// [index] out of [views]. Inverse of [facingViewIndex].
double facingViewAngle(int index, int views) {
  if (views < 1) throw RangeError.range(views, 1, null, 'views');
  return normalizeFacingAngle(index * _tau / views);
}

/// Component holding a continuous facing angle, for sprites drawn from
/// any number of directions (8, 16, …) rather than the four of
/// [Orientation].
///
/// [angle] is in radians and follows `Transform2D.rotation`: `0` faces +x
/// (right) and positive angles turn toward +y (down), i.e. clockwise on
/// screen. An entity whose local +x axis is its "forward" therefore faces
/// its own rotation. Map the angle to a sprite view with [viewIndex]
/// (see [facingViewIndex] for which index is "view 0").
///
/// [Facing] stores state only; nothing in `fledge_render_2d` reads it.
/// Directional sprite systems (and game code) do.
///
/// ```dart
/// world.spawn()
///   ..insert(Transform2D.from(100, 200))
///   ..insert(Facing()); // faces down (toward the viewer)
///
/// // Each frame, from movement:
/// facing.updateFromVector(velocity.x, velocity.y);
/// final view = facing.viewIndex(8); // 0..7, 0 = right, clockwise
/// ```
class Facing {
  /// Facing right (+x).
  static const double right = 0;

  /// Facing down (+y in screen coordinates, toward the viewer in a
  /// top-down / 3/4 view).
  static const double down = math.pi / 2;

  /// Facing left (-x).
  static const double left = math.pi;

  /// Facing up (-y in screen coordinates).
  static const double up = 3 * math.pi / 2;

  /// Facing angle in radians. Not normalised: any value is accepted and
  /// the helpers wrap it.
  double angle;

  /// Creates a facing, by default [down] (matching [Orientation]'s
  /// default of [Direction.down]).
  Facing([this.angle = down]);

  /// Facing along the vector ([dx], [dy]); [down] for a zero vector.
  factory Facing.fromVector(double dx, double dy) =>
      Facing(dx == 0 && dy == 0 ? down : math.atan2(dy, dx));

  /// Facing the cardinal [direction].
  factory Facing.fromDirection(Direction direction) =>
      Facing(angleOf(direction));

  /// The facing angle of a cardinal [direction].
  static double angleOf(Direction direction) => switch (direction) {
    Direction.right => right,
    Direction.down => down,
    Direction.left => left,
    Direction.up => up,
  };

  /// [angle] wrapped into `[0, 2π)`.
  double get normalized => normalizeFacingAngle(angle);

  /// Turns to face along ([dx], [dy]) if its length exceeds
  /// [minLength]; otherwise keeps the current facing (so a stationary
  /// entity remembers where it last looked).
  ///
  /// Returns true if [angle] changed.
  bool updateFromVector(double dx, double dy, {double minLength = 0}) {
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0 || lengthSquared <= minLength * minLength) {
      return false;
    }
    final next = math.atan2(dy, dx);
    if (next == angle) return false;
    angle = next;
    return true;
  }

  /// The view (0 ≤ index < [views]) to draw for this facing. See
  /// [facingViewIndex] for the convention.
  int viewIndex(int views) => facingViewIndex(angle, views);

  /// The nearest cardinal [Direction], for interop with [Orientation].
  Direction get direction => switch (viewIndex(4)) {
    0 => Direction.right,
    1 => Direction.down,
    2 => Direction.left,
    _ => Direction.up,
  };

  @override
  String toString() => 'Facing(${angle.toStringAsFixed(3)} rad)';
}
