import '../action/action.dart';

/// State of a single button.
class ButtonInputState {
  /// Whether the button is currently pressed.
  bool pressed = false;

  /// Whether the button was pressed in the previous frame.
  bool previouslyPressed = false;

  /// Update for a new frame.
  void beginFrame() {
    previouslyPressed = pressed;
  }

  /// Whether just pressed this frame.
  bool get justPressed => pressed && !previouslyPressed;

  /// Whether just released this frame.
  bool get justReleased => !pressed && previouslyPressed;

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
