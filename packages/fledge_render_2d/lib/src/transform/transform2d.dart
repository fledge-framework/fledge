import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

/// 2D transform component.
///
/// Represents local position, rotation, and scale relative to parent.
/// Use [GlobalTransform2D] for the computed world-space transform.
///
/// Example:
/// ```dart
/// final transform = Transform2D(
///   translation: Vector2(100, 200),
///   rotation: math.pi / 4, // 45 degrees
///   scale: Vector2.all(2),
/// );
/// ```
class Transform2D {
  /// Local position relative to parent.
  Vector2 translation;

  /// Local rotation in radians.
  double rotation;

  /// Local scale.
  Vector2 scale;

  /// Creates a transform with the specified values.
  Transform2D({
    Vector2? translation,
    this.rotation = 0,
    Vector2? scale,
  })  : translation = translation ?? Vector2.zero(),
        scale = scale ?? Vector2(1, 1);

  /// Creates a transform with only translation.
  factory Transform2D.from(double x, double y) =>
      Transform2D(translation: Vector2(x, y));

  /// Creates a transform at the origin with no rotation or scale.
  factory Transform2D.identity() => Transform2D();

  /// Convert to a 3x3 transformation matrix.
  ///
  /// The matrix applies transformations in order:
  /// scale -> rotate -> translate
  Matrix3 toMatrix() {
    final cos = math.cos(rotation);
    final sin = math.sin(rotation);

    // Scale and rotate
    final a = cos * scale.x;
    final b = sin * scale.x;
    final c = -sin * scale.y;
    final d = cos * scale.y;

    // Combine with translation
    return Matrix3(
      a,
      b,
      0,
      c,
      d,
      0,
      translation.x,
      translation.y,
      1,
    );
  }

  /// Set translation from x and y values.
  void setTranslation(double x, double y) {
    translation.setValues(x, y);
  }

  /// Set scale uniformly.
  void setUniformScale(double s) {
    scale.setValues(s, s);
  }

  /// Rotate by the given angle in radians.
  void rotate(double angle) {
    rotation += angle;
  }

  /// Set rotation in degrees (convenience).
  void setRotationDegrees(double degrees) {
    rotation = degrees * (math.pi / 180);
  }

  /// Get rotation in degrees.
  double get rotationDegrees => rotation * (180 / math.pi);

  /// Translate by the given delta.
  void translate(double dx, double dy) {
    translation.x += dx;
    translation.y += dy;
  }

  /// Create a copy of this transform.
  Transform2D clone() => Transform2D(
        translation: translation.clone(),
        rotation: rotation,
        scale: scale.clone(),
      );

  /// Copy values from another transform.
  void copyFrom(Transform2D other) {
    translation.setFrom(other.translation);
    rotation = other.rotation;
    scale.setFrom(other.scale);
  }

  @override
  String toString() => 'Transform2D('
      'translation: (${translation.x.toStringAsFixed(2)}, ${translation.y.toStringAsFixed(2)}), '
      'rotation: ${rotationDegrees.toStringAsFixed(1)}°, '
      'scale: (${scale.x.toStringAsFixed(2)}, ${scale.y.toStringAsFixed(2)}))';
}
