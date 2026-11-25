import 'dart:ui' show Color;

/// A solid-colour panel UI node.
///
/// Drawn by `FledgeUiOverlay` filling the entity's computed rect: with
/// `Canvas.drawRect`, or `Canvas.drawRRect` when [borderRadius] is greater
/// than zero.
class UiRect {
  /// Fill colour.
  final Color color;

  /// Corner radius in logical pixels. `0.0` = square corners. Positive =
  /// rounded corners.
  final double borderRadius;

  /// Creates a UI rect panel.
  const UiRect({required this.color, this.borderRadius = 0.0});
}
