import 'dart:math' as math;

import 'package:fledge_ecs/fledge_ecs.dart';

import '../action/action.dart';
import '../action/action_state.dart';
import '../action/input_binding.dart';
import '../context/context_registry.dart';
import '../raw/keyboard_state.dart';
import '../raw/mouse_state.dart';
import '../raw/gamepad_state.dart';
import 'input_polling_system.dart';

/// System that resolves actions from raw input based on the active input map.
///
/// Runs in the [FirstSets.input] phase of `Schedules.first`, after
/// InputPollingSystem. Reads raw input states and the active
/// InputContext to produce ActionState values.
class ActionResolutionSystem implements System {
  /// The `SystemMeta.name` of [ActionResolutionSystem]. Systems that read
  /// `ActionState` in `Schedules.first` should order `after:` it.
  static const String systemName = 'actionResolution';

  @override
  SystemMeta get meta => const SystemMeta(
    name: systemName,
    sets: [FirstSets.input],
    resourceReads: {
      KeyboardState,
      MouseState,
      GamepadState,
      InputContextRegistry,
    },
    resourceWrites: {ActionState},
    // Explicit: we need the previous-frame transition flags cleared
    // and the begin-frame bookkeeping done before we resolve
    // actions from raw state.
    after: [InputPollingSystem.systemName],
  );

  /// Axis sources driving button actions (a trigger as a button) that were
  /// pressed last frame, for their hysteresis.
  final Set<(ActionId, BindingSource)> _axisButtonsDown = {};

  /// Where a stick reads full tilt: past it the value is 1, so a worn
  /// stick that can't quite reach the rim still gets there.
  static const stickOuter = 0.95;

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  void run(World world) {
    final keyboard = world.getResource<KeyboardState>();
    final mouse = world.getResource<MouseState>();
    final gamepad = world.getResource<GamepadState>();
    final contextRegistry = world.getResource<InputContextRegistry>();
    final actionState = world.getResource<ActionState>();

    if (actionState == null || contextRegistry == null) return;

    final inputMap = contextRegistry.activeMap;
    if (inputMap == null) return;

    // Clear previous frame's values
    actionState.clear();

    // Track intermediate values for combining multiple bindings
    final buttonPhases = <ActionId, ButtonPhase>{};
    // Presses beyond the usual one: scroll steps, counted per binding.
    final scrollPresses = <ActionId, int>{};
    // Actions an ordinary button binding pressed this frame.
    final buttonPressed = <ActionId>{};
    final axisValues = <ActionId, double>{};
    final vector2Values = <ActionId, (double, double)>{};

    // Process single bindings
    for (final binding in inputMap.bindings) {
      final source = binding.source;
      final action = binding.action;
      final actionType = inputMap.actionTypes[action] ?? ActionType.button;

      switch (source) {
        case KeyboardBinding():
          _processKeyboardBinding(
            binding,
            source,
            actionType,
            keyboard,
            buttonPhases,
            buttonPressed,
            axisValues,
          );

        case MouseButtonBinding():
          _processMouseButtonBinding(
            binding,
            source,
            actionType,
            mouse,
            buttonPhases,
            buttonPressed,
            axisValues,
          );

        case MouseAxisBinding():
          _processMouseAxisBinding(binding, source, mouse, axisValues);

        case MouseScrollBinding():
          _processMouseScrollBinding(
            binding,
            source,
            actionType,
            mouse,
            buttonPhases,
            scrollPresses,
            axisValues,
          );

        case GamepadButtonBinding():
          _processGamepadButtonBinding(
            binding,
            source,
            actionType,
            gamepad,
            buttonPhases,
            buttonPressed,
            axisValues,
          );

        case GamepadAxisBinding():
          _processGamepadAxisBinding(
            binding,
            source,
            actionType,
            gamepad,
            buttonPhases,
            buttonPressed,
            axisValues,
            vector2Values,
          );

        case GamepadStickBinding():
          _processGamepadStickBinding(
            binding,
            source,
            actionType,
            gamepad,
            vector2Values,
          );
      }
    }

    // Process composite vector2 bindings
    for (final composite in inputMap.compositeBindings) {
      _processCompositeBinding(
        composite,
        keyboard,
        mouse,
        gamepad,
        vector2Values,
      );
    }

    // Finalize action values
    for (final action in inputMap.actionTypes.keys) {
      final type = inputMap.actionTypes[action]!;
      final deadzone = inputMap.deadzones[action] ?? 0.1;

      switch (type) {
        case ActionType.button:
          final phase = buttonPhases[action] ?? ButtonPhase.up;
          final presses =
              (scrollPresses[action] ?? 0) +
              (buttonPressed.contains(action) ? 1 : 0);
          actionState.set(action, ButtonValue(phase, presses: presses));

        case ActionType.axis:
          var value = axisValues[action] ?? 0.0;
          if (value.abs() < deadzone) value = 0.0;
          actionState.set(action, AxisValue(value, deadzone: deadzone));

        case ActionType.vector2:
          var (x, y) = vector2Values[action] ?? (0.0, 0.0);
          // Clamped to length 1: a keyboard diagonal is (0.707, 0.707), and
          // keys and a stick together never go past full tilt.
          if (!inputMap.unclampedVector2.contains(action)) {
            final length = math.sqrt(x * x + y * y);
            if (length > 1) {
              x /= length;
              y /= length;
            }
          }
          actionState.set(action, Vector2Value(x, y));
      }
    }
  }

  void _processKeyboardBinding(
    InputBinding binding,
    KeyboardBinding source,
    ActionType actionType,
    KeyboardState? keyboard,
    Map<ActionId, ButtonPhase> buttonPhases,
    Set<ActionId> buttonPressed,
    Map<ActionId, double> axisValues,
  ) {
    if (keyboard == null) return;

    final phase = keyboard.getPhase(source.key);
    final isPressed =
        phase == ButtonPhase.justPressed || phase == ButtonPhase.held;

    switch (actionType) {
      case ActionType.button:
        // Combine phases: most active wins
        final current = buttonPhases[binding.action];
        if (current == null || _phaseOrder(phase) > _phaseOrder(current)) {
          buttonPhases[binding.action] = phase;
        }
        if (phase == ButtonPhase.justPressed) buttonPressed.add(binding.action);

      case ActionType.axis:
        if (isPressed) {
          final current = axisValues[binding.action] ?? 0.0;
          axisValues[binding.action] =
              current + binding.buttonAxisValue * binding.scale;
        }

      case ActionType.vector2:
        // Handled by composite bindings
        break;
    }
  }

  void _processMouseButtonBinding(
    InputBinding binding,
    MouseButtonBinding source,
    ActionType actionType,
    MouseState? mouse,
    Map<ActionId, ButtonPhase> buttonPhases,
    Set<ActionId> buttonPressed,
    Map<ActionId, double> axisValues,
  ) {
    if (mouse == null) return;

    final phase = mouse.getButtonPhase(source.button);
    final isPressed =
        phase == ButtonPhase.justPressed || phase == ButtonPhase.held;

    switch (actionType) {
      case ActionType.button:
        final current = buttonPhases[binding.action];
        if (current == null || _phaseOrder(phase) > _phaseOrder(current)) {
          buttonPhases[binding.action] = phase;
        }
        if (phase == ButtonPhase.justPressed) buttonPressed.add(binding.action);

      case ActionType.axis:
        if (isPressed) {
          final current = axisValues[binding.action] ?? 0.0;
          axisValues[binding.action] =
              current + binding.buttonAxisValue * binding.scale;
        }

      default:
        break;
    }
  }

  void _processMouseAxisBinding(
    InputBinding binding,
    MouseAxisBinding source,
    MouseState? mouse,
    Map<ActionId, double> axisValues,
  ) {
    if (mouse == null) return;

    final value = mouse.getAxis(source.axis) * binding.scale;
    final current = axisValues[binding.action] ?? 0.0;
    axisValues[binding.action] = current + value;
  }

  void _processGamepadButtonBinding(
    InputBinding binding,
    GamepadButtonBinding source,
    ActionType actionType,
    GamepadState? gamepad,
    Map<ActionId, ButtonPhase> buttonPhases,
    Set<ActionId> buttonPressed,
    Map<ActionId, double> axisValues,
  ) {
    if (gamepad == null) return;

    final phase = gamepad.getButtonPhase(
      source.buttonKey,
      gamepadId: source.gamepadId,
    );
    final isPressed =
        phase == ButtonPhase.justPressed || phase == ButtonPhase.held;

    switch (actionType) {
      case ActionType.button:
        final current = buttonPhases[binding.action];
        if (current == null || _phaseOrder(phase) > _phaseOrder(current)) {
          buttonPhases[binding.action] = phase;
        }
        if (phase == ButtonPhase.justPressed) buttonPressed.add(binding.action);

      case ActionType.axis:
        if (isPressed) {
          final current = axisValues[binding.action] ?? 0.0;
          axisValues[binding.action] =
              current + binding.buttonAxisValue * binding.scale;
        }

      default:
        break;
    }
  }

  void _processMouseScrollBinding(
    InputBinding binding,
    MouseScrollBinding source,
    ActionType actionType,
    MouseState? mouse,
    Map<ActionId, ButtonPhase> buttonPhases,
    Map<ActionId, int> scrollPresses,
    Map<ActionId, double> axisValues,
  ) {
    if (mouse == null) return;
    final steps = mouse.scrollSteps(source.direction);
    if (steps == 0) return;

    switch (actionType) {
      case ActionType.button:
        buttonPhases[binding.action] = ButtonPhase.justPressed;
        scrollPresses[binding.action] =
            (scrollPresses[binding.action] ?? 0) + steps;

      case ActionType.axis:
        final current = axisValues[binding.action] ?? 0.0;
        axisValues[binding.action] =
            current + steps * binding.buttonAxisValue * binding.scale;

      default:
        break;
    }
  }

  void _processGamepadAxisBinding(
    InputBinding binding,
    GamepadAxisBinding source,
    ActionType actionType,
    GamepadState? gamepad,
    Map<ActionId, ButtonPhase> buttonPhases,
    Set<ActionId> buttonPressed,
    Map<ActionId, double> axisValues,
    Map<ActionId, (double, double)> vector2Values,
  ) {
    if (gamepad == null) return;

    var value = gamepad.getAxis(source.axisKey, gamepadId: source.gamepadId);
    if (source.inverted) value = -value;

    if (actionType == ActionType.button) {
      // A trigger as a button: pressed past the press point, let go a
      // little below it.
      final key = (binding.action, source as BindingSource);
      final was = _axisButtonsDown.contains(key);
      final down =
          value >= (was ? binding.pressPoint - 0.1 : binding.pressPoint);
      if (down) {
        _axisButtonsDown.add(key);
      } else {
        _axisButtonsDown.remove(key);
      }
      final phase = switch ((was, down)) {
        (false, true) => ButtonPhase.justPressed,
        (true, true) => ButtonPhase.held,
        (true, false) => ButtonPhase.justReleased,
        (false, false) => ButtonPhase.up,
      };
      final current = buttonPhases[binding.action];
      if (current == null || _phaseOrder(phase) > _phaseOrder(current)) {
        buttonPhases[binding.action] = phase;
      }
      if (phase == ButtonPhase.justPressed) buttonPressed.add(binding.action);
      return;
    }

    if (value.abs() < binding.deadzone) value = 0.0;
    value *= binding.scale;

    switch (actionType) {
      case ActionType.axis:
        final current = axisValues[binding.action] ?? 0.0;
        axisValues[binding.action] = current + value;

      case ActionType.vector2:
        // Which half of the vector, from the axis key's suffix
        // (`left_stick_y`, a raw `leftThumbstickY`); a key that names
        // neither can't feed a vector (bind the whole stick instead).
        final key = source.axisKey;
        final isY = key.endsWith('_y') || key.endsWith('Y');
        final isX = key.endsWith('_x') || key.endsWith('X');
        if (!isX && !isY) return;
        final (cx, cy) = vector2Values[binding.action] ?? (0.0, 0.0);
        if (isY) {
          vector2Values[binding.action] = (cx, cy + value);
        } else {
          vector2Values[binding.action] = (cx + value, cy);
        }

      default:
        break;
    }
  }

  void _processGamepadStickBinding(
    InputBinding binding,
    GamepadStickBinding source,
    ActionType actionType,
    GamepadState? gamepad,
    Map<ActionId, (double, double)> vector2Values,
  ) {
    if (gamepad == null || actionType != ActionType.vector2) return;
    final x = gamepad.getAxis(source.stick.xKey, gamepadId: source.gamepadId);
    final y = gamepad.getAxis(source.stick.yKey, gamepadId: source.gamepadId);
    final (sx, sy) = radialDeadzone(x, y, binding.deadzone);
    final (cx, cy) = vector2Values[binding.action] ?? (0.0, 0.0);
    vector2Values[binding.action] = (
      cx + sx * binding.scale,
      cy + sy * binding.scale,
    );
  }

  /// A stick's raw ([x], [y]) through a radial [deadzone], rescaled so the
  /// value runs smoothly from 0 at the deadzone's edge to 1 at
  /// [stickOuter] and beyond, the same in every direction.
  static (double, double) radialDeadzone(double x, double y, double deadzone) {
    final length = math.sqrt(x * x + y * y);
    if (length <= deadzone || length == 0) return (0.0, 0.0);
    final span = stickOuter - deadzone;
    final scaled = span <= 0
        ? 1.0
        : ((math.min(length, stickOuter) - deadzone) / span).clamp(0.0, 1.0);
    return (x / length * scaled, y / length * scaled);
  }

  void _processCompositeBinding(
    CompositeVector2Binding composite,
    KeyboardState? keyboard,
    MouseState? mouse,
    GamepadState? gamepad,
    Map<ActionId, (double, double)> vector2Values,
  ) {
    double value(BindingSource source) =>
        _sourceValue(source, composite.deadzone, keyboard, mouse, gamepad);
    final x = value(composite.right) - value(composite.left);
    // Screen Y is typically inverted (up = negative).
    final y = value(composite.down) - value(composite.up);

    final (cx, cy) = vector2Values[composite.action] ?? (0.0, 0.0);
    vector2Values[composite.action] = (cx + x, cy + y);
  }

  /// How far [source] is pushed, 0 to 1: a button is 0 or 1; an axis counts
  /// its positive half (its `inverted` flag picks the other half) past
  /// [deadzone].
  double _sourceValue(
    BindingSource source,
    double deadzone,
    KeyboardState? keyboard,
    MouseState? mouse,
    GamepadState? gamepad,
  ) {
    switch (source) {
      case KeyboardBinding():
        return (keyboard?.isPressed(source.key) ?? false) ? 1 : 0;
      case MouseButtonBinding():
        return (mouse?.isButtonPressed(source.button) ?? false) ? 1 : 0;
      case GamepadButtonBinding():
        final pressed =
            gamepad?.isButtonPressed(
              source.buttonKey,
              gamepadId: source.gamepadId,
            ) ??
            false;
        return pressed ? 1 : 0;
      case GamepadAxisBinding():
        if (gamepad == null) return 0;
        var value = gamepad.getAxis(
          source.axisKey,
          gamepadId: source.gamepadId,
        );
        if (source.inverted) value = -value;
        return value < deadzone ? 0 : math.min(value, 1);
      default:
        return 0;
    }
  }

  int _phaseOrder(ButtonPhase phase) {
    return switch (phase) {
      ButtonPhase.up => 0,
      ButtonPhase.justReleased => 1,
      ButtonPhase.held => 2,
      ButtonPhase.justPressed => 3,
    };
  }
}
