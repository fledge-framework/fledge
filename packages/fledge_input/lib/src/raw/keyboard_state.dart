import 'package:flutter/services.dart';

import '../action/action.dart';
import 'raw_input.dart';

/// Tracks the state of all keyboard keys.
///
/// Updated by [InputWidget] when key events are received.
class KeyboardState {
  final Map<LogicalKeyboardKey, ButtonInputState> _keys = {};

  /// Get or create state for a key.
  ButtonInputState _getKey(LogicalKeyboardKey key) {
    return _keys.putIfAbsent(key, () => ButtonInputState());
  }

  /// Called by InputWidget on key down.
  void keyDown(LogicalKeyboardKey key) {
    _getKey(key).pressed = true;
  }

  /// Called by InputWidget on key up.
  void keyUp(LogicalKeyboardKey key) {
    _getKey(key).pressed = false;
  }

  /// Check if a key is pressed.
  bool isPressed(LogicalKeyboardKey key) {
    return _keys[key]?.pressed ?? false;
  }

  /// Check if a key was just pressed this frame.
  bool justPressed(LogicalKeyboardKey key) {
    return _keys[key]?.justPressed ?? false;
  }

  /// Check if a key was just released this frame.
  bool justReleased(LogicalKeyboardKey key) {
    return _keys[key]?.justReleased ?? false;
  }

  /// Get the button phase for a key.
  ButtonPhase getPhase(LogicalKeyboardKey key) {
    return _keys[key]?.phase ?? ButtonPhase.up;
  }

  /// Called at the start of each frame to update previous state.
  void beginFrame() {
    for (final state in _keys.values) {
      state.beginFrame();
    }
  }

  /// Clear all key states.
  void clear() {
    _keys.clear();
  }
}
