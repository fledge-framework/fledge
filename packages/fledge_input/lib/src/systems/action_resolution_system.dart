import 'package:fledge_ecs/fledge_ecs.dart';

import '../action/action.dart';
import '../action/action_state.dart';
import '../action/input_binding.dart';
import '../context/context_registry.dart';
import '../raw/keyboard_state.dart';
import '../raw/mouse_state.dart';
import '../raw/gamepad_state.dart';

/// System that resolves actions from raw input based on the active input map.
///
/// Runs after InputPollingSystem. Reads raw input states and the active
/// InputContext to produce ActionState values.
class ActionResolutionSystem implements System {
  @override
  SystemMeta get meta => const SystemMeta(
        name: 'actionResolution',
        resourceReads: {
          KeyboardState,
          MouseState,
          GamepadState,
          InputContextRegistry
        },
        resourceWrites: {ActionState},
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    final keyboard = world.getResource<KeyboardState>();
    final mouse = world.getResource<MouseState>();
    final gamepad = world.getResource<GamepadState>();
    final contextRegistry = world.getResource<InputContextRegistry>();
    final actionState = world.getResource<ActionState>();

    if (actionState == null || contextRegistry == null) return Future.value();

    final inputMap = contextRegistry.activeMap;
    if (inputMap == null) return Future.value();

    // Clear previous frame's values
    actionState.clear();

    // Track intermediate values for combining multiple bindings
    final buttonPhases = <ActionId, ButtonPhase>{};
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
            axisValues,
          );

        case MouseButtonBinding():
          _processMouseButtonBinding(
            binding,
            source,
            actionType,
            mouse,
            buttonPhases,
            axisValues,
          );

        case MouseAxisBinding():
          _processMouseAxisBinding(
            binding,
            source,
            mouse,
            axisValues,
          );

        case GamepadButtonBinding():
          _processGamepadButtonBinding(
            binding,
            source,
            actionType,
            gamepad,
            buttonPhases,
            axisValues,
          );

        case GamepadAxisBinding():
          _processGamepadAxisBinding(
            binding,
            source,
            actionType,
            gamepad,
            axisValues,
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
          actionState.set(action, ButtonValue(phase));

        case ActionType.axis:
          var value = axisValues[action] ?? 0.0;
          if (value.abs() < deadzone) value = 0.0;
          actionState.set(action, AxisValue(value, deadzone: deadzone));

        case ActionType.vector2:
          final (x, y) = vector2Values[action] ?? (0.0, 0.0);
          actionState.set(action, Vector2Value(x, y));
      }
    }

    return Future.value();
  }

  void _processKeyboardBinding(
    InputBinding binding,
    KeyboardBinding source,
    ActionType actionType,
    KeyboardState? keyboard,
    Map<ActionId, ButtonPhase> buttonPhases,
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
    Map<ActionId, double> axisValues,
  ) {
    if (gamepad == null) return;

    final phase =
        gamepad.getButtonPhase(source.buttonKey, gamepadId: source.gamepadId);
    final isPressed =
        phase == ButtonPhase.justPressed || phase == ButtonPhase.held;

    switch (actionType) {
      case ActionType.button:
        final current = buttonPhases[binding.action];
        if (current == null || _phaseOrder(phase) > _phaseOrder(current)) {
          buttonPhases[binding.action] = phase;
        }

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

  void _processGamepadAxisBinding(
    InputBinding binding,
    GamepadAxisBinding source,
    ActionType actionType,
    GamepadState? gamepad,
    Map<ActionId, double> axisValues,
    Map<ActionId, (double, double)> vector2Values,
  ) {
    if (gamepad == null) return;

    var value = gamepad.getAxis(source.axisKey, gamepadId: source.gamepadId);
    if (source.inverted) value = -value;
    if (value.abs() < binding.deadzone) value = 0.0;
    value *= binding.scale;

    switch (actionType) {
      case ActionType.axis:
        final current = axisValues[binding.action] ?? 0.0;
        axisValues[binding.action] = current + value;

      case ActionType.vector2:
        // Determine if this is X or Y based on axis name
        final isY =
            source.axisKey.contains('y') || source.axisKey.contains('Y');
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

  void _processCompositeBinding(
    CompositeVector2Binding composite,
    KeyboardState? keyboard,
    MouseState? mouse,
    GamepadState? gamepad,
    Map<ActionId, (double, double)> vector2Values,
  ) {
    double x = 0, y = 0;

    if (_isSourcePressed(composite.right, keyboard, mouse, gamepad)) x += 1;
    if (_isSourcePressed(composite.left, keyboard, mouse, gamepad)) x -= 1;
    if (_isSourcePressed(composite.up, keyboard, mouse, gamepad)) {
      y -= 1; // Screen Y is typically inverted (up = negative)
    }
    if (_isSourcePressed(composite.down, keyboard, mouse, gamepad)) y += 1;

    final (cx, cy) = vector2Values[composite.action] ?? (0.0, 0.0);
    vector2Values[composite.action] = (cx + x, cy + y);
  }

  bool _isSourcePressed(
    BindingSource source,
    KeyboardState? keyboard,
    MouseState? mouse,
    GamepadState? gamepad,
  ) {
    switch (source) {
      case KeyboardBinding():
        return keyboard?.isPressed(source.key) ?? false;
      case MouseButtonBinding():
        return mouse?.isButtonPressed(source.button) ?? false;
      case GamepadButtonBinding():
        return gamepad?.isButtonPressed(source.buttonKey,
                gamepadId: source.gamepadId) ??
            false;
      default:
        return false;
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
