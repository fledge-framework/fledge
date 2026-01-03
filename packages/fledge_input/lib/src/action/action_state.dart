import 'action.dart';

/// Resource containing the resolved action values for the current frame.
///
/// This is the primary resource that game systems read to check input.
class ActionState {
  final Map<ActionId, ActionValue> _values = {};

  /// Get the value of an action.
  ActionValue? get(ActionId action) => _values[action];

  /// Get a button action's value.
  ButtonValue? getButton(ActionId action) {
    final value = _values[action];
    return value is ButtonValue ? value : null;
  }

  /// Get an axis action's value.
  AxisValue? getAxis(ActionId action) {
    final value = _values[action];
    return value is AxisValue ? value : null;
  }

  /// Get a vector2 action's value.
  Vector2Value? getVector2(ActionId action) {
    final value = _values[action];
    return value is Vector2Value ? value : null;
  }

  /// Check if a button action is pressed.
  bool isPressed(ActionId action) {
    return getButton(action)?.isPressed ?? false;
  }

  /// Check if a button action was just pressed this frame.
  bool justPressed(ActionId action) {
    return getButton(action)?.justPressed ?? false;
  }

  /// Check if a button action was just released this frame.
  bool justReleased(ActionId action) {
    return getButton(action)?.justReleased ?? false;
  }

  /// Check if a button action is being held.
  bool isHeld(ActionId action) {
    return getButton(action)?.isHeld ?? false;
  }

  /// Get axis value as a double.
  double axisValue(ActionId action) {
    return getAxis(action)?.value ?? 0.0;
  }

  /// Get vector2 value as a tuple.
  (double, double) vector2Value(ActionId action) {
    final v = getVector2(action);
    return (v?.x ?? 0.0, v?.y ?? 0.0);
  }

  /// Set an action value (called by ActionResolutionSystem).
  void set(ActionId action, ActionValue value) {
    _values[action] = value;
  }

  /// Clear all values (called at start of resolution).
  void clear() {
    _values.clear();
  }

  /// Get all currently set action IDs.
  Iterable<ActionId> get actions => _values.keys;
}
