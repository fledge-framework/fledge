import 'dart:ui' show Color, FontWeight, Rect, TextAlign;

import 'package:fledge_render_2d/fledge_render_2d.dart'
    show ExtractedData, SortableExtractedData, TextureHandle;

/// Common base for extracted UI elements.
///
/// Every UI element carries a screen-space [rect] and a [sortKey]
/// that determines draw order within the UI pass (higher = drawn on
/// top). The concrete subtypes ([ExtractedUiImage], [ExtractedUiRect],
/// [ExtractedUiText]) add the per-kind fields the painter needs.
///
/// UI elements are intentionally NOT [ExtractedSprite]s — sharing the
/// sprite storage would force the base sprite render path to draw
/// them, double-drawing over the game view. The UI painter draws
/// these directly on its own canvas layer.
sealed class ExtractedUiElement with ExtractedData, SortableExtractedData {
  /// The element's screen-space rectangle in logical pixels.
  final Rect rect;

  /// Draw-order key. Higher values draw on top of lower ones. The
  /// [UiExtractor] assigns keys inside `DrawLayer.ui`'s sort range so
  /// UI elements always stack over gameplay sprites.
  @override
  final int sortKey;

  /// Creates a UI element.
  const ExtractedUiElement({required this.rect, required this.sortKey});
}

/// Extracted image UI element — a tinted textured quad.
class ExtractedUiImage extends ExtractedUiElement {
  /// The texture to sample.
  final TextureHandle texture;

  /// Source rectangle in texture pixels. `null` uses the whole
  /// texture.
  final Rect? sourceRect;

  /// Tint applied to the sampled texels.
  final Color tint;

  /// Creates an extracted UI image.
  const ExtractedUiImage({
    required super.rect,
    required super.sortKey,
    required this.texture,
    this.sourceRect,
    this.tint = const Color(0xFFFFFFFF),
  });
}

/// Extracted solid-colour UI panel.
///
/// [borderRadius] of `0.0` is drawn as a plain filled rect;
/// positive values use `Canvas.drawRRect`.
class ExtractedUiRect extends ExtractedUiElement {
  /// Fill colour.
  final Color color;

  /// Corner radius in logical pixels.
  final double borderRadius;

  /// Creates an extracted UI rect.
  const ExtractedUiRect({
    required super.rect,
    required super.sortKey,
    required this.color,
    this.borderRadius = 0.0,
  });
}

/// Extracted text UI element.
///
/// Drawn via `Canvas.drawParagraph` — text shaping runs on the paint
/// thread, so the extractor just copies the plain values through.
class ExtractedUiText extends ExtractedUiElement {
  /// The string to draw.
  final String text;

  /// Font size in logical pixels.
  final double fontSize;

  /// Text colour.
  final Color color;

  /// Font family, or `null` for the platform default.
  final String? fontFamily;

  /// Font weight.
  final FontWeight fontWeight;

  /// Horizontal alignment within [rect].
  final TextAlign align;

  /// Creates an extracted UI text.
  const ExtractedUiText({
    required super.rect,
    required super.sortKey,
    required this.text,
    this.fontSize = 14.0,
    this.color = const Color(0xFFFFFFFF),
    this.fontFamily,
    this.fontWeight = FontWeight.normal,
    this.align = TextAlign.left,
  });
}
