import '../systems/input_fixed_latch_system.dart' show InputFixedLatchSystem;
import 'action.dart';

/// Resource containing the resolved action values for the current frame.
///
/// This is the primary resource that game systems read to check input.
///
/// ## Reading buttons from the fixed step
///
/// [justPressed] and [justReleased] describe the current *frame*. A frame can
/// run the fixed-timestep chain zero times (the press would be missed) or
/// several times (it would be seen twice). Systems in the fixed schedules use
/// [fixedJustPressed] and [fixedJustReleased] instead: a press is held until
/// a fixed step has run, then cleared by [InputFixedLatchSystem] in
/// `Schedules.fixedLast`, so exactly one fixed step sees it.
class ActionState {
  final Map<ActionId, ActionValue> _values = {};

  /// Presses and releases waiting for the next fixed step.
  final Map<ActionId, int> _fixedPressed = {};
  final Set<ActionId> _fixedReleased = {};

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

  /// Whether [action] was pressed since the last fixed step: true for exactly
  /// one fixed step per press, whatever the frame rate.
  bool fixedJustPressed(ActionId action) => _fixedPressed.containsKey(action);

  /// How many times [action] was pressed since the last fixed step. Usually
  /// 0 or 1; more when several frames each pressed it before a fixed step
  /// ran, or when one source presses several times a frame (scroll wheel
  /// steps).
  int fixedPressCount(ActionId action) => _fixedPressed[action] ?? 0;

  /// Whether [action] was released since the last fixed step: true for
  /// exactly one fixed step per release.
  bool fixedJustReleased(ActionId action) => _fixedReleased.contains(action);

  /// Forgets the presses and releases the last fixed step has seen (called
  /// by [InputFixedLatchSystem] at the end of each fixed step).
  void clearFixedLatch() {
    _fixedPressed.clear();
    _fixedReleased.clear();
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
    if (value is ButtonValue) {
      if (value.presses > 0) {
        _fixedPressed[action] = (_fixedPressed[action] ?? 0) + value.presses;
      }
      if (value.justReleased) _fixedReleased.add(action);
    }
  }

  /// Clear all values (called at start of resolution). Presses waiting for
  /// the fixed step are kept.
  void clear() {
    _values.clear();
  }

  /// Get all currently set action IDs.
  Iterable<ActionId> get actions => _values.keys;
}
