/// Cursor visibility and capture mode.
enum CursorMode {
  /// Cursor is visible and moves freely.
  visible,

  /// Cursor is hidden but moves freely (tracks position).
  hidden,

  /// Cursor is hidden and captured for relative movement.
  ///
  /// In this mode, [MouseState.deltaX] and [MouseState.deltaY] provide
  /// raw mouse movement regardless of screen boundaries. The cursor
  /// position is not meaningful.
  ///
  /// Note: True pointer lock requires platform support. On platforms
  /// without native pointer lock, this behaves like [hidden] but the
  /// cursor may hit screen edges.
  locked,
}
