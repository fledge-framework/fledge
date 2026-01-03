/// Window display modes.
enum WindowMode {
  /// True fullscreen (exclusive).
  ///
  /// The window takes over the entire display with no window decorations.
  /// This mode may have better performance on some platforms.
  fullscreen,

  /// Borderless window matching display size (windowed borderless).
  ///
  /// A frameless window that covers the entire display but isn't truly
  /// fullscreen. Allows for faster alt-tabbing and better multi-monitor
  /// support than true fullscreen.
  borderless,

  /// Standard windowed mode with title bar and borders.
  ///
  /// The window can be resized, moved, minimized, and maximized.
  windowed,
}
