import 'package:vector_math/vector_math.dart';

/// Computed global transform (world space).
///
/// This component is automatically updated by the transform propagation
/// system based on the entity hierarchy. It represents the final
/// world-space transformation after all parent transforms are applied.
///
/// Do not modify this directly - modify [Transform2D] instead and
/// let the propagation system update this.
class GlobalTransform2D {
  /// The world-space transformation matrix.
  Matrix3 matrix;

  /// Creates a global transform with the given matrix.
  GlobalTransform2D([Matrix3? matrix]) : matrix = matrix ?? Matrix3.identity();

  /// Creates an identity global transform.
  factory GlobalTransform2D.identity() => GlobalTransform2D();

  /// The world-space translation (position).
  Vector2 get translation => Vector2(matrix[6], matrix[7]);

  /// Set the translation directly.
  set translation(Vector2 value) {
    matrix[6] = value.x;
    matrix[7] = value.y;
  }

  /// The x position in world space.
  double get x => matrix[6];

  /// The y position in world space.
  double get y => matrix[7];

  /// Transform a local point to world space.
  Vector2 transformPoint(Vector2 local) {
    final result = Vector3(local.x, local.y, 1);
    matrix.transform(result);
    return Vector2(result.x, result.y);
  }

  /// Transform a local vector (ignores translation).
  Vector2 transformVector(Vector2 local) {
    final result = Vector3(local.x, local.y, 0);
    matrix.transform(result);
    return Vector2(result.x, result.y);
  }

  /// Create a copy of this global transform.
  GlobalTransform2D clone() => GlobalTransform2D(matrix.clone());

  /// Copy values from another global transform.
  void copyFrom(GlobalTransform2D other) {
    matrix.setFrom(other.matrix);
  }

  /// Compute the inverse transform.
  GlobalTransform2D inverse() {
    final inv = Matrix3.zero();
    matrix.copyInverse(inv);
    return GlobalTransform2D(inv);
  }

  @override
  String toString() =>
      'GlobalTransform2D(x: ${x.toStringAsFixed(2)}, y: ${y.toStringAsFixed(2)})';
}
