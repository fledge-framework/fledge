import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:screen_retriever/screen_retriever.dart' hide Display;
import 'package:window_manager/window_manager.dart';

import '../events/window_events.dart';
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
/// Runs once on the first frame. Every native call is guarded — on failure
/// a [WindowOperationFailed] event is emitted. Non-fatal failures (setting
/// a title, min/max size, always-on-top) are reported but initialization
/// continues; if the critical setup steps (`ensureInitialized`, display
/// enumeration, or initial mode) fail, init aborts without mutating
/// `WindowState`.
class WindowInitSystem implements System {
  final WindowConfig config;
  bool _initialized = false;

  WindowInitSystem(this.config);

  @override
  SystemMeta get meta => const SystemMeta(
        name: 'WindowInitSystem',
        exclusive: true,
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => runCondition?.call(world) ?? true;

  @override
  Future<void> run(World world) async {
    if (_initialized) return;
    _initialized = true;

    // Critical step 1: backend initialization.
    if (!await _tryNative(
      world,
      'init',
      () => windowManager.ensureInitialized(),
    )) {
      return;
    }

    // Critical step 2: enumerate displays. If this fails we can't pick a
    // target display, so we abort.
    final List<Display> displays;
    final int primaryIndex;
    try {
      final screenDisplays = await screenRetriever.getAllDisplays();
      final primaryDisplay = await screenRetriever.getPrimaryDisplay();
      final result = _buildDisplayList(screenDisplays, primaryDisplay.id);
      displays = result.$1;
      primaryIndex = result.$2;
    } catch (e) {
      world.eventWriter<WindowOperationFailed>().send(
            WindowOperationFailed(
              operation: 'syncDisplays',
              reason: e.toString(),
            ),
          );
      return;
    }

    final displayInfo = world.getResource<DisplayInfo>()!;
    displayInfo.updateDisplays(displays, primaryIndex);

    final targetDisplayIndex = config.targetDisplay ?? primaryIndex;
    final targetDisplay =
        displayInfo.getDisplay(targetDisplayIndex) ?? displayInfo.primary;

    // Non-critical: title + size constraints. Reported on failure, but we
    // keep going so the window still appears.
    await _tryNative(
        world, 'setTitle', () => windowManager.setTitle(config.title));

    if (config.minSize != null) {
      await _tryNative(
        world,
        'setMinimumSize',
        () => windowManager.setMinimumSize(config.minSize!),
      );
    }
    if (config.maxSize != null) {
      await _tryNative(
        world,
        'setMaximumSize',
        () => windowManager.setMaximumSize(config.maxSize!),
      );
    }

    await _tryNative(
      world,
      'setResizable',
      () => windowManager.setResizable(config.resizable),
    );

    if (config.alwaysOnTop) {
      await _tryNative(
        world,
        'setAlwaysOnTop',
        () => windowManager.setAlwaysOnTop(true),
      );
    }

    final windowState = world.getResource<WindowState>()!;
    final modeOk = await _applyMode(
        world, config.mode, targetDisplay, windowState, config);

    // Show + focus. Non-critical in the sense that init doesn't abort, but
    // we do want to reflect actual success in the state.
    final shown = await _tryNative(
      world,
      'show',
      () => windowManager.show(),
    );
    final focused = await _tryNative(
      world,
      'focus',
      () => windowManager.focus(),
    );

    if (shown) windowState.isVisible = true;
    if (focused) windowState.isFocused = true;

    // If the initial mode didn't apply, the window state for mode/size/pos
    // is left as the plugin's optimistic `WindowState.initial(config)` — the
    // game can choose to respond to the failure event.
    if (!modeOk) return;
  }

  Future<bool> _applyMode(
    World world,
    WindowMode mode,
    Display display,
    WindowState state,
    WindowConfig config,
  ) async {
    switch (mode) {
      case WindowMode.fullscreen:
        if (!await _tryNative(
          world,
          'setMode',
          () => windowManager.setFullScreen(true),
          attemptedMode: mode,
        )) {
          return false;
        }
        state.mode = WindowMode.fullscreen;
        state.size = display.size;
        state.position = display.bounds.topLeft;

      case WindowMode.borderless:
        final displayOrigin =
            display.isPrimary ? Offset.zero : display.bounds.topLeft;
        final borderlessBounds = Rect.fromLTWH(
          displayOrigin.dx,
          displayOrigin.dy,
          display.size.width,
          display.size.height,
        );
        if (!await _tryNative(
          world,
          'setMode',
          () async {
            await windowManager.setFullScreen(false);
            await windowManager.setAsFrameless();
            await windowManager.setHasShadow(false);
            await windowManager.setBounds(borderlessBounds);
          },
          attemptedMode: mode,
        )) {
          return false;
        }
        state.mode = WindowMode.borderless;
        state.size = display.size;
        state.position = displayOrigin;

      case WindowMode.windowed:
        final size = config.windowedSize ?? WindowConfig.defaultWindowedSize;
        final position =
            config.windowedPosition ?? _centerOnDisplay(size, display);
        if (!await _tryNative(
          world,
          'setMode',
          () async {
            await windowManager.setFullScreen(false);
            await windowManager.setTitleBarStyle(TitleBarStyle.normal);
            await windowManager.setBounds(Rect.fromLTWH(
              position.dx,
              position.dy,
              size.width,
              size.height,
            ));
          },
          attemptedMode: mode,
        )) {
          return false;
        }
        state.mode = WindowMode.windowed;
        state.size = size;
        state.position = position;
        state.savedWindowedSize = size;
        state.savedWindowedPosition = position;
    }

    state.displayIndex = display.index;
    return true;
  }

  static Future<bool> _tryNative(
    World world,
    String operation,
    Future<void> Function() action, {
    WindowMode? attemptedMode,
  }) async {
    try {
      await action();
      return true;
    } catch (e, _) {
      world.eventWriter<WindowOperationFailed>().send(
            WindowOperationFailed(
              operation: operation,
              reason: e.toString(),
              attemptedMode: attemptedMode,
            ),
          );
      return false;
    }
  }

  /// Pure builder for [DisplayInfo.updateDisplays]'s arguments, exposed for
  /// unit testing.
  static (List<Display>, int) _buildDisplayList(
    List<dynamic> screenDisplays,
    dynamic primaryId,
  ) {
    final displays = <Display>[];
    var primaryIndex = 0;
    for (var i = 0; i < screenDisplays.length; i++) {
      final d = screenDisplays[i];
      final isPrimary = d.id == primaryId;
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
        refreshRate: 60.0,
        isPrimary: isPrimary,
      ));
    }
    return (displays, primaryIndex);
  }

  Offset _centerOnDisplay(Size windowSize, Display display) => Offset(
        display.bounds.left + (display.bounds.width - windowSize.width) / 2,
        display.bounds.top + (display.bounds.height - windowSize.height) / 2,
      );
}
