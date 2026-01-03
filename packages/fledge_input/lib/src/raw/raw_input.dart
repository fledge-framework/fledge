import '../action/action.dart';

/// State of a single button.
///
/// Tracks button state across frames with proper handling of asynchronous
/// input events. Flutter key events can arrive at any point between frames,
/// so we explicitly track transitions rather than just comparing states.
class ButtonInputState {
  /// Whether the button is currently pressed.
  bool pressed = false;

  /// Whether the button was pressed in the previous frame.
  bool previouslyPressed = false;

  /// Whether the button was pressed during this frame (set by press, cleared by beginFrame).
  bool _pressedThisFrame = false;

  /// Whether the button was released during this frame (set by release, cleared by beginFrame).
  bool _releasedThisFrame = false;

  /// Called when the button is pressed.
  void press() {
    if (!pressed) {
      pressed = true;
      _pressedThisFrame = true;
    }
  }

  /// Called when the button is released.
  void release() {
    if (pressed) {
      pressed = false;
      _releasedThisFrame = true;
    }
  }

  /// Update for a new frame. Call at the START of each frame.
  void beginFrame() {
    // The previous frame's state is what we had at the end of last frame
    previouslyPressed = pressed;
    // Clear the transition flags for the new frame
    _pressedThisFrame = false;
    _releasedThisFrame = false;
  }

  /// Whether just pressed this frame.
  bool get justPressed => _pressedThisFrame || (pressed && !previouslyPressed);

  /// Whether just released this frame.
  bool get justReleased => _releasedThisFrame || (!pressed && previouslyPressed);

  /// Get the ButtonPhase.
  ButtonPhase get phase {
    if (justPressed) return ButtonPhase.justPressed;
    if (justReleased) return ButtonPhase.justReleased;
    if (pressed) return ButtonPhase.held;
    return ButtonPhase.up;
  }

  @override
  String toString() => 'ButtonInputState(pressed: $pressed, phase: $phase)';
}
