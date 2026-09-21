# fledge_input

Action-based input system for [Fledge](https://fledge-framework.dev) games. Maps keyboard, mouse, and gamepad inputs to named actions.

[![pub package](https://img.shields.io/pub/v/fledge_input.svg)](https://pub.dev/packages/fledge_input)

## Installation

```yaml
dependencies:
  fledge_input: ^0.2.0
```

## Quick Start

```dart
import 'package:flutter/services.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_input/fledge_input.dart';

enum Actions { jump, move, attack }

final inputMap = InputMap.builder()
  .bindKey(LogicalKeyboardKey.space, ActionId.fromEnum(Actions.jump))
  .bindWasd(ActionId.fromEnum(Actions.move))
  .bindGamepadButton('a', ActionId.fromEnum(Actions.jump))
  .bindLeftStick(ActionId.fromEnum(Actions.move))
  .build();

final app = App()
  ..addPlugin(InputPlugin.simple(
    context: InputContext(name: 'default', map: inputMap),
  ));

// Wrap your Flutter game widget with InputWidget.
InputWidget(
  world: app.world,
  child: GameWidget(app: app),
);
```

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs/plugins/input) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
