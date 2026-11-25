import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:window_manager/window_manager.dart';

import '../events/window_events.dart';
import '../resources/window_state.dart';
import 'window_event_system.dart';

/// Window changes reported by the operating system (the user focusing,
/// resizing, moving, minimizing or maximizing the window), queued until
/// [WindowOsEventSystem] applies them on the next frame.
///
/// [WindowPlugin] inserts this resource and [WindowInitSystem] connects it
/// to `window_manager` once the window is initialized. The callbacks arrive
/// outside the frame loop, so nothing here is awaited inside a tick. Tests
/// and custom platform layers can feed it directly.
class WindowOsEvents {
  bool? _focused;
  Size? _size;
  Offset? _position;
  bool? _minimized;
  bool? _maximized;

  /// The window gained ([focused] true) or lost keyboard focus.
  void focusChanged(bool focused) => _focused = focused;

  /// The window's size is now [size] (logical pixels).
  void resized(Size size) => _size = size;

  /// The window's top-left corner is now at [position] (screen coordinates).
  void moved(Offset position) => _position = position;

  /// The window was minimized ([minimized] true) or restored.
  void minimizedChanged(bool minimized) => _minimized = minimized;

  /// The window was maximized ([maximized] true) or unmaximized.
  void maximizedChanged(bool maximized) => _maximized = maximized;

  /// Whether anything is waiting to be applied.
  bool get hasPending =>
      _focused != null ||
      _size != null ||
      _position != null ||
      _minimized != null ||
      _maximized != null;

  _PendingOsEvents _take() {
    final pending = _PendingOsEvents(
      _focused,
      _size,
      _position,
      _minimized,
      _maximized,
    );
    _focused = null;
    _size = null;
    _position = null;
    _minimized = null;
    _maximized = null;
    return pending;
  }

  _WindowManagerBridge? _bridge;

  /// Starts forwarding `window_manager` callbacks into this queue. Called by
  /// [WindowInitSystem] after the window is initialized; calling it again
  /// does nothing.
  void connect() {
    if (_bridge != null) return;
    final bridge = _WindowManagerBridge(this);
    windowManager.addListener(bridge);
    _bridge = bridge;
  }

  /// Stops forwarding `window_manager` callbacks.
  void disconnect() {
    final bridge = _bridge;
    if (bridge == null) return;
    windowManager.removeListener(bridge);
    _bridge = null;
  }
}

class _PendingOsEvents {
  final bool? focused;
  final Size? size;
  final Offset? position;
  final bool? minimized;
  final bool? maximized;
  _PendingOsEvents(
    this.focused,
    this.size,
    this.position,
    this.minimized,
    this.maximized,
  );
}

/// Translates `window_manager` callbacks into [WindowOsEvents] calls.
/// Resize and move callbacks carry no data, so the bounds are fetched here,
/// outside the frame loop.
class _WindowManagerBridge with WindowListener {
  final WindowOsEvents events;
  _WindowManagerBridge(this.events);

  @override
  void onWindowFocus() => events.focusChanged(true);

  @override
  void onWindowBlur() => events.focusChanged(false);

  @override
  void onWindowMinimize() => events.minimizedChanged(true);

  @override
  void onWindowRestore() => events.minimizedChanged(false);

  @override
  void onWindowMaximize() => events.maximizedChanged(true);

  @override
  void onWindowUnmaximize() => events.maximizedChanged(false);

  @override
  void onWindowResize() => _refreshBounds();

  @override
  void onWindowMove() => _refreshBounds();

  Future<void> _refreshBounds() async {
    try {
      final bounds = await windowManager.getBounds();
      events
        ..resized(bounds.size)
        ..moved(bounds.topLeft);
    } catch (_) {
      // The window may be closing; the next callback will try again.
    }
  }
}

/// Applies the OS window changes queued in [WindowOsEvents] to
/// [WindowState] and sends [WindowFocusChanged], [WindowResized] and
/// [WindowMoved].
///
/// A change that matches the current [WindowState] (for example the OS
/// echo of a resize [WindowEventSystem] already applied) sends nothing, so
/// a programmatic change produces one event, not two.
///
/// Runs in the [FirstSets.platform] phase of `Schedules.first`, after
/// [WindowEventSystem]. Synchronous: it only drains the queue.
class WindowOsEventSystem implements System {
  /// The `SystemMeta.name` of [WindowOsEventSystem], for `before:` /
  /// `after:`.
  static const String systemName = 'WindowOsEventSystem';

  @override
  SystemMeta get meta => const SystemMeta(
    name: systemName,
    sets: [FirstSets.platform],
    after: [WindowEventSystem.systemName],
    resourceReads: {WindowOsEvents},
    resourceWrites: {WindowState},
    eventWrites: {WindowFocusChanged, WindowResized, WindowMoved},
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => runCondition?.call(world) ?? true;

  @override
  void run(World world) {
    final os = world.getResource<WindowOsEvents>();
    final state = world.getResource<WindowState>();
    if (os == null || state == null || !os.hasPending) return;
    final pending = os._take();

    final focused = pending.focused;
    if (focused != null && focused != state.isFocused) {
      state.isFocused = focused;
      world.eventWriter<WindowFocusChanged>().send(
        WindowFocusChanged(isFocused: focused),
      );
    }

    final size = pending.size;
    if (size != null && size != state.size) {
      final previous = state.size;
      state.size = size;
      world.eventWriter<WindowResized>().send(
        WindowResized(previousSize: previous, newSize: size),
      );
    }

    final position = pending.position;
    if (position != null && position != state.position) {
      final previous = state.position;
      state.position = position;
      world.eventWriter<WindowMoved>().send(
        WindowMoved(previousPosition: previous, newPosition: position),
      );
    }

    if (pending.minimized case final minimized?) {
      state.isMinimized = minimized;
    }
    if (pending.maximized case final maximized?) {
      state.isMaximized = maximized;
    }
  }
}
