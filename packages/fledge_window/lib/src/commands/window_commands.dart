import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart';

import '../events/window_events.dart';
import '../resources/display_info.dart';
import '../resources/window_state.dart';
import '../window_mode.dart';

/// Extension methods for window control on [World].
///
/// These provide convenient access to window state and actions.
///
/// ```dart
/// // Query state
/// final state = world.windowState;
/// final display = world.displayInfo?.primary;
///
/// // Change mode
/// world.setWindowMode(WindowMode.fullscreen);
/// world.toggleFullscreen();
///
/// // Resize (windowed mode)
/// world.setWindowSize(Size(1920, 1080));
/// ```
extension WindowCommands on World {
  /// Gets the current window state, or null if not initialized.
  WindowState? get windowState => getResource<WindowState>();

  /// Gets display information, or null if not initialized.
  DisplayInfo? get displayInfo => getResource<DisplayInfo>();

  /// Requests a window mode change.
  ///
  /// The change is processed by [WindowEventSystem] and will fire a
  /// [WindowModeChanged] event when complete.
  ///
  /// ```dart
  /// world.setWindowMode(WindowMode.fullscreen);
  /// world.setWindowMode(WindowMode.borderless, targetDisplay: 1);
  /// ```
  void setWindowMode(WindowMode mode, {int? targetDisplay}) {
    eventWriter<SetWindowModeRequest>()
        .send(SetWindowModeRequest(mode, targetDisplay: targetDisplay));
  }

  /// Requests a window size change (windowed mode only).
  ///
  /// Has no effect in fullscreen or borderless mode.
  ///
  /// ```dart
  /// world.setWindowSize(Size(1920, 1080));
  /// ```
  void setWindowSize(Size size) {
    eventWriter<SetWindowSizeRequest>().send(SetWindowSizeRequest(size));
  }

  /// Requests a window position change (windowed mode only).
  ///
  /// Has no effect in fullscreen or borderless mode.
  ///
  /// ```dart
  /// world.setWindowPosition(Offset(100, 100));
  /// ```
  void setWindowPosition(Offset position) {
    eventWriter<SetWindowPositionRequest>()
        .send(SetWindowPositionRequest(position));
  }

  /// Toggles between fullscreen and windowed mode.
  ///
  /// If currently fullscreen, switches to windowed (restoring previous size).
  /// If currently windowed or borderless, switches to fullscreen.
  ///
  /// ```dart
  /// // Bind to F11 key
  /// if (actions.justPressed(ActionId('toggleFullscreen'))) {
  ///   world.toggleFullscreen();
  /// }
  /// ```
  void toggleFullscreen() {
    final state = windowState;
    if (state == null) return;

    if (state.mode == WindowMode.fullscreen) {
      setWindowMode(WindowMode.windowed);
    } else {
      setWindowMode(WindowMode.fullscreen);
    }
  }

  /// Toggles between borderless and windowed mode.
  ///
  /// If currently borderless, switches to windowed (restoring previous size).
  /// If currently windowed or fullscreen, switches to borderless.
  ///
  /// ```dart
  /// if (actions.justPressed(ActionId('toggleBorderless'))) {
  ///   world.toggleBorderless();
  /// }
  /// ```
  void toggleBorderless() {
    final state = windowState;
    if (state == null) return;

    if (state.mode == WindowMode.borderless) {
      setWindowMode(WindowMode.windowed);
    } else {
      setWindowMode(WindowMode.borderless);
    }
  }

  /// Cycles through all window modes: windowed -> borderless -> fullscreen.
  ///
  /// ```dart
  /// if (actions.justPressed(ActionId('cycleWindowMode'))) {
  ///   world.cycleWindowMode();
  /// }
  /// ```
  void cycleWindowMode() {
    final state = windowState;
    if (state == null) return;

    final nextMode = switch (state.mode) {
      WindowMode.windowed => WindowMode.borderless,
      WindowMode.borderless => WindowMode.fullscreen,
      WindowMode.fullscreen => WindowMode.windowed,
    };

    setWindowMode(nextMode);
  }
}
