import 'dart:ui';

import '../window_mode.dart';

/// Event fired when the window mode changes.
///
/// ```dart
/// for (final event in world.readEvents<WindowModeChanged>()) {
///   print('Mode changed: ${event.previousMode} -> ${event.newMode}');
/// }
/// ```
class WindowModeChanged {
  /// The previous window mode.
  final WindowMode previousMode;

  /// The new window mode.
  final WindowMode newMode;

  /// Creates a window mode changed event.
  const WindowModeChanged({
    required this.previousMode,
    required this.newMode,
  });

  @override
  String toString() =>
      'WindowModeChanged($previousMode -> $newMode)';
}

/// Event fired when the window is resized.
///
/// ```dart
/// for (final event in world.readEvents<WindowResized>()) {
///   print('Resized: ${event.previousSize} -> ${event.newSize}');
///   // Update camera viewport, UI layout, etc.
/// }
/// ```
class WindowResized {
  /// The previous window size.
  final Size previousSize;

  /// The new window size.
  final Size newSize;

  /// Creates a window resized event.
  const WindowResized({
    required this.previousSize,
    required this.newSize,
  });

  @override
  String toString() =>
      'WindowResized(${previousSize.width.toInt()}x${previousSize.height.toInt()} '
      '-> ${newSize.width.toInt()}x${newSize.height.toInt()})';
}

/// Event fired when window focus changes.
///
/// ```dart
/// for (final event in world.readEvents<WindowFocusChanged>()) {
///   if (!event.isFocused) {
///     // Pause game when losing focus
///     world.setNextState(GameState.paused);
///   }
/// }
/// ```
class WindowFocusChanged {
  /// Whether the window is now focused.
  final bool isFocused;

  /// Creates a window focus changed event.
  const WindowFocusChanged({required this.isFocused});

  @override
  String toString() =>
      'WindowFocusChanged(${isFocused ? 'focused' : 'unfocused'})';
}

/// Event fired when the window is moved.
class WindowMoved {
  /// The previous window position.
  final Offset previousPosition;

  /// The new window position.
  final Offset newPosition;

  /// Creates a window moved event.
  const WindowMoved({
    required this.previousPosition,
    required this.newPosition,
  });
}

// Request events - sent by game code to request changes

/// Request to change the window mode.
///
/// Send this event to change the window mode:
/// ```dart
/// world.sendEvent(SetWindowModeRequest(WindowMode.fullscreen));
/// ```
///
/// Or use the convenience methods:
/// ```dart
/// world.setWindowMode(WindowMode.fullscreen);
/// world.toggleFullscreen();
/// ```
class SetWindowModeRequest {
  /// The desired window mode.
  final WindowMode mode;

  /// Target display index (null = current display).
  final int? targetDisplay;

  /// Creates a window mode request.
  const SetWindowModeRequest(this.mode, {this.targetDisplay});
}

/// Request to resize the window (windowed mode only).
///
/// Send this event to resize the window:
/// ```dart
/// world.sendEvent(SetWindowSizeRequest(Size(1920, 1080)));
/// ```
///
/// Or use the convenience method:
/// ```dart
/// world.setWindowSize(Size(1920, 1080));
/// ```
class SetWindowSizeRequest {
  /// The desired window size.
  final Size size;

  /// Creates a window size request.
  const SetWindowSizeRequest(this.size);
}

/// Request to move the window (windowed mode only).
class SetWindowPositionRequest {
  /// The desired window position.
  final Offset position;

  /// Creates a window position request.
  const SetWindowPositionRequest(this.position);
}
