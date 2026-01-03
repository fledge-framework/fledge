/// Input handling plugin for the Fledge ECS game framework.
///
/// Provides a Unity-style action-based input system with:
/// - Named actions mapped to multiple physical inputs
/// - Context switching via game states
/// - Support for keyboard, mouse, and gamepad
///
/// ## Quick Start
///
/// ```dart
/// import 'package:flutter/services.dart';
/// import 'package:fledge_ecs/fledge_ecs.dart';
/// import 'package:fledge_input/fledge_input.dart';
///
/// // Define your actions
/// enum Actions { jump, move, attack }
///
/// // Create an input map
/// final inputMap = InputMap.builder()
///   .bindKey(LogicalKeyboardKey.space, ActionId.fromEnum(Actions.jump))
///   .bindWasd(ActionId.fromEnum(Actions.move))
///   .bindGamepadButton('a', ActionId.fromEnum(Actions.jump))
///   .bindLeftStick(ActionId.fromEnum(Actions.move))
///   .build();
///
/// // Configure the plugin
/// final inputPlugin = InputPlugin.simple(
///   context: InputContext(name: 'default', map: inputMap),
/// );
///
/// // Use in your app
/// await App()
///   .addPlugin(inputPlugin)
///   .addSystem(playerSystem)
///   .run();
///
/// // Wrap your game widget with InputWidget
/// InputWidget(
///   world: app.world,
///   child: GameWidget(app: app),
/// )
///
/// // Read actions in a system
/// @system
/// void playerSystem(World world) {
///   final actions = world.getResource<ActionState>()!;
///
///   if (actions.justPressed(ActionId.fromEnum(Actions.jump))) {
///     // Jump!
///   }
///
///   final (mx, my) = actions.vector2Value(ActionId.fromEnum(Actions.move));
///   // Move player by (mx, my)
/// }
/// ```
///
/// ## Context Switching with Game States
///
/// ```dart
/// enum GameState { menu, playing }
///
/// final menuMap = InputMap.builder()
///   .bindArrows(ActionId('navigate'))
///   .bindKey(LogicalKeyboardKey.enter, ActionId('select'))
///   .build();
///
/// final gameplayMap = InputMap.builder()
///   .bindWasd(ActionId('move'))
///   .bindKey(LogicalKeyboardKey.space, ActionId('jump'))
///   .build();
///
/// final inputPlugin = InputPlugin<GameState>(
///   contexts: [
///     InputContext(name: 'menu', map: menuMap),
///     InputContext(name: 'gameplay', map: gameplayMap),
///   ],
///   stateBindings: {
///     GameState.menu: 'menu',
///     GameState.playing: 'gameplay',
///   },
///   defaultContext: 'menu',
/// );
///
/// await App()
///   .addState<GameState>(GameState.menu)
///   .addPlugin(inputPlugin)
///   .run();
/// ```
library fledge_input;

// Plugin
export 'src/plugin.dart';

// Actions
export 'src/action/action.dart';
export 'src/action/action_state.dart';
export 'src/action/input_binding.dart';
export 'src/action/input_map.dart';

// Context
export 'src/context/input_context.dart';
export 'src/context/context_registry.dart';

// Raw input
export 'src/raw/keyboard_state.dart';
export 'src/raw/mouse_state.dart';
export 'src/raw/gamepad_state.dart';
export 'src/raw/raw_input.dart';

// Systems
export 'src/systems/input_polling_system.dart';
export 'src/systems/action_resolution_system.dart';
export 'src/systems/context_update_system.dart';

// Widget
export 'src/widget/input_widget.dart';
