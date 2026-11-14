import 'package:flutter/services.dart';

import 'action.dart';

/// Source of an input binding (which device and input).
///
/// Every source round-trips through JSON ([toJson], [BindingSource.fromJson]),
/// so a game can save the player's rebinds.
sealed class BindingSource {
  const BindingSource();

  /// A JSON-safe description of this source, read back by
  /// [BindingSource.fromJson].
  Map<String, Object?> toJson();

  /// The source [json] describes (from [toJson]), or null if it isn't one,
  /// e.g. a file written by a newer version.
  static BindingSource? fromJson(Map<String, Object?> json) {
    switch (json) {
      case {'type': 'key', 'key': final int id}:
        return KeyboardBinding(
          LogicalKeyboardKey.findKeyByKeyId(id) ?? LogicalKeyboardKey(id),
        );
      case {'type': 'mouse_button', 'button': final int button}:
        return MouseButtonBinding(button);
      case {'type': 'mouse_axis', 'axis': final String name}:
        final axis = MouseAxis.values.asNameMap()[name];
        return axis == null ? null : MouseAxisBinding(axis);
      case {'type': 'scroll', 'direction': final String name}:
        final direction = ScrollDirection.values.asNameMap()[name];
        return direction == null ? null : MouseScrollBinding(direction);
      case {'type': 'gamepad_button', 'button': final String button}:
        return GamepadButtonBinding(
          button,
          gamepadId: json['gamepad'] as String?,
        );
      case {'type': 'gamepad_axis', 'axis': final String axis}:
        return GamepadAxisBinding(
          axis,
          gamepadId: json['gamepad'] as String?,
          inverted: json['inverted'] == true,
        );
    }
    return null;
  }
}

/// Keyboard key binding.
class KeyboardBinding extends BindingSource {
  /// The logical key to bind.
  final LogicalKeyboardKey key;

  const KeyboardBinding(this.key);

  @override
  Map<String, Object?> toJson() => {'type': 'key', 'key': key.keyId};

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
  Map<String, Object?> toJson() => {'type': 'mouse_button', 'button': button};

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
  Map<String, Object?> toJson() => {'type': 'mouse_axis', 'axis': axis.name};

  @override
  bool operator ==(Object other) =>
      other is MouseAxisBinding && other.axis == axis;

  @override
  int get hashCode => axis.hashCode;

  @override
  String toString() => 'MouseAxisBinding($axis)';
}

/// Which way a scroll wheel turns.
enum ScrollDirection {
  /// Wheel away from the user (content scrolls up).
  up,

  /// Wheel towards the user.
  down,

  /// Horizontal scroll left (tilt wheel, trackpad).
  left,

  /// Horizontal scroll right.
  right,
}

/// The scroll wheel as a button: every wheel step in [direction] is one
/// press, and a frame with several steps counts them all
/// ([ButtonValue.presses], [ActionState.fixedPressCount]).
///
/// The phase is never `held`: the action is `justPressed` in a frame that
/// scrolled that way and `up` otherwise.
class MouseScrollBinding extends BindingSource {
  final ScrollDirection direction;

  const MouseScrollBinding(this.direction);

  static const up = MouseScrollBinding(ScrollDirection.up);
  static const down = MouseScrollBinding(ScrollDirection.down);
  static const left = MouseScrollBinding(ScrollDirection.left);
  static const right = MouseScrollBinding(ScrollDirection.right);

  @override
  Map<String, Object?> toJson() => {
    'type': 'scroll',
    'direction': direction.name,
  };

  @override
  bool operator ==(Object other) =>
      other is MouseScrollBinding && other.direction == direction;

  @override
  int get hashCode => direction.hashCode;

  @override
  String toString() => 'MouseScrollBinding(${direction.name})';
}

/// Gamepad button binding.
///
/// [buttonKey] is either a standard button name, the snake_case of the
/// `gamepads` package's `GamepadButton` (`a`, `left_bumper`, `dpad_up`,
/// `left_stick`, `start`, ...; see the constants below), which is the same
/// on every platform and controller, or a raw platform key as the
/// `gamepads` package reports it.
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
  static const home = GamepadButtonBinding('home');
  static const touchpad = GamepadButtonBinding('touchpad');

  @override
  Map<String, Object?> toJson() => {
    'type': 'gamepad_button',
    'button': buttonKey,
    if (gamepadId != null) 'gamepad': gamepadId,
  };

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
///
/// [axisKey] is a standard axis name (`left_stick_x`, `left_stick_y`,
/// `right_stick_x`, `right_stick_y`, `left_trigger`, `right_trigger`) or a
/// raw platform key. Standard sticks run -1 to 1 with +x right and +y
/// **down**, like the screen and the keyboard composites; triggers run 0 to
/// 1.
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
  Map<String, Object?> toJson() => {
    'type': 'gamepad_axis',
    'axis': axisKey,
    if (gamepadId != null) 'gamepad': gamepadId,
    if (inverted) 'inverted': true,
  };

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
