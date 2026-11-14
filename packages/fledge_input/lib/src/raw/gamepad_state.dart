import 'package:gamepads/gamepads.dart';

import '../action/action.dart';
import 'raw_input.dart';

/// The standard key of [button]: the snake_case of its name (`a`,
/// `left_bumper`, `dpad_up`, `left_stick`), as `GamepadButtonBinding` uses.
String standardButtonKey(GamepadButton button) => _snake(button.name);

/// The standard key of [axis] (`left_stick_x`, `right_trigger`), as
/// `GamepadAxisBinding` uses.
String standardAxisKey(GamepadAxis axis) => _snake(axis.name);

String _snake(String camel) =>
    camel.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

/// State for a single gamepad.
class SingleGamepadState {
  /// The gamepad ID from the gamepads package.
  final String id;

  /// Human-readable name.
  final String name;

  /// Button states keyed by button ID string.
  final Map<String, ButtonInputState> buttons = {};

  /// Axis values keyed by axis ID string.
  final Map<String, double> axes = {};

  /// Whether the gamepad is connected.
  bool connected = true;

  SingleGamepadState(this.id, this.name);

  /// Get or create button state.
  ButtonInputState _getButton(String key) {
    return buttons.putIfAbsent(key, () => ButtonInputState());
  }

  /// Handle a button event.
  void setButtonPressed(String key, bool pressed) {
    final button = _getButton(key);
    if (pressed) {
      button.press();
    } else {
      button.release();
    }
  }

  /// Handle an axis event.
  void setAxisValue(String key, double value) {
    axes[key] = value;
  }

  /// Check if a button is pressed.
  bool isButtonPressed(String key) {
    return buttons[key]?.pressed ?? false;
  }

  /// Get button phase.
  ButtonPhase getButtonPhase(String key) {
    return buttons[key]?.phase ?? ButtonPhase.up;
  }

  /// Get an axis value.
  double getAxis(String key) {
    return axes[key] ?? 0.0;
  }

  /// Called at the start of each frame.
  void beginFrame() {
    for (final state in buttons.values) {
      state.beginFrame();
    }
  }

  /// Called at the end of each frame to clear transition flags.
  void endFrame() {
    for (final state in buttons.values) {
      state.endFrame();
    }
  }
}

/// Tracks the state of all connected gamepads.
class GamepadState {
  /// All connected gamepads by ID.
  final Map<String, SingleGamepadState> gamepads = {};

  /// Get or create a gamepad state.
  SingleGamepadState getOrCreate(String id, String name) {
    return gamepads.putIfAbsent(id, () => SingleGamepadState(id, name));
  }

  /// Get a gamepad by ID.
  SingleGamepadState? get(String id) => gamepads[id];

  /// Mark a gamepad as disconnected.
  void disconnect(String id) {
    final gamepad = gamepads[id];
    if (gamepad != null) {
      gamepad.connected = false;
    }
  }

  /// Remove a disconnected gamepad.
  void remove(String id) {
    gamepads.remove(id);
  }

  /// Get the first connected gamepad, or null.
  SingleGamepadState? get primary {
    for (final gamepad in gamepads.values) {
      if (gamepad.connected) return gamepad;
    }
    return null;
  }

  /// Get all connected gamepads.
  Iterable<SingleGamepadState> get connected =>
      gamepads.values.where((g) => g.connected);

  /// Check if a button is pressed on any gamepad.
  bool isButtonPressed(String key, {String? gamepadId}) {
    if (gamepadId != null) {
      return gamepads[gamepadId]?.isButtonPressed(key) ?? false;
    }
    return gamepads.values.any((g) => g.connected && g.isButtonPressed(key));
  }

  /// Get button phase from any gamepad.
  ButtonPhase getButtonPhase(String key, {String? gamepadId}) {
    if (gamepadId != null) {
      return gamepads[gamepadId]?.getButtonPhase(key) ?? ButtonPhase.up;
    }
    // Return the most "active" phase from any gamepad
    for (final gamepad in gamepads.values) {
      if (!gamepad.connected) continue;
      final phase = gamepad.getButtonPhase(key);
      if (phase != ButtonPhase.up) return phase;
    }
    return ButtonPhase.up;
  }

  /// Get an axis value from any gamepad.
  double getAxis(String key, {String? gamepadId}) {
    if (gamepadId != null) {
      return gamepads[gamepadId]?.getAxis(key) ?? 0.0;
    }
    // Return the largest absolute value from any gamepad
    double result = 0.0;
    for (final gamepad in gamepads.values) {
      if (!gamepad.connected) continue;
      final value = gamepad.getAxis(key);
      if (value.abs() > result.abs()) {
        result = value;
      }
    }
    return result;
  }

  /// Records a raw gamepad [event]: under its raw platform key, and, where
  /// [normalizer] recognises it, under the standard key too
  /// ([standardButtonKey], [standardAxisKey]), so bindings to standard names
  /// work on every platform and controller. Standard stick Y axes are
  /// flipped to +1 down, matching screen coordinates.
  void applyEvent(GamepadEvent event, GamepadNormalizer? normalizer) {
    final gamepad = getOrCreate(event.gamepadId, event.gamepadId);
    if (event.type == KeyType.button) {
      gamepad.setButtonPressed(event.key, event.value > 0.5);
    } else {
      gamepad.setAxisValue(event.key, event.value);
    }
    if (normalizer == null) return;
    for (final normalized in normalizer.normalize(event)) {
      final button = normalized.button;
      final axis = normalized.axis;
      if (button != null) {
        gamepad.setButtonPressed(
          standardButtonKey(button),
          normalized.value > 0.5,
        );
      } else if (axis != null) {
        final flip =
            axis == GamepadAxis.leftStickY || axis == GamepadAxis.rightStickY;
        gamepad.setAxisValue(
          standardAxisKey(axis),
          flip ? -normalized.value : normalized.value,
        );
      }
    }
  }

  /// Called at the start of each frame.
  void beginFrame() {
    for (final gamepad in gamepads.values) {
      gamepad.beginFrame();
    }
  }

  /// Called at the end of each frame to clear transition flags.
  void endFrame() {
    for (final gamepad in gamepads.values) {
      gamepad.endFrame();
    }
  }

  /// Clear all gamepads.
  void clear() {
    gamepads.clear();
  }
}
