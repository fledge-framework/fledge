/// How a [UiContainer] arranges its children.
enum LayoutMode {
  /// Children stack in the same anchored position (last child on top).
  ///
  /// Useful for placing a badge over an icon, or overlaying text on
  /// a background rect.
  stack,

  /// Children laid out left-to-right with [UiContainer.gap] pixels
  /// between each.
  row,

  /// Children laid out top-to-bottom with [UiContainer.gap] pixels
  /// between each.
  column,
}

/// A container that lays out its children according to [mode].
///
/// Children are established through the existing hierarchy
/// (`Parent` / `Children` in `fledge_ecs`), so any UI entity with a
/// `Parent(container)` is treated as a child of `container` at layout
/// time.
///
/// Padding trims the interior rect used for laying out children — the
/// container's outer rect is what gets anchored inside *its* parent.
class UiContainer {
  /// How children are arranged.
  final LayoutMode mode;

  /// Space in logical pixels between adjacent children in
  /// [LayoutMode.row] / [LayoutMode.column] layouts. Ignored for
  /// [LayoutMode.stack].
  final double gap;

  /// Left padding in logical pixels.
  final double paddingLeft;

  /// Top padding in logical pixels.
  final double paddingTop;

  /// Right padding in logical pixels.
  final double paddingRight;

  /// Bottom padding in logical pixels.
  final double paddingBottom;

  /// Creates a container.
  const UiContainer({
    this.mode = LayoutMode.stack,
    this.gap = 0.0,
    this.paddingLeft = 0.0,
    this.paddingTop = 0.0,
    this.paddingRight = 0.0,
    this.paddingBottom = 0.0,
  });

  /// Convenience: symmetric padding on all four sides.
  const UiContainer.padded({
    this.mode = LayoutMode.stack,
    this.gap = 0.0,
    double padding = 0.0,
  })  : paddingLeft = padding,
        paddingTop = padding,
        paddingRight = padding,
        paddingBottom = padding;

  /// Total horizontal padding (left + right).
  double get horizontalPadding => paddingLeft + paddingRight;

  /// Total vertical padding (top + bottom).
  double get verticalPadding => paddingTop + paddingBottom;
}
