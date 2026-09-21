import 'dart:ui' show Rect;

/// Marker: this entity is a UI node.
///
/// Excludes it from world-space sprite extractors (they should filter on
/// `Without<UiNode>` if you don't want the UI entity's sprite drawn in
/// world space by mistake). The [UiExtractor] handles UI entities
/// separately.
class UiNode {
  /// Creates a UI node marker.
  const UiNode();
}

/// Explicit size in logical pixels.
///
/// Optional — if absent, size derives from the node's content (text
/// extent, image size, sum of children in row/column containers, ...).
class UiSize {
  /// The desired width in logical pixels.
  final double width;

  /// The desired height in logical pixels.
  final double height;

  /// Creates an explicit UI size.
  const UiSize({required this.width, required this.height});
}

/// Screen-space offset from the anchor point.
///
/// Positive x = right, positive y = down (screen coordinates).
class UiOffset {
  /// Horizontal offset in logical pixels.
  final double x;

  /// Vertical offset in logical pixels.
  final double y;

  /// Creates a UI offset.
  const UiOffset({this.x = 0.0, this.y = 0.0});
}

/// Output of [LayoutSystem] — the entity's laid-out screen-space rect.
///
/// Written by the layout system in `Schedules.postUpdate` and consumed
/// by the extractor + widget paint pass. Mutable so the layout system
/// can update it in place without archetype churn.
class UiComputedRect {
  /// The entity's screen-space rectangle in logical pixels.
  Rect rect;

  /// Creates a computed-rect component.
  UiComputedRect(this.rect);
}
