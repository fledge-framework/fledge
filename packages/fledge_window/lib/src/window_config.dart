import 'dart:ui';

import 'window_mode.dart';

/// Configuration for window initialization.
///
/// Pass this to [WindowPlugin] to configure the initial window state.
///
/// ```dart
/// // Fullscreen game
/// WindowPlugin(config: WindowConfig.fullscreen(title: 'My Game'))
///
/// // Borderless windowed
/// WindowPlugin(config: WindowConfig.borderless(title: 'My Game'))
///
/// // Custom windowed setup
/// WindowPlugin(config: WindowConfig(
///   mode: WindowMode.windowed,
///   title: 'My Game',
///   windowedSize: Size(1920, 1080),
///   minSize: Size(800, 600),
/// ))
/// ```
class WindowConfig {
  /// Initial window mode.
  final WindowMode mode;

  /// Window title displayed in the title bar.
  final String title;

  /// Initial size for windowed mode.
  ///
  /// If null, defaults to 1280x720.
  final Size? windowedSize;

  /// Initial position for windowed mode.
  ///
  /// If null, the window will be centered on the target display.
  final Offset? windowedPosition;

  /// Target display index.
  ///
  /// If null, uses the primary display.
  final int? targetDisplay;

  /// Minimum window size (for windowed mode).
  final Size? minSize;

  /// Maximum window size (for windowed mode).
  ///
  /// If null, no maximum is enforced.
  final Size? maxSize;

  /// Whether the window should always be on top.
  final bool alwaysOnTop;

  /// Whether the window should be resizable in windowed mode.
  final bool resizable;

  /// Creates a window configuration.
  const WindowConfig({
    this.mode = WindowMode.borderless,
    this.title = 'Fledge Game',
    this.windowedSize,
    this.windowedPosition,
    this.targetDisplay,
    this.minSize,
    this.maxSize,
    this.alwaysOnTop = false,
    this.resizable = true,
  });

  /// Creates a fullscreen configuration.
  ///
  /// This is equivalent to:
  /// ```dart
  /// WindowConfig(mode: WindowMode.fullscreen, title: title)
  /// ```
  const WindowConfig.fullscreen({
    String title = 'Fledge Game',
    int? targetDisplay,
  })  : mode = WindowMode.fullscreen,
        title = title,
        windowedSize = null,
        windowedPosition = null,
        targetDisplay = targetDisplay,
        minSize = null,
        maxSize = null,
        alwaysOnTop = false,
        resizable = true;

  /// Creates a borderless windowed configuration.
  ///
  /// This is equivalent to:
  /// ```dart
  /// WindowConfig(mode: WindowMode.borderless, title: title)
  /// ```
  const WindowConfig.borderless({
    String title = 'Fledge Game',
    int? targetDisplay,
  })  : mode = WindowMode.borderless,
        title = title,
        windowedSize = null,
        windowedPosition = null,
        targetDisplay = targetDisplay,
        minSize = null,
        maxSize = null,
        alwaysOnTop = false,
        resizable = true;

  /// Creates a windowed configuration with optional size.
  ///
  /// If [size] is null, defaults to 1280x720.
  const WindowConfig.windowed({
    String title = 'Fledge Game',
    Size? size,
    Offset? position,
    Size? minSize,
    Size? maxSize,
    bool resizable = true,
  })  : mode = WindowMode.windowed,
        title = title,
        windowedSize = size,
        windowedPosition = position,
        targetDisplay = null,
        minSize = minSize,
        maxSize = maxSize,
        alwaysOnTop = false,
        resizable = resizable;

  /// Default size for windowed mode when no size is specified.
  static const Size defaultWindowedSize = Size(1280, 720);
}
