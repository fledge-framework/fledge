import 'dart:math' as math;

/// Identifier for an action. Can be a string or created from an enum value.
///
/// Actions are logical inputs like 'jump', 'move', 'attack' that can be
/// bound to multiple physical inputs.
class ActionId {
  final String name;

  const ActionId(this.name);

  /// Create from an enum value, using the enum name as the action name.
  factory ActionId.fromEnum(Enum value) => ActionId(value.name);

  @override
  bool operator ==(Object other) => other is ActionId && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'ActionId($name)';
}

/// The type of input an action expects.
enum ActionType {
  /// A digital button: pressed, held, or released.
  button,

  /// A single analog axis: -1.0 to 1.0 (e.g., trigger, single stick axis).
  axis,

  /// A 2D analog input: Vector2 (e.g., full analog stick, WASD as vector).
  vector2,
}

/// The phase of a button action within a frame.
enum ButtonPhase {
  /// Button is not pressed.
  up,

  /// Button was just pressed this frame.
  justPressed,

  /// Button is being held down (was pressed in a previous frame).
  held,

  /// Button was just released this frame.
  justReleased,
}

/// The current value and state of a resolved action.
sealed class ActionValue {
  const ActionValue();
}

/// Value for button-type actions.
class ButtonValue extends ActionValue {
  /// The current phase of the button.
  final ButtonPhase phase;

  const ButtonValue(this.phase);

  /// True if button is currently down (justPressed or held).
  bool get isPressed =>
      phase == ButtonPhase.justPressed || phase == ButtonPhase.held;

  /// True if button was just pressed this frame.
  bool get justPressed => phase == ButtonPhase.justPressed;

  /// True if button was just released this frame.
  bool get justReleased => phase == ButtonPhase.justReleased;

  /// True if button is being held (not just pressed this frame).
  bool get isHeld => phase == ButtonPhase.held;

  @override
  String toString() => 'ButtonValue($phase)';
}

/// Value for axis-type actions.
class AxisValue extends ActionValue {
  /// The axis value from -1.0 to 1.0.
  final double value;

  /// Deadzone threshold that was applied.
  final double deadzone;

  const AxisValue(this.value, {this.deadzone = 0.0});

  /// True if the axis is past the deadzone.
  bool get isActive => value.abs() > deadzone;

  @override
  String toString() => 'AxisValue($value)';
}

/// Value for vector2-type actions.
class Vector2Value extends ActionValue {
  /// X component of the vector.
  final double x;

  /// Y component of the vector.
  final double y;

  const Vector2Value(this.x, this.y);

  /// Magnitude of the vector.
  double get magnitude => math.sqrt(x * x + y * y);

  /// Whether the vector has significant input (past deadzone).
  bool isActive([double deadzone = 0.1]) => magnitude > deadzone;

  /// Normalized direction (unit vector), or zero if magnitude is too small.
  Vector2Value get normalized {
    final mag = magnitude;
    if (mag < 0.0001) return const Vector2Value(0, 0);
    return Vector2Value(x / mag, y / mag);
  }

  @override
  String toString() => 'Vector2Value($x, $y)';
}
