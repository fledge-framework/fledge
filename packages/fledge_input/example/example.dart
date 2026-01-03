// ignore_for_file: avoid_print
import 'package:flutter/services.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_input/fledge_input.dart';

// Define your game actions
enum GameActions { move, jump, attack }

void main() async {
  // Create an input map with bindings
  final inputMap = InputMap.builder()
      // Keyboard
      .bindWasd(ActionId.fromEnum(GameActions.move))
      .bindKey(LogicalKeyboardKey.space, ActionId.fromEnum(GameActions.jump))
      // Gamepad
      .bindLeftStick(ActionId.fromEnum(GameActions.move))
      .bindGamepadButton('a', ActionId.fromEnum(GameActions.jump))
      .build();

  // Create the input plugin
  final inputPlugin = InputPlugin.simple(
    context: InputContext(name: 'gameplay', map: inputMap),
  );

  // Add to your app
  // ignore: unused_local_variable
  final app = App()
    ..addPlugin(TimePlugin())
    ..addPlugin(inputPlugin);

  // In a system, read input like this:
  // final actions = world.getResource<ActionState>()!;
  //
  // if (actions.justPressed(ActionId.fromEnum(GameActions.jump))) {
  //   print('Jump!');
  // }
  //
  // final move = actions.vector2Value(ActionId.fromEnum(GameActions.move));
  // print('Move: (${move.$1}, ${move.$2})');

  print('Input plugin configured with ${inputMap.bindings.length} bindings');
  print('Wrap your game widget with InputWidget to capture input');

  // Note: In Flutter, wrap your game widget:
  // InputWidget(
  //   world: app.world,
  //   child: GameWidget(app: app),
  // )
}
