import 'dart:ui' show Color, FontWeight, TextAlign;

/// A text UI node.
///
/// Text is rendered directly on the widget's canvas via
/// `Canvas.drawParagraph` (see `FledgeUiOverlay`) — it bypasses the
/// sprite pipeline, since dart:ui text shaping is a separate concern
/// from atlas draws.
///
/// The [text] field is deliberately mutable so games can update HUD
/// content without spawning new entities per frame (e.g. a score
/// counter or a lap timer).
class UiText {
  /// The string to draw.
  String text;

  /// Font size in logical pixels.
  final double fontSize;

  /// Text color.
  final Color color;

  /// Optional font family. `null` uses Flutter's platform default.
  final String? fontFamily;

  /// Font weight.
  final FontWeight fontWeight;

  /// Horizontal alignment within the node's computed rect.
  final TextAlign align;

  /// Creates a UI text node.
  UiText({
    required this.text,
    this.fontSize = 14.0,
    this.color = const Color(0xFFFFFFFF),
    this.fontFamily,
    this.fontWeight = FontWeight.normal,
    this.align = TextAlign.left,
  });
}
