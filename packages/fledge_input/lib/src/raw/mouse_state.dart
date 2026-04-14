import '../action/action.dart';
import '../action/input_binding.dart';
import 'raw_input.dart';

/// Tracks mouse state including position, buttons, and scroll.
class MouseState {
  /// Current mouse position in local widget coordinates.
  double x = 0;
  double y = 0;

  /// Previous frame's position (for delta calculation).
  double _prevX = 0;
  double _prevY = 0;

  /// Raw delta from pointer lock (accumulated until frame end).
  double _lockedDeltaX = 0;
  double _lockedDeltaY = 0;

  /// Whether we're receiving locked pointer deltas.
  bool _hasLockedDelta = false;

  /// Mouse movement delta this frame.
  ///
  /// When pointer is locked, returns raw delta from pointer lock.
  /// Otherwise, returns position-based delta.
  double get deltaX => _hasLockedDelta ? _lockedDeltaX : (x - _prevX);
  double get deltaY => _hasLockedDelta ? _lockedDeltaY : (y - _prevY);

  /// Scroll delta this frame (reset each frame).
  double scrollX = 0;
  double scrollY = 0;

  /// Button states (index = button number).
  final Map<int, ButtonInputState> _buttons = {};

  /// Get or create button state.
  ButtonInputState _getButton(int button) {
    return _buttons.putIfAbsent(button, () => ButtonInputState());
  }

  /// Called by InputWidget on mouse move.
  void onMove(double newX, double newY) {
    x = newX;
    y = newY;
  }

  /// Called by InputWidget when receiving raw deltas from pointer lock.
  ///
  /// These deltas are accumulated and used instead of position-based
  /// deltas when pointer lock is active.
  void onLockedDelta(double dx, double dy) {
    _lockedDeltaX += dx;
    _lockedDeltaY += dy;
    _hasLockedDelta = true;
  }

  /// Called by InputWidget on mouse button down.
  void buttonDown(int button) {
    _getButton(button).press();
  }

  /// Called by InputWidget on mouse button up.
  void buttonUp(int button) {
    _getButton(button).release();
  }

  /// Called by InputWidget on scroll.
  void onScroll(double dx, double dy) {
    scrollX += dx;
    scrollY += dy;
  }

  /// Check if a button is pressed.
  bool isButtonPressed(int button) {
    return _buttons[button]?.pressed ?? false;
  }

  /// Check if a button was just pressed this frame.
  bool justPressed(int button) {
    return _buttons[button]?.justPressed ?? false;
  }

  /// Check if a button was just released this frame.
  bool justReleased(int button) {
    return _buttons[button]?.justReleased ?? false;
  }

  /// Get the phase for a button.
  ButtonPhase getButtonPhase(int button) {
    return _buttons[button]?.phase ?? ButtonPhase.up;
  }

  /// Get an axis value.
  double getAxis(MouseAxis axis) {
    return switch (axis) {
      MouseAxis.positionX => x,
      MouseAxis.positionY => y,
      MouseAxis.deltaX => deltaX,
      MouseAxis.deltaY => deltaY,
      MouseAxis.scrollX => scrollX,
      MouseAxis.scrollY => scrollY,
    };
  }

  /// Called at the start of each frame.
  void beginFrame() {
    _prevX = x;
    _prevY = y;
    scrollX = 0;
    scrollY = 0;
    // Clear locked deltas from previous frame
    _lockedDeltaX = 0;
    _lockedDeltaY = 0;
    _hasLockedDelta = false;
    for (final state in _buttons.values) {
      state.beginFrame();
    }
  }

  /// Called at the end of each frame to clear transition flags.
  void endFrame() {
    for (final state in _buttons.values) {
      state.endFrame();
    }
  }

  /// Clear all state.
  void clear() {
    x = 0;
    y = 0;
    _prevX = 0;
    _prevY = 0;
    _lockedDeltaX = 0;
    _lockedDeltaY = 0;
    _hasLockedDelta = false;
    scrollX = 0;
    scrollY = 0;
    _buttons.clear();
  }
}
