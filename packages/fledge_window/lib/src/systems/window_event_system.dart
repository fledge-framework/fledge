import 'dart:collection';
import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:window_manager/window_manager.dart';

import '../events/window_events.dart';
import '../resources/display_info.dart';
import '../resources/window_state.dart';
import '../window_mode.dart';
import 'display_sync_system.dart';
import 'window_init_system.dart';

/// System that processes window change requests.
///
/// Handles [SetWindowModeRequest], [SetWindowSizeRequest], and
/// [SetWindowPositionRequest] events and applies the changes.
///
/// The system is synchronous and never awaits `window_manager` inside a
/// tick. A frame with no pending requests costs nothing beyond reading the
/// (empty) request queues. When there is work, the native calls for one
/// request start in the background; on the first frame after they finish,
/// the result is applied: [WindowState] is updated and the success event
/// ([WindowModeChanged], [WindowResized], [WindowMoved]) is sent, and the
/// next queued request starts. Requests are applied in arrival order (per
/// frame: mode, then size, then position requests), one at a time, so each
/// one is planned against the state its predecessors left behind.
///
/// Every native call is guarded: if the OS/backend rejects the operation
/// or the call throws, a [WindowOperationFailed] event is emitted (on the
/// frame the result is applied) and the [WindowState] is left unchanged.
/// Success events fire only after the native call returns cleanly.
///
/// Runs in the [FirstSets.platform] phase of `Schedules.first`, after
/// [WindowInitSystem] and [DisplaySyncSystem], so requests are applied
/// against an initialized window and up-to-date [DisplayInfo].
class WindowEventSystem implements System {
  /// The `SystemMeta.name` of [WindowEventSystem]. Games that order
  /// their own systems relative to this one use it in `before:` /
  /// `after:`.
  static const String systemName = 'WindowEventSystem';

  @override
  SystemMeta get meta => const SystemMeta(
    name: systemName,
    sets: [FirstSets.platform],
    after: [WindowInitSystem.systemName, DisplaySyncSystem.systemName],
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

  /// Requests read from the event queues but not yet started.
  final Queue<Object> _pending = Queue<Object>();

  /// Whether a request's native calls are running in the background.
  bool _inFlight = false;

  /// A finished request, waiting for the next frame to apply it.
  _Outcome? _finished;

  @override
  void run(World world) {
    final windowState = world.getResource<WindowState>();
    final displayInfo = world.getResource<DisplayInfo>();

    if (windowState == null || displayInfo == null) return;

    _pending
      ..addAll(world.eventReader<SetWindowModeRequest>().read())
      ..addAll(world.eventReader<SetWindowSizeRequest>().read())
      ..addAll(world.eventReader<SetWindowPositionRequest>().read());

    final finished = _finished;
    if (finished != null) {
      _finished = null;
      finished.apply(world, windowState);
    }

    if (_inFlight) return;
    while (_pending.isNotEmpty) {
      final op = _plan(world, _pending.removeFirst(), windowState, displayInfo);
      if (op == null) continue;
      _start(op);
      break;
    }
  }

  /// Starts [op]'s native calls without awaiting them. The outcome is
  /// stored and applied by the next [run].
  void _start(_Op op) {
    _inFlight = true;
    Future<void> native;
    try {
      native = op.native();
    } catch (e) {
      native = Future<void>.error(e);
    }
    native.then(
      (_) {
        _finished = _Outcome(op, null);
        _inFlight = false;
      },
      onError: (Object e) {
        _finished = _Outcome(op, e);
        _inFlight = false;
      },
    );
  }

  /// Turns [request] into the native work plus the state change to apply
  /// on success, or `null` if the request is a no-op against [state].
  _Op? _plan(
    World world,
    Object request,
    WindowState state,
    DisplayInfo displayInfo,
  ) {
    return switch (request) {
      SetWindowModeRequest() => _planMode(world, request, state, displayInfo),
      SetWindowSizeRequest() => _planSize(request, state),
      SetWindowPositionRequest() => _planPosition(request, state),
      _ => null,
    };
  }

  _Op? _planMode(
    World world,
    SetWindowModeRequest request,
    WindowState state,
    DisplayInfo displayInfo,
  ) {
    final previousMode = state.mode;
    final mode = request.mode;
    if (previousMode == mode) return null;

    if (!displayInfo.isInitialized) {
      world.eventWriter<WindowOperationFailed>().send(
        WindowOperationFailed(
          operation: 'setMode',
          reason: 'no display information available yet',
          attemptedMode: mode,
        ),
      );
      return null;
    }

    final targetIndex = request.targetDisplay ?? state.displayIndex;
    final display = displayInfo.getDisplay(targetIndex) ?? displayInfo.primary;

    // Remember the windowed bounds when switching away, so the user can
    // return to them. Captured now; written only on success.
    final wasWindowed = previousMode == WindowMode.windowed;
    final leavingSize = state.size;
    final leavingPosition = state.position;

    final Future<void> Function() native;
    final Size newSize;
    final Offset newPosition;
    switch (mode) {
      case WindowMode.fullscreen:
        native = () => windowManager.setFullScreen(true);
        newSize = display.size;
        newPosition = display.bounds.topLeft;

      case WindowMode.borderless:
        final displayOrigin = display.isPrimary
            ? Offset.zero
            : display.bounds.topLeft;
        final borderlessBounds = Rect.fromLTWH(
          displayOrigin.dx,
          displayOrigin.dy,
          display.size.width,
          display.size.height,
        );
        native = () async {
          await windowManager.setFullScreen(false);
          await windowManager.setAsFrameless();
          await windowManager.setHasShadow(false);
          await windowManager.setBounds(borderlessBounds);
        };
        newSize = display.size;
        newPosition = displayOrigin;

      case WindowMode.windowed:
        final size = state.savedWindowedSize ?? const Size(1280, 720);
        final position =
            state.savedWindowedPosition ?? _centerOnDisplay(size, display);
        native = () async {
          await windowManager.setFullScreen(false);
          await windowManager.setTitleBarStyle(TitleBarStyle.normal);
          await windowManager.setAlwaysOnTop(false);
          await windowManager.setBounds(
            Rect.fromLTWH(position.dx, position.dy, size.width, size.height),
          );
        };
        newSize = size;
        newPosition = position;
    }

    return _Op(
      operation: 'setMode',
      attemptedMode: mode,
      native: native,
      onSuccess: (world, state) {
        if (wasWindowed) {
          state.savedWindowedSize = leavingSize;
          state.savedWindowedPosition = leavingPosition;
        }
        state
          ..mode = mode
          ..size = newSize
          ..position = newPosition
          ..displayIndex = display.index;
        world.eventWriter<WindowModeChanged>().send(
          WindowModeChanged(previousMode: previousMode, newMode: mode),
        );
      },
    );
  }

  _Op? _planSize(SetWindowSizeRequest request, WindowState state) {
    if (state.mode != WindowMode.windowed) return null;

    final previousSize = state.size;
    final size = request.size;
    if (previousSize == size) return null;

    return _Op(
      operation: 'resize',
      native: () => windowManager.setSize(size),
      onSuccess: (world, state) {
        state
          ..size = size
          ..savedWindowedSize = size;
        world.eventWriter<WindowResized>().send(
          WindowResized(previousSize: previousSize, newSize: size),
        );
      },
    );
  }

  _Op? _planPosition(SetWindowPositionRequest request, WindowState state) {
    if (state.mode != WindowMode.windowed) return null;

    final previousPosition = state.position;
    final position = request.position;
    if (previousPosition == position) return null;

    return _Op(
      operation: 'reposition',
      native: () => windowManager.setPosition(position),
      onSuccess: (world, state) {
        state
          ..position = position
          ..savedWindowedPosition = position;
        world.eventWriter<WindowMoved>().send(
          WindowMoved(
            previousPosition: previousPosition,
            newPosition: position,
          ),
        );
      },
    );
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

/// One request's native work and the state change it makes on success.
class _Op {
  final String operation;
  final WindowMode? attemptedMode;
  final Future<void> Function() native;
  final void Function(World world, WindowState state) onSuccess;

  _Op({
    required this.operation,
    required this.native,
    required this.onSuccess,
    this.attemptedMode,
  });
}

/// A finished [_Op]: [error] is `null` when the native calls succeeded.
class _Outcome {
  final _Op op;
  final Object? error;

  _Outcome(this.op, this.error);

  void apply(World world, WindowState state) {
    final error = this.error;
    if (error == null) {
      op.onSuccess(world, state);
      return;
    }
    world.eventWriter<WindowOperationFailed>().send(
      WindowOperationFailed(
        operation: op.operation,
        reason: error.toString(),
        attemptedMode: op.attemptedMode,
      ),
    );
  }
}
