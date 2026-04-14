import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:window_manager/window_manager.dart';

import '../events/window_events.dart';
import '../resources/display_info.dart';
import '../resources/window_state.dart';
import '../window_mode.dart';

/// System that processes window change requests.
///
/// Handles [SetWindowModeRequest], [SetWindowSizeRequest], and
/// [SetWindowPositionRequest] events and applies the changes.
///
/// Every native call is guarded: if the OS/backend rejects the operation
/// or the call throws, a [WindowOperationFailed] event is emitted and the
/// [WindowState] is left unchanged. Success events fire only after the
/// native call returns cleanly.
class WindowEventSystem implements System {
  @override
  SystemMeta get meta => const SystemMeta(
        name: 'WindowEventSystem',
        eventReads: {
          SetWindowModeRequest,
          SetWindowSizeRequest,
          SetWindowPositionRequest,
        },
        eventWrites: {
          WindowModeChanged,
          WindowResized,
          WindowMoved,
          WindowOperationFailed,
        },
        resourceReads: {DisplayInfo},
        resourceWrites: {WindowState},
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => runCondition?.call(world) ?? true;

  @override
  Future<void> run(World world) async {
    final windowState = world.getResource<WindowState>();
    final displayInfo = world.getResource<DisplayInfo>();

    if (windowState == null || displayInfo == null) return;

    final modeReader = world.eventReader<SetWindowModeRequest>();
    for (final request in modeReader.read()) {
      await _handleModeChange(world, request, windowState, displayInfo);
    }

    final sizeReader = world.eventReader<SetWindowSizeRequest>();
    for (final request in sizeReader.read()) {
      await _handleSizeChange(world, request, windowState);
    }

    final positionReader = world.eventReader<SetWindowPositionRequest>();
    for (final request in positionReader.read()) {
      await _handlePositionChange(world, request, windowState);
    }
  }

  Future<void> _handleModeChange(
    World world,
    SetWindowModeRequest request,
    WindowState state,
    DisplayInfo displayInfo,
  ) async {
    final previousMode = state.mode;
    if (previousMode == request.mode) return;

    // Save windowed state before switching away, so the user can return to it.
    final Size? previousWindowedSize;
    final Offset? previousWindowedPosition;
    if (previousMode == WindowMode.windowed) {
      previousWindowedSize = state.savedWindowedSize;
      previousWindowedPosition = state.savedWindowedPosition;
      state.savedWindowedSize = state.size;
      state.savedWindowedPosition = state.position;
    } else {
      previousWindowedSize = null;
      previousWindowedPosition = null;
    }

    final targetIndex = request.targetDisplay ?? state.displayIndex;
    final display = displayInfo.getDisplay(targetIndex) ?? displayInfo.primary;

    final applied = await _applyMode(world, request.mode, display, state);
    if (!applied) {
      // Roll back the saved-windowed bookkeeping on failure.
      if (previousMode == WindowMode.windowed) {
        state.savedWindowedSize = previousWindowedSize;
        state.savedWindowedPosition = previousWindowedPosition;
      }
      return;
    }

    world.eventWriter<WindowModeChanged>().send(WindowModeChanged(
          previousMode: previousMode,
          newMode: request.mode,
        ));
  }

  /// Apply [mode] to the window. Returns `true` on success, `false` if any
  /// native call failed (in which case `state` is left untouched and a
  /// `WindowOperationFailed` event has already been emitted).
  Future<bool> _applyMode(
    World world,
    WindowMode mode,
    Display display,
    WindowState state,
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
        final ok = await _tryNative(
              world,
              'setMode',
              () async {
                await windowManager.setFullScreen(false);
                await windowManager.setAsFrameless();
                await windowManager.setHasShadow(false);
                await windowManager.setBounds(borderlessBounds);
              },
              attemptedMode: mode,
            );
        if (!ok) return false;
        state.mode = WindowMode.borderless;
        state.size = display.size;
        state.position = displayOrigin;

      case WindowMode.windowed:
        final size = state.savedWindowedSize ?? const Size(1280, 720);
        final position =
            state.savedWindowedPosition ?? _centerOnDisplay(size, display);
        final ok = await _tryNative(
              world,
              'setMode',
              () async {
                await windowManager.setFullScreen(false);
                await windowManager.setTitleBarStyle(TitleBarStyle.normal);
                await windowManager.setAlwaysOnTop(false);
                await windowManager.setBounds(Rect.fromLTWH(
                  position.dx,
                  position.dy,
                  size.width,
                  size.height,
                ));
              },
              attemptedMode: mode,
            );
        if (!ok) return false;
        state.mode = WindowMode.windowed;
        state.size = size;
        state.position = position;
    }

    state.displayIndex = display.index;
    return true;
  }

  Future<void> _handleSizeChange(
    World world,
    SetWindowSizeRequest request,
    WindowState state,
  ) async {
    if (state.mode != WindowMode.windowed) return;

    final previousSize = state.size;
    if (previousSize == request.size) return;

    if (!await _tryNative(
      world,
      'resize',
      () => windowManager.setSize(request.size),
    )) {
      return;
    }

    state.size = request.size;
    state.savedWindowedSize = request.size;

    world.eventWriter<WindowResized>().send(WindowResized(
          previousSize: previousSize,
          newSize: request.size,
        ));
  }

  Future<void> _handlePositionChange(
    World world,
    SetWindowPositionRequest request,
    WindowState state,
  ) async {
    if (state.mode != WindowMode.windowed) return;

    final previousPosition = state.position;
    if (previousPosition == request.position) return;

    if (!await _tryNative(
      world,
      'reposition',
      () => windowManager.setPosition(request.position),
    )) {
      return;
    }

    state.position = request.position;
    state.savedWindowedPosition = request.position;

    world.eventWriter<WindowMoved>().send(WindowMoved(
          previousPosition: previousPosition,
          newPosition: request.position,
        ));
  }

  /// Run [action]; on any exception, emit a [WindowOperationFailed] event
  /// tagged with [operation] and swallow the error so the game loop stays
  /// alive. Returns `true` if the action completed without throwing.
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

  /// Centre a window of [windowSize] on [display]. Exposed as static for
  /// unit testing.
  static Offset _centerOnDisplay(Size windowSize, Display display) =>
      centerOnDisplay(windowSize, display.bounds);

  /// Geometry-only version of [_centerOnDisplay] that doesn't require a
  /// native `Display`. Pure function, for tests.
  static Offset centerOnDisplay(Size windowSize, Rect displayBounds) => Offset(
        displayBounds.left + (displayBounds.width - windowSize.width) / 2,
        displayBounds.top + (displayBounds.height - windowSize.height) / 2,
      );
}
