import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:screen_retriever/screen_retriever.dart' hide Display;
import 'package:window_manager/window_manager.dart';

import '../resources/display_info.dart';
import '../resources/window_state.dart';
import '../window_config.dart';
import '../window_mode.dart';

/// System that initializes the window on app startup.
///
/// This system:
/// 1. Ensures window_manager is initialized
/// 2. Gathers display information
/// 3. Applies the initial window configuration
/// 4. Shows and focuses the window
///
/// It runs only once on the first frame.
class WindowInitSystem implements System {
  final WindowConfig config;
  bool _initialized = false;

  WindowInitSystem(this.config);

  @override
  SystemMeta get meta => const SystemMeta(
        name: 'WindowInitSystem',
        exclusive: true, // Needs sole access during initialization
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => runCondition?.call(world) ?? true;

  @override
  Future<void> run(World world) async {
    // Only run once
    if (_initialized) return;
    _initialized = true;
    // Ensure window_manager is initialized
    await windowManager.ensureInitialized();

    // Gather display information
    final screenDisplays = await screenRetriever.getAllDisplays();
    final primaryDisplay = await screenRetriever.getPrimaryDisplay();

    // Build our Display objects
    final displays = <Display>[];
    var primaryIndex = 0;

    for (var i = 0; i < screenDisplays.length; i++) {
      final d = screenDisplays[i];
      final isPrimary = d.id == primaryDisplay.id;
      if (isPrimary) primaryIndex = i;

      displays.add(Display(
        index: i,
        name: d.name ?? 'Display $i',
        size: Size(d.size.width, d.size.height),
        bounds: Rect.fromLTWH(
          d.visiblePosition?.dx ?? 0,
          d.visiblePosition?.dy ?? 0,
          d.visibleSize?.width ?? d.size.width,
          d.visibleSize?.height ?? d.size.height,
        ),
        scaleFactor: (d.scaleFactor ?? 1.0).toDouble(),
        refreshRate: 60.0, // screen_retriever doesn't provide refresh rate
        isPrimary: isPrimary,
      ));
    }

    // Update DisplayInfo resource
    final displayInfo = world.getResource<DisplayInfo>()!;
    displayInfo.updateDisplays(displays, primaryIndex);

    // Determine target display
    final targetDisplayIndex = config.targetDisplay ?? primaryIndex;
    final targetDisplay =
        displayInfo.getDisplay(targetDisplayIndex) ?? displayInfo.primary;

    // Set window title
    await windowManager.setTitle(config.title);

    // Set size constraints if specified
    if (config.minSize != null) {
      await windowManager.setMinimumSize(config.minSize!);
    }
    if (config.maxSize != null) {
      await windowManager.setMaximumSize(config.maxSize!);
    }

    // Set resizable
    await windowManager.setResizable(config.resizable);

    // Set always on top
    if (config.alwaysOnTop) {
      await windowManager.setAlwaysOnTop(true);
    }

    // Apply initial mode
    final windowState = world.getResource<WindowState>()!;
    await _applyMode(config.mode, targetDisplay, windowState, config);

    // Show and focus window
    await windowManager.show();
    await windowManager.focus();

    windowState.isVisible = true;
    windowState.isFocused = true;
  }

  Future<void> _applyMode(
    WindowMode mode,
    Display display,
    WindowState state,
    WindowConfig config,
  ) async {
    switch (mode) {
      case WindowMode.fullscreen:
        await windowManager.setFullScreen(true);
        state.mode = WindowMode.fullscreen;
        state.size = display.size;
        state.position = display.bounds.topLeft;

      case WindowMode.borderless:
        await windowManager.setFullScreen(false);
        // Remove all window decorations and shadows for true borderless
        await windowManager.setAsFrameless();
        await windowManager.setHasShadow(false);
        // Position at display origin with full display size
        // For primary display, origin is (0,0). For secondary displays,
        // we use bounds.topLeft as an approximation of the display origin.
        final displayOrigin =
            display.isPrimary ? Offset.zero : display.bounds.topLeft;
        final borderlessBounds = Rect.fromLTWH(
          displayOrigin.dx,
          displayOrigin.dy,
          display.size.width,
          display.size.height,
        );
        await windowManager.setBounds(borderlessBounds);
        state.mode = WindowMode.borderless;
        state.size = display.size;
        state.position = displayOrigin;

      case WindowMode.windowed:
        await windowManager.setFullScreen(false);
        await windowManager.setTitleBarStyle(TitleBarStyle.normal);

        final size = config.windowedSize ?? WindowConfig.defaultWindowedSize;
        final position =
            config.windowedPosition ?? _centerOnDisplay(size, display);

        await windowManager.setBounds(Rect.fromLTWH(
          position.dx,
          position.dy,
          size.width,
          size.height,
        ));
        state.mode = WindowMode.windowed;
        state.size = size;
        state.position = position;
        state.savedWindowedSize = size;
        state.savedWindowedPosition = position;
    }

    state.displayIndex = display.index;
  }

  Offset _centerOnDisplay(Size windowSize, Display display) {
    return Offset(
      display.bounds.left + (display.bounds.width - windowSize.width) / 2,
      display.bounds.top + (display.bounds.height - windowSize.height) / 2,
    );
  }
}
