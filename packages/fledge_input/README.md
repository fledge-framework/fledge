# fledge_input

Action-based input system for [Fledge](https://fledge-framework.dev) games. Maps keyboard, mouse, and gamepad inputs to named actions.

[![pub package](https://img.shields.io/pub/v/fledge_input.svg)](https://pub.dev/packages/fledge_input)

## Features

- **Named Actions**: Define semantic actions like "jump" or "move" instead of raw keys
- **Multiple Bindings**: Map multiple physical inputs to a single action
- **Context Switching**: Switch input mappings based on game state (menu vs gameplay)
- **Input Types**: Keyboard, mouse, and gamepad support
- **WASD/Arrows**: Built-in helpers for common movement patterns

## Installation

```yaml
dependencies:
  fledge_input: ^0.1.0
```

## Quick Start

```dart
import 'package:flutter/services.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_input/fledge_input.dart';

// Define your actions
enum Actions { jump, move, attack }

// Create an input map
final inputMap = InputMap.builder()
  .bindKey(LogicalKeyboardKey.space, ActionId.fromEnum(Actions.jump))
  .bindWasd(ActionId.fromEnum(Actions.move))
  .bindGamepadButton('a', ActionId.fromEnum(Actions.jump))
  .bindLeftStick(ActionId.fromEnum(Actions.move))
  .build();

// Configure the plugin
final inputPlugin = InputPlugin.simple(
  context: InputContext(name: 'default', map: inputMap),
);

// Use in your app
final app = App()
  ..addPlugin(inputPlugin);

// Wrap your game widget with InputWidget
InputWidget(
  world: app.world,
  child: GameWidget(app: app),
)
```

## Reading Input in Systems

```dart
class PlayerSystem extends System {
  @override
  Future<void> run(World world) async {
    final actions = world.getResource<ActionState>()!;

    if (actions.justPressed(ActionId.fromEnum(Actions.jump))) {
      // Jump!
    }

    final move = actions.vector2Value(ActionId.fromEnum(Actions.move));
    // Move player by (move.$1, move.$2)
  }
}
```

## Context Switching

Switch input mappings based on game state:

```dart
enum GameState { menu, playing }

final menuMap = InputMap.builder()
  .bindArrows(ActionId('navigate'))
  .bindKey(LogicalKeyboardKey.enter, ActionId('select'))
  .build();

final gameplayMap = InputMap.builder()
  .bindWasd(ActionId('move'))
  .bindKey(LogicalKeyboardKey.space, ActionId('jump'))
  .build();

final inputPlugin = InputPlugin<GameState>(
  contexts: [
    InputContext(name: 'menu', map: menuMap),
    InputContext(name: 'gameplay', map: gameplayMap),
  ],
  stateBindings: {
    GameState.menu: 'menu',
    GameState.playing: 'gameplay',
  },
  defaultContext: 'menu',
);
```

## Documentation

See the [Input System Guide](https://fledge-framework.dev/docs/guides/input) for detailed documentation.

## Related Packages

- [fledge_ecs](https://pub.dev/packages/fledge_ecs) - Core ECS framework
- [fledge_window](https://pub.dev/packages/fledge_window) - Window management

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
