import 'package:vector_math/vector_math.dart';

/// Utilities for pixel-perfect 2D rendering.
///
/// Pixel-perfect rendering prevents visual artifacts like tile seams
/// by ensuring positions align to whole pixel boundaries.

/// Snap a double value to the nearest integer (pixel).
double snapToPixel(double value) => value.roundToDouble();

/// Snap a Vector2 position to the nearest pixel.
Vector2 snapVector2ToPixel(Vector2 position) {
  return Vector2(
    position.x.roundToDouble(),
    position.y.roundToDouble(),
  );
}

/// Snap a Vector2 position to pixels, modifying in place.
void snapVector2ToPixelInPlace(Vector2 position) {
  position.x = position.x.roundToDouble();
  position.y = position.y.roundToDouble();
}

/// Extension methods for pixel-perfect Vector2 operations.
extension PixelPerfectVector2 on Vector2 {
  /// Returns a new Vector2 snapped to pixel boundaries.
  Vector2 get snappedToPixel => Vector2(
        x.roundToDouble(),
        y.roundToDouble(),
      );

  /// Snaps this Vector2 to pixel boundaries in place.
  void snapToPixel() {
    x = x.roundToDouble();
    y = y.roundToDouble();
  }
}
