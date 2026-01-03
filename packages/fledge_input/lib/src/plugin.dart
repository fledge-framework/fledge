import 'package:fledge_ecs/fledge_ecs.dart';

import 'action/action_state.dart';
import 'context/context_registry.dart';
import 'context/input_context.dart';
import 'raw/keyboard_state.dart';
import 'raw/mouse_state.dart';
import 'raw/gamepad_state.dart';
import 'systems/input_polling_system.dart';
import 'systems/action_resolution_system.dart';
import 'systems/context_update_system.dart';
import 'systems/input_frame_end_system.dart';

/// Plugin that adds comprehensive input handling to a Fledge app.
///
/// ## Usage
///
/// ```dart
/// // Define actions
/// enum GameActions { jump, move, attack, pause }
///
/// // Define game states
/// enum GameState { menu, playing, paused }
///
/// // Create input maps for each context
/// final gameplayMap = InputMap.builder()
///   .bindKey(LogicalKeyboardKey.space, ActionId.fromEnum(GameActions.jump))
///   .bindWasd(ActionId.fromEnum(GameActions.move))
///   .bindMouseButton(0, ActionId.fromEnum(GameActions.attack))
///   .bindKey(LogicalKeyboardKey.escape, ActionId.fromEnum(GameActions.pause))
///   .bindGamepadButton('a', ActionId.fromEnum(GameActions.jump))
///   .bindLeftStick(ActionId.fromEnum(GameActions.move))
///   .build();
///
/// final menuMap = InputMap.builder()
///   .bindKey(LogicalKeyboardKey.enter, ActionId('select'))
///   .bindWasd(ActionId('navigate'))
///   .build();
///
/// // Configure plugin
/// final inputPlugin = InputPlugin<GameState>(
///   contexts: [
///     InputContext(name: 'gameplay', map: gameplayMap),
///     InputContext(name: 'menu', map: menuMap),
///   ],
///   stateBindings: {
///     GameState.playing: 'gameplay',
///     GameState.menu: 'menu',
///   },
///   defaultContext: 'menu',
/// );
///
/// // Add to app
/// await App()
///   .addPlugin(TimePlugin())
///   .addState<GameState>(GameState.menu)
///   .addPlugin(inputPlugin)
///   .run();
/// ```
class InputPlugin<S extends Enum> implements Plugin {
  /// Input contexts to register.
  final List<InputContext> contexts;

  /// Mapping from state values to context names.
  final Map<S, String>? stateBindings;

  /// Default context name when no state matches.
  final String? defaultContext;

  /// Whether to enable gamepad support.
  final bool enableGamepad;

  /// Plugin configuration.
  final InputPluginConfig config;

  InputPlugin({
    this.contexts = const [],
    this.stateBindings,
    this.defaultContext,
    this.enableGamepad = true,
    this.config = const InputPluginConfig(),
  });

  /// Create a simple input plugin with a single context.
  factory InputPlugin.simple({
    required InputContext context,
    bool enableGamepad = true,
    InputPluginConfig config = const InputPluginConfig(),
  }) {
    return InputPlugin(
      contexts: [context],
      defaultContext: context.name,
      enableGamepad: enableGamepad,
      config: config,
    );
  }

  @override
  void build(App app) {
    // Insert raw input resources
    app
        .insertResource(KeyboardState())
        .insertResource(MouseState())
        .insertResource(GamepadState())
        .insertResource(ActionState());

    // Set up context registry
    final registry = InputContextRegistry();
    for (final context in contexts) {
      registry.register(context);
    }

    // Bind contexts to states
    if (stateBindings != null) {
      for (final entry in stateBindings!.entries) {
        final contextName = entry.value;
        final context =
            contexts.where((c) => c.name == contextName).firstOrNull;
        if (context != null) {
          registry.registerForState(context, entry.key);
        }
      }
    }

    if (defaultContext != null) {
      registry.setDefault(defaultContext!);
    }

    app.insertResource(registry);

    // Add systems
    app.addSystem(InputPollingSystem(), stage: CoreStage.first);

    // Add state-aware context update if state bindings are configured
    if (stateBindings != null && stateBindings!.isNotEmpty) {
      app.addSystem(ContextUpdateSystem<S>(), stage: CoreStage.first);
    }

    app.addSystem(ActionResolutionSystem(), stage: CoreStage.first);

    // Clear transition flags at end of frame, after all systems have read input
    app.addSystem(InputFrameEndSystem(), stage: CoreStage.last);
  }

  @override
  void cleanup() {
    // Resources are garbage collected with the world
  }
}

/// Configuration for the input plugin.
class InputPluginConfig {
  /// Default deadzone for analog inputs.
  final double defaultDeadzone;

  /// Whether to consume handled key events (prevent propagation).
  final bool consumeKeyEvents;

  const InputPluginConfig({
    this.defaultDeadzone = 0.1,
    this.consumeKeyEvents = true,
  });
}
