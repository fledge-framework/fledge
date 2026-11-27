import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

/// Whether [WindowMode.borderless] is drawn with the OS's own fullscreen
/// instead of a frameless window sized to the display.
///
/// True on macOS. AppKit keeps every ordinary window below the menu bar and
/// clear of the Dock, so a frameless window given the display's bounds
/// still leaves both showing. The macOS way to cover the screen is native
/// fullscreen (its own Space; the menu bar slides in when the pointer
/// reaches the top), which macOS games use for borderless too. macOS has no
/// exclusive fullscreen, so borderless and fullscreen look the same there.
bool get borderlessUsesNativeFullScreen =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

/// Puts the window into borderless mode covering [bounds] (the display's).
Future<void> enterBorderless(Rect bounds) async {
  if (borderlessUsesNativeFullScreen) {
    // Hides the title bar, so it doesn't slide in with the menu bar.
    await windowManager.setAsFrameless();
    // AppKit won't take a hidden window fullscreen, and at startup the
    // window is still hidden when the mode is applied.
    await windowManager.show();
    await windowManager.setFullScreen(true);
    return;
  }
  await windowManager.setFullScreen(false);
  await windowManager.setAsFrameless();
  await windowManager.setHasShadow(false);
  await windowManager.setBounds(bounds);
}

/// Takes the window out of fullscreen, if it is.
///
/// On macOS leaving fullscreen is an animation that ends after the native
/// call returns, and AppKit then puts back the frame the window had before
/// it went fullscreen, undoing bounds set meanwhile. So this waits (up to
/// [timeout]) until the window is out before callers set its bounds.
Future<void> leaveFullScreen({
  Duration timeout = const Duration(seconds: 2),
}) async {
  await windowManager.setFullScreen(false);
  if (!borderlessUsesNativeFullScreen) return;
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    bool stillFullScreen;
    try {
      stillFullScreen = await windowManager.isFullScreen();
    } catch (_) {
      return; // Can't tell: carry on rather than hang.
    }
    if (!stillFullScreen) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}
