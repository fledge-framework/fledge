/// Where a UI node anchors relative to its parent's padded interior
/// (or the viewport, for root nodes).
///
/// The anchor is a point on both the parent's rect and the child's own
/// rect. The child is positioned so those two points coincide, then
/// offset by [UiOffset]. This mirrors the "align + position" model used
/// by CSS and Flutter's `Align` widget.
enum UiAnchor {
  /// Top-left corner.
  topLeft,

  /// Top edge, horizontally centred.
  topCenter,

  /// Top-right corner.
  topRight,

  /// Left edge, vertically centred.
  centerLeft,

  /// Both axes centred.
  center,

  /// Right edge, vertically centred.
  centerRight,

  /// Bottom-left corner.
  bottomLeft,

  /// Bottom edge, horizontally centred.
  bottomCenter,

  /// Bottom-right corner.
  bottomRight;

  /// Returns `(nx, ny)` in the 0..1 range representing the anchor's
  /// normalized position within a rect.
  ///
  /// `(0, 0)` is top-left, `(0.5, 0.5)` is centre, `(1, 1)` is
  /// bottom-right. Used for both the parent's anchor point *and* the
  /// child's own anchor point.
  (double, double) get normalized {
    switch (this) {
      case UiAnchor.topLeft:
        return (0.0, 0.0);
      case UiAnchor.topCenter:
        return (0.5, 0.0);
      case UiAnchor.topRight:
        return (1.0, 0.0);
      case UiAnchor.centerLeft:
        return (0.0, 0.5);
      case UiAnchor.center:
        return (0.5, 0.5);
      case UiAnchor.centerRight:
        return (1.0, 0.5);
      case UiAnchor.bottomLeft:
        return (0.0, 1.0);
      case UiAnchor.bottomCenter:
        return (0.5, 1.0);
      case UiAnchor.bottomRight:
        return (1.0, 1.0);
    }
  }
}

/// Anchor point of this node within its parent's rect.
///
/// Named `UiAnchorComponent` (rather than `UiAnchor`) because the enum
/// [UiAnchor] itself is the far more common thing to type. Games spell
/// their anchor as `UiAnchor.topLeft`, then attach it via
/// `UiAnchorComponent(UiAnchor.topLeft)`.
class UiAnchorComponent {
  /// Which corner / edge / centre the node anchors to.
  final UiAnchor anchor;

  /// Creates an anchor component.
  const UiAnchorComponent(this.anchor);
}
