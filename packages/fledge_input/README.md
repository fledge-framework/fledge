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

`fixedPressCount` says how many presses the fixed step is getting, for actions that can be pressed several times before a step runs.

## Scroll wheel

`bindScroll` turns the wheel into a button: every wheel step is one press, and a fast spin that lands several steps in one frame counts them all.

```dart
InputMap.builder()
  .bindScroll(ScrollDirection.down, ActionId('next_item'))
  .bindScroll(ScrollDirection.up, ActionId('previous_item'));

// In a fixed-step system:
final steps = actions.fixedPressCount(next) - actions.fixedPressCount(previous);
```

## Rebinding

Every `BindingSource` round-trips through JSON, so a game can save the player's own keys and rebuild its map from them. `bind` and `bindComposite` take any source, and `InputContextRegistry.replaceMap` swaps a context's map; the next frame resolves with it.

```dart
final saved = [for (final s in sources) s.toJson()];       // to disk
final keys = [for (final j in saved) BindingSource.fromJson(j)!];

final map = InputMap.builder()
  .bind(keys[0], ActionId('use'))
  .bindComposite(ActionId('move'), up: keys[1], down: keys[2], left: keys[3], right: keys[4])
  .build();
world.getResource<InputContextRegistry>()!.replaceMap('gameplay', map);
```

## Gamepads

Bind gamepad buttons and axes by their standard names (the `GamepadButtonBinding` / `GamepadAxisBinding` constants: `a`, `left_bumper`, `dpad_up`, `left_stick_x`, ...). Raw platform events are normalized through the `gamepads` package, so one binding works on Windows, macOS and Linux with any recognised controller; Xbox and PlayStation layouts share names (`left_bumper` is LB and L1). Stick Y is +1 **down**, like the screen and the keyboard composites. Raw platform keys still work as binding names too.

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs/plugins/input) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
