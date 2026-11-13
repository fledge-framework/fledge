# fledge_input

Action-based input system for [Fledge](https://fledge-framework.dev) games. Maps keyboard, mouse, and gamepad inputs to named actions.

[![pub package](https://img.shields.io/pub/v/fledge_input.svg)](https://pub.dev/packages/fledge_input)

## Installation

```yaml
dependencies:
  fledge_input: ^0.2.1
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

## Buttons in the fixed step

`justPressed` describes the current frame, and a frame can run the fixed-timestep chain zero times (missing the press) or several times (seeing it twice). Systems in the fixed schedules read `fixedJustPressed` / `fixedJustReleased` instead: a press is held until a fixed step has run, then cleared in `Schedules.fixedLast` by `InputFixedLatchSystem` (installed by the plugin), so exactly one fixed step sees it.

```dart
// In a system on Schedules.fixedUpdate:
if (actions.fixedJustPressed(ActionId.fromEnum(Actions.jump))) {
  velocity.y = jumpSpeed;
}
```

Held buttons and axes are state, not edges, so `isPressed` and `getVector2` work the same in either schedule.

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs/plugins/input) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
