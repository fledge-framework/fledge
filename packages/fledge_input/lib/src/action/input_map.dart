import 'package:flutter/services.dart';

import 'action.dart';
import 'input_binding.dart';

/// Configuration for how actions are bound to inputs.
///
/// An InputMap defines which physical inputs trigger which logical actions.
/// Multiple bindings can map to the same action (e.g., both Space and gamepad A
/// can trigger 'jump').
class InputMap {
  /// All single bindings.
  final List<InputBinding> bindings;

  /// Composite vector2 bindings (WASD-style).
  final List<CompositeVector2Binding> compositeBindings;

  /// Action metadata (type hints).
  final Map<ActionId, ActionType> actionTypes;

  /// Deadzone settings per action.
  final Map<ActionId, double> deadzones;

  const InputMap({
    this.bindings = const [],
    this.compositeBindings = const [],
    this.actionTypes = const {},
    this.deadzones = const {},
  });

  /// Builder for fluent API.
  static InputMapBuilder builder() => InputMapBuilder();

  /// Get all action IDs defined in this map.
  Set<ActionId> get actions => actionTypes.keys.toSet();
}

/// Fluent builder for InputMap.
class InputMapBuilder {
  final List<InputBinding> _bindings = [];
  final List<CompositeVector2Binding> _compositeBindings = [];
  final Map<ActionId, ActionType> _actionTypes = {};
  final Map<ActionId, double> _deadzones = {};

  /// Bind a keyboard key to a button action.
  InputMapBuilder bindKey(LogicalKeyboardKey key, ActionId action) {
    _bindings.add(InputBinding(
      action: action,
      source: KeyboardBinding(key),
    ));
    _actionTypes[action] ??= ActionType.button;
    return this;
  }

  /// Bind a keyboard key to an axis action (e.g., D for +X, A for -X).
  InputMapBuilder bindKeyToAxis(
    LogicalKeyboardKey key,
    ActionId action, {
    double value = 1.0,
  }) {
    _bindings.add(InputBinding(
      action: action,
      source: KeyboardBinding(key),
      buttonAxisValue: value,
    ));
    _actionTypes[action] ??= ActionType.axis;
    return this;
  }

  /// Bind WASD keys to a Vector2 action.
  InputMapBuilder bindWasd(ActionId action) {
    _compositeBindings.add(CompositeVector2Binding(
      action: action,
      up: KeyboardBinding(LogicalKeyboardKey.keyW),
      down: KeyboardBinding(LogicalKeyboardKey.keyS),
      left: KeyboardBinding(LogicalKeyboardKey.keyA),
      right: KeyboardBinding(LogicalKeyboardKey.keyD),
    ));
    _actionTypes[action] = ActionType.vector2;
    return this;
  }

  /// Bind arrow keys to a Vector2 action.
  InputMapBuilder bindArrows(ActionId action) {
    _compositeBindings.add(CompositeVector2Binding(
      action: action,
      up: KeyboardBinding(LogicalKeyboardKey.arrowUp),
      down: KeyboardBinding(LogicalKeyboardKey.arrowDown),
      left: KeyboardBinding(LogicalKeyboardKey.arrowLeft),
      right: KeyboardBinding(LogicalKeyboardKey.arrowRight),
    ));
    _actionTypes[action] = ActionType.vector2;
    return this;
  }

  /// Bind a mouse button to an action.
  InputMapBuilder bindMouseButton(int button, ActionId action) {
    _bindings.add(InputBinding(
      action: action,
      source: MouseButtonBinding(button),
    ));
    _actionTypes[action] ??= ActionType.button;
    return this;
  }

  /// Bind a mouse axis to an action.
  InputMapBuilder bindMouseAxis(MouseAxis axis, ActionId action,
      {double scale = 1.0}) {
    _bindings.add(InputBinding(
      action: action,
      source: MouseAxisBinding(axis),
      scale: scale,
    ));
    _actionTypes[action] ??= ActionType.axis;
    return this;
  }

  /// Bind a gamepad button to an action.
  InputMapBuilder bindGamepadButton(String buttonKey, ActionId action,
      {String? gamepadId}) {
    _bindings.add(InputBinding(
      action: action,
      source: GamepadButtonBinding(buttonKey, gamepadId: gamepadId),
    ));
    _actionTypes[action] ??= ActionType.button;
    return this;
  }

  /// Bind a gamepad axis to an action.
  InputMapBuilder bindGamepadAxis(String axisKey, ActionId action,
      {String? gamepadId, double deadzone = 0.1, bool inverted = false}) {
    _bindings.add(InputBinding(
      action: action,
      source:
          GamepadAxisBinding(axisKey, gamepadId: gamepadId, inverted: inverted),
      deadzone: deadzone,
    ));
    _actionTypes[action] ??= ActionType.axis;
    return this;
  }

  /// Bind left analog stick to a Vector2 action.
  InputMapBuilder bindLeftStick(ActionId action,
      {double deadzone = 0.1, String? gamepadId}) {
    _bindings.add(InputBinding(
      action: action,
      source: GamepadAxisBinding('left_stick_x', gamepadId: gamepadId),
      deadzone: deadzone,
    ));
    _bindings.add(InputBinding(
      action: action,
      source: GamepadAxisBinding('left_stick_y', gamepadId: gamepadId),
      deadzone: deadzone,
    ));
    _actionTypes[action] = ActionType.vector2;
    _deadzones[action] = deadzone;
    return this;
  }

  /// Bind right analog stick to a Vector2 action.
  InputMapBuilder bindRightStick(ActionId action,
      {double deadzone = 0.1, String? gamepadId}) {
    _bindings.add(InputBinding(
      action: action,
      source: GamepadAxisBinding('right_stick_x', gamepadId: gamepadId),
      deadzone: deadzone,
    ));
    _bindings.add(InputBinding(
      action: action,
      source: GamepadAxisBinding('right_stick_y', gamepadId: gamepadId),
      deadzone: deadzone,
    ));
    _actionTypes[action] = ActionType.vector2;
    _deadzones[action] = deadzone;
    return this;
  }

  /// Bind D-pad to a Vector2 action.
  InputMapBuilder bindDpad(ActionId action, {String? gamepadId}) {
    _compositeBindings.add(CompositeVector2Binding(
      action: action,
      up: GamepadButtonBinding('dpad_up', gamepadId: gamepadId),
      down: GamepadButtonBinding('dpad_down', gamepadId: gamepadId),
      left: GamepadButtonBinding('dpad_left', gamepadId: gamepadId),
      right: GamepadButtonBinding('dpad_right', gamepadId: gamepadId),
    ));
    _actionTypes[action] = ActionType.vector2;
    return this;
  }

  /// Set deadzone for an action.
  InputMapBuilder withDeadzone(ActionId action, double deadzone) {
    _deadzones[action] = deadzone;
    return this;
  }

  /// Explicitly set the action type.
  InputMapBuilder withActionType(ActionId action, ActionType type) {
    _actionTypes[action] = type;
    return this;
  }

  /// Build the InputMap.
  InputMap build() => InputMap(
        bindings: List.unmodifiable(_bindings),
        compositeBindings: List.unmodifiable(_compositeBindings),
        actionTypes: Map.unmodifiable(_actionTypes),
        deadzones: Map.unmodifiable(_deadzones),
      );
}
