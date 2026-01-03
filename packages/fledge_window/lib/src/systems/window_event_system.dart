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

    // Handle mode change requests
    final modeReader = world.eventReader<SetWindowModeRequest>();
    for (final request in modeReader.read()) {
      await _handleModeChange(world, request, windowState, displayInfo);
    }

    // Handle size requests
    final sizeReader = world.eventReader<SetWindowSizeRequest>();
    for (final request in sizeReader.read()) {
      await _handleSizeChange(world, request, windowState);
    }

    // Handle position requests
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

    // Save windowed state before switching away
    if (previousMode == WindowMode.windowed) {
      state.savedWindowedSize = state.size;
      state.savedWindowedPosition = state.position;
    }

    // Get target display
    final targetIndex = request.targetDisplay ?? state.displayIndex;
    final display = displayInfo.getDisplay(targetIndex) ?? displayInfo.primary;

    await _applyMode(request.mode, display, state);

    // Fire event
    world.eventWriter<WindowModeChanged>().send(WindowModeChanged(
          previousMode: previousMode,
          newMode: request.mode,
        ));
  }

  Future<void> _applyMode(
    WindowMode mode,
    Display display,
    WindowState state,
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
        final displayOrigin = display.isPrimary
            ? Offset.zero
            : display.bounds.topLeft;
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
        // Disable always on top for windowed mode
        await windowManager.setAlwaysOnTop(false);

        // Restore saved size/position or use defaults
        final size = state.savedWindowedSize ?? const Size(1280, 720);
        final position =
            state.savedWindowedPosition ?? _centerOnDisplay(size, display);

        await windowManager.setBounds(Rect.fromLTWH(
          position.dx,
          position.dy,
          size.width,
          size.height,
        ));
        state.mode = WindowMode.windowed;
        state.size = size;
        state.position = position;
    }

    state.displayIndex = display.index;
  }

  Future<void> _handleSizeChange(
    World world,
    SetWindowSizeRequest request,
    WindowState state,
  ) async {
    // Only allow resize in windowed mode
    if (state.mode != WindowMode.windowed) return;

    final previousSize = state.size;
    if (previousSize == request.size) return;

    await windowManager.setSize(request.size);
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
    // Only allow move in windowed mode
    if (state.mode != WindowMode.windowed) return;

    final previousPosition = state.position;
    if (previousPosition == request.position) return;

    await windowManager.setPosition(request.position);
    state.position = request.position;
    state.savedWindowedPosition = request.position;

    world.eventWriter<WindowMoved>().send(WindowMoved(
          previousPosition: previousPosition,
          newPosition: request.position,
        ));
  }

  Offset _centerOnDisplay(Size windowSize, Display display) {
    return Offset(
      display.bounds.left + (display.bounds.width - windowSize.width) / 2,
      display.bounds.top + (display.bounds.height - windowSize.height) / 2,
    );
  }
}
