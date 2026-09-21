import 'dart:ui' show Color;

/// A solid-colour panel UI node.
///
/// Rendered by tinting `kSolidColorTexture` (a 1×1 white pixel
/// registered by the render plugin) when [borderRadius] is `0.0`, so
/// the same sprite-batching path handles UI rects and other UI
/// images. When [borderRadius] is greater than zero, the extractor
/// emits a dedicated `ExtractedUiRect` and the widget paints it
/// directly via `Canvas.drawRRect` — the sprite pipeline has no
/// per-quad geometry override to draw a rounded rect.
class UiRect {
  /// Fill colour.
  final Color color;

  /// Corner radius in logical pixels. `0.0` = square corners (fast
  /// sprite path). Positive = rounded, drawn via `Canvas.drawRRect`.
  final double borderRadius;

  /// Creates a UI rect panel.
  const UiRect({required this.color, this.borderRadius = 0.0});
}
