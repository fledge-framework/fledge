import 'dart:async';

/// A delta event from pointer lock, providing raw mouse movement.
class PointerLockDelta {
  /// Horizontal movement delta.
  final double dx;

  /// Vertical movement delta.
  final double dy;

  const PointerLockDelta(this.dx, this.dy);
}

/// Abstraction for pointer lock implementations.
///
/// Pointer lock captures the mouse cursor and provides raw movement deltas,
/// essential for FPS-style camera controls.
///
/// Since Flutter does not provide a built-in pointer lock API, this delegate
/// allows users to plug in their own implementation (e.g. using the
/// `pointer_lock` package from GitHub).
///
/// ## Example
///
/// ```dart
/// import 'package:pointer_lock/pointer_lock.dart';
///
/// class JsonPointerLockDelegate implements PointerLockDelegate {
///   StreamSubscription<PointerLockMoveEvent>? _subscription;
///   StreamController<PointerLockDelta>? _controller;
///
///   @override
///   Stream<PointerLockDelta> start() {
///     _controller = StreamController<PointerLockDelta>();
///     final stream = pointerLock.createSession(
///       cursor: PointerLockCursor.hidden,
///       unlockOnPointerUp: false,
///     );
///     _subscription = stream.listen((event) {
///       _controller!.add(PointerLockDelta(event.delta.dx, event.delta.dy));
///     });
///     return _controller!.stream;
///   }
///
///   @override
///   void stop() {
///     _subscription?.cancel();
///     _subscription = null;
///     _controller?.close();
///     _controller = null;
///   }
/// }
/// ```
abstract class PointerLockDelegate {
  /// Start a pointer lock session and return a stream of movement deltas.
  ///
  /// Called when [CursorMode.locked] is activated.
  Stream<PointerLockDelta> start();

  /// Stop the current pointer lock session.
  ///
  /// Called when leaving [CursorMode.locked] or on widget disposal.
  void stop();
}
