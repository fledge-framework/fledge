import 'package:flutter/services.dart';

import 'action.dart';

/// Source of an input binding (which device and input).
sealed class BindingSource {
  const BindingSource();
}

/// Keyboard key binding.
class KeyboardBinding extends BindingSource {
  /// The logical key to bind.
  final LogicalKeyboardKey key;

  const KeyboardBinding(this.key);

  @override
  bool operator ==(Object other) =>
      other is KeyboardBinding && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'KeyboardBinding(${key.keyLabel})';
}

/// Mouse button binding.
class MouseButtonBinding extends BindingSource {
  /// The mouse button (0 = left, 1 = middle, 2 = right, etc.).
  final int button;

  const MouseButtonBinding(this.button);

  static const left = MouseButtonBinding(0);
  static const middle = MouseButtonBinding(1);
  static const right = MouseButtonBinding(2);

  @override
  bool operator ==(Object other) =>
      other is MouseButtonBinding && other.button == button;

  @override
  int get hashCode => button.hashCode;

  @override
  String toString() => 'MouseButtonBinding($button)';
}

/// Mouse axes available.
enum MouseAxis {
  /// Mouse X position on screen.
  positionX,

  /// Mouse Y position on screen.
  positionY,

  /// Mouse movement delta X (for FPS controls).
  deltaX,

  /// Mouse movement delta Y.
  deltaY,

  /// Scroll wheel vertical.
  scrollY,

  /// Scroll wheel horizontal.
  scrollX,
}

/// Mouse axis binding.
class MouseAxisBinding extends BindingSource {
  final MouseAxis axis;

  const MouseAxisBinding(this.axis);

  @override
  bool operator ==(Object other) =>
      other is MouseAxisBinding && other.axis == axis;

  @override
  int get hashCode => axis.hashCode;

  @override
  String toString() => 'MouseAxisBinding($axis)';
}

/// Gamepad button binding.
class GamepadButtonBinding extends BindingSource {
  /// Button key string from the gamepads package.
  final String buttonKey;

  /// Optional: specific gamepad ID. If null, uses any gamepad.
  final String? gamepadId;

  const GamepadButtonBinding(this.buttonKey, {this.gamepadId});

  // Common button constants
  static const a = GamepadButtonBinding('a');
  static const b = GamepadButtonBinding('b');
  static const x = GamepadButtonBinding('x');
  static const y = GamepadButtonBinding('y');
  static const leftBumper = GamepadButtonBinding('left_bumper');
  static const rightBumper = GamepadButtonBinding('right_bumper');
  static const leftTrigger = GamepadButtonBinding('left_trigger');
  static const rightTrigger = GamepadButtonBinding('right_trigger');
  static const dpadUp = GamepadButtonBinding('dpad_up');
  static const dpadDown = GamepadButtonBinding('dpad_down');
  static const dpadLeft = GamepadButtonBinding('dpad_left');
  static const dpadRight = GamepadButtonBinding('dpad_right');
  static const start = GamepadButtonBinding('start');
  static const back = GamepadButtonBinding('back');
  static const leftStickButton = GamepadButtonBinding('left_stick');
  static const rightStickButton = GamepadButtonBinding('right_stick');

  @override
  bool operator ==(Object other) =>
      other is GamepadButtonBinding &&
      other.buttonKey == buttonKey &&
      other.gamepadId == gamepadId;

  @override
  int get hashCode => Object.hash(buttonKey, gamepadId);

  @override
  String toString() => 'GamepadButtonBinding($buttonKey)';
}

/// Gamepad axis binding.
class GamepadAxisBinding extends BindingSource {
  /// Axis key from the gamepads package.
  final String axisKey;

  /// Optional gamepad ID.
  final String? gamepadId;

  /// Whether to invert the axis value.
  final bool inverted;

  const GamepadAxisBinding(
    this.axisKey, {
    this.gamepadId,
    this.inverted = false,
  });

  static const leftStickX = GamepadAxisBinding('left_stick_x');
  static const leftStickY = GamepadAxisBinding('left_stick_y');
  static const rightStickX = GamepadAxisBinding('right_stick_x');
  static const rightStickY = GamepadAxisBinding('right_stick_y');
  static const leftTriggerAxis = GamepadAxisBinding('left_trigger');
  static const rightTriggerAxis = GamepadAxisBinding('right_trigger');

  @override
  bool operator ==(Object other) =>
      other is GamepadAxisBinding &&
      other.axisKey == axisKey &&
      other.gamepadId == gamepadId &&
      other.inverted == inverted;

  @override
  int get hashCode => Object.hash(axisKey, gamepadId, inverted);

  @override
  String toString() => 'GamepadAxisBinding($axisKey)';
}

/// A complete binding from a source to an action with configuration.
class InputBinding {
  /// The action this binding contributes to.
  final ActionId action;

  /// The input source.
  final BindingSource source;

  /// For button bindings used as axes, the value when pressed.
  final double buttonAxisValue;

  /// For axis bindings, deadzone threshold.
  final double deadzone;

  /// Multiplier applied to the input value.
  final double scale;

  const InputBinding({
    required this.action,
    required this.source,
    this.buttonAxisValue = 1.0,
    this.deadzone = 0.1,
    this.scale = 1.0,
  });

  @override
  String toString() => 'InputBinding($action <- $source)';
}

/// Composite binding that combines multiple sources into a Vector2.
///
/// Used for WASD-style movement where 4 buttons map to one 2D action.
class CompositeVector2Binding {
  final ActionId action;
  final BindingSource up;
  final BindingSource down;
  final BindingSource left;
  final BindingSource right;

  const CompositeVector2Binding({
    required this.action,
    required this.up,
    required this.down,
    required this.left,
    required this.right,
  });

  @override
  String toString() => 'CompositeVector2Binding($action)';
}
