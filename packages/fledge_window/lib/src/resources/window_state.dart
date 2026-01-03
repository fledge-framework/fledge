import 'dart:ui';

import '../window_config.dart';
import '../window_mode.dart';

/// Resource containing the current window state.
///
/// Access via `world.getResource<WindowState>()` or `world.windowState`.
///
/// ```dart
/// final windowState = world.windowState;
/// if (windowState != null) {
///   print('Mode: ${windowState.mode}');
///   print('Size: ${windowState.size}');
///   print('Focused: ${windowState.isFocused}');
/// }
/// ```
class WindowState {
  /// Current window mode.
  WindowMode mode;

  /// Current window size in logical pixels.
  Size size;

  /// Current window position in screen coordinates.
  Offset position;

  /// Whether the window is currently focused.
  bool isFocused;

  /// Whether the window is visible.
  bool isVisible;

  /// Whether the window is minimized.
  bool isMinimized;

  /// Whether the window is maximized (windowed mode only).
  bool isMaximized;

  /// The display index this window is primarily on.
  int displayIndex;

  /// Saved windowed size for restoring from fullscreen/borderless.
  Size? savedWindowedSize;

  /// Saved windowed position for restoring from fullscreen/borderless.
  Offset? savedWindowedPosition;

  /// Creates window state with initial values from config.
  ///
  /// This is used internally by the WindowPlugin.
  factory WindowState.initial(WindowConfig config) {
    return WindowState(
      mode: config.mode,
      size: config.windowedSize ?? WindowConfig.defaultWindowedSize,
      position: config.windowedPosition ?? Offset.zero,
      isFocused: false,
      isVisible: false,
      isMinimized: false,
      isMaximized: false,
      displayIndex: config.targetDisplay ?? 0,
      savedWindowedSize: config.windowedSize,
      savedWindowedPosition: config.windowedPosition,
    );
  }

  /// Creates window state from current values.
  WindowState({
    required this.mode,
    required this.size,
    required this.position,
    this.isFocused = false,
    this.isVisible = false,
    this.isMinimized = false,
    this.isMaximized = false,
    this.displayIndex = 0,
    this.savedWindowedSize,
    this.savedWindowedPosition,
  });

  /// Whether the window is in a full-display mode (fullscreen or borderless).
  bool get isFullDisplay =>
      mode == WindowMode.fullscreen || mode == WindowMode.borderless;

  @override
  String toString() {
    return 'WindowState(mode: $mode, size: $size, focused: $isFocused)';
  }
}
