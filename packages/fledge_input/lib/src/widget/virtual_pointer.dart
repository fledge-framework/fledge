import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A pointer moved by a controller (`GamepadFocusBridge` drives it): where
/// it is, whether it's showing, and its buttons. `VirtualPointer` turns it
/// into real mouse events, so everything that answers a mouse (hover,
/// clicks, drags) answers it too.
class VirtualPointerController extends ChangeNotifier {
  bool _active = false;
  Offset _position = Offset.zero;
  int _buttons = 0;

  /// Every state since the pointer last sent its events, in order, so a
  /// press and release within one frame still clicks (consecutive moves
  /// fold into one).
  final List<({bool active, Offset position, int buttons})> _pending = [];

  /// The states to send, oldest first; taken by `VirtualPointer`.
  List<({bool active, Offset position, int buttons})> takePending() {
    final steps = [..._pending];
    _pending.clear();
    return steps;
  }

  void _record() {
    final step = (active: _active, position: _position, buttons: _buttons);
    final last = _pending.isEmpty ? null : _pending.last;
    if (last != null &&
        last.active == step.active &&
        last.buttons == step.buttons) {
      _pending[_pending.length - 1] = step;
    } else {
      _pending.add(step);
    }
    notifyListeners();
  }

  /// Bounds it's kept inside (the view), set by `VirtualPointer`.
  Rect bounds = Rect.largest;

  /// Whether it's showing (and sending events).
  bool get active => _active;

  /// Where it points, in the view's logical pixels.
  Offset get position => _position;

  /// The mouse buttons held (`kPrimaryButton`, `kSecondaryButton`).
  int get buttons => _buttons;

  /// Shows it [at] a point, or where it last was (the middle of the view
  /// the first time).
  void show({Offset? at}) {
    if (_active) return;
    _active = true;
    _position = _clamp(
      at ?? (_position == Offset.zero ? bounds.center : _position),
    );
    _record();
  }

  /// Hides it (letting go of any button).
  void hide() {
    if (!_active) return;
    _active = false;
    _buttons = 0;
    _record();
  }

  /// Moves it by [delta], kept inside [bounds].
  void moveBy(Offset delta) {
    if (!_active || delta == Offset.zero) return;
    final next = _clamp(_position + delta);
    if (next == _position) return;
    _position = next;
    _record();
  }

  /// Presses [button] (`kPrimaryButton`, `kSecondaryButton`).
  void press(int button) {
    if (!_active || _buttons & button != 0) return;
    _buttons |= button;
    _record();
  }

  /// Lets go of [button].
  void release(int button) {
    if (_buttons & button == 0) return;
    _buttons &= ~button;
    _record();
  }

  Offset _clamp(Offset p) => bounds.isInfinite
      ? p
      : Offset(
          p.dx.clamp(bounds.left, bounds.right - 1),
          p.dy.clamp(bounds.top, bounds.bottom - 1),
        );
}

/// Draws [controller]'s pointer over [child] and sends its moves and
/// presses as mouse events from device [device], through the gesture
/// binding: a `MouseRegion` hovers, a `GestureDetector` taps, a drag drags,
/// exactly as with a mouse. Add [device] to `ActiveInputDevice
/// .gamepadPointerDevices` so it never counts as the mouse.
class VirtualPointer extends StatefulWidget {
  const VirtualPointer({
    super.key,
    required this.controller,
    required this.child,
    this.cursor,
    this.hotSpot = Offset.zero,
  });

  /// The synthetic mouse's device id.
  static const int device = 0x7E57;

  final VirtualPointerController controller;
  final Widget child;

  /// What to draw at the pointer (a plain arrow when null).
  final Widget? cursor;

  /// Where in [cursor] the point is.
  final Offset hotSpot;

  @override
  State<VirtualPointer> createState() => _VirtualPointerState();
}

class _VirtualPointerState extends State<VirtualPointer> {
  bool _added = false;
  Offset _sent = Offset.zero;

  /// The view's id, kept from the last build (the view can't be looked up
  /// while the widget is being torn down).
  int _viewId = 0;
  int _sentButtons = 0;

  /// A pointer id per press, as a real mouse gets one.
  int _pointer = 0x7E570000;
  final Stopwatch _clock = Stopwatch()..start();
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(VirtualPointer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    if (_added) {
      // Don't leave a phantom mouse behind.
      _dispatch(_sent, 0, remove: true);
    }
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
    // Pointer events go out after the frame, never in the middle of one.
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _flush();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  /// Sends every change since the last events, in order.
  void _flush() {
    for (final step in widget.controller.takePending()) {
      if (!step.active) {
        if (_added) _dispatch(_sent, 0, remove: true);
      } else {
        _dispatch(step.position, step.buttons);
      }
    }
  }

  void _dispatch(Offset to, int buttons, {bool remove = false}) {
    final viewId = _viewId;
    final time = _clock.elapsed;
    const kind = PointerDeviceKind.mouse;
    const device = VirtualPointer.device;
    void send(PointerEvent e) => GestureBinding.instance.handlePointerEvent(e);
    if (!_added) {
      send(
        PointerAddedEvent(
          viewId: viewId,
          timeStamp: time,
          kind: kind,
          device: device,
          position: to,
        ),
      );
      _added = true;
      _sent = to;
    }
    // Moves first, with what's held then.
    if (to != _sent) {
      final delta = to - _sent;
      send(
        _sentButtons == 0
            ? PointerHoverEvent(
                viewId: viewId,
                timeStamp: time,
                kind: kind,
                device: device,
                position: to,
                delta: delta,
              )
            : PointerMoveEvent(
                viewId: viewId,
                timeStamp: time,
                pointer: _pointer,
                kind: kind,
                device: device,
                position: to,
                delta: delta,
                buttons: _sentButtons,
              ),
      );
      _sent = to;
    }
    if (buttons != _sentButtons) {
      if (_sentButtons != 0) {
        send(
          PointerUpEvent(
            viewId: viewId,
            timeStamp: time,
            pointer: _pointer,
            kind: kind,
            device: device,
            position: to,
          ),
        );
      }
      if (buttons != 0) {
        _pointer++;
        send(
          PointerDownEvent(
            viewId: viewId,
            timeStamp: time,
            pointer: _pointer,
            kind: kind,
            device: device,
            position: to,
            buttons: buttons,
          ),
        );
      }
      _sentButtons = buttons;
    }
    if (remove) {
      send(
        PointerRemovedEvent(
          viewId: viewId,
          timeStamp: time,
          kind: kind,
          device: device,
          position: to,
        ),
      );
      _added = false;
      _sentButtons = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final view = View.maybeOf(context);
    if (view != null) {
      _viewId = view.viewId;
      final size = view.physicalSize / view.devicePixelRatio;
      c.bounds = Offset.zero & size;
    }
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        if (c.active)
          Positioned(
            left: c.position.dx - widget.hotSpot.dx,
            top: c.position.dy - widget.hotSpot.dy,
            child: IgnorePointer(child: widget.cursor ?? const _Arrow()),
          ),
      ],
    );
  }
}

/// A plain arrow for when no cursor art is given.
class _Arrow extends StatelessWidget {
  const _Arrow();

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(size: Size(12, 18), painter: _ArrowPainter());
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width * 0.35, size.height * 0.72)
      ..lineTo(size.width, size.height * 0.72)
      ..close();
    canvas
      ..drawPath(path, Paint()..color = const Color(0xFFFFFFFF))
      ..drawPath(
        path,
        Paint()
          ..color = const Color(0xFF000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) => false;
}
