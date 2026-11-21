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

## Pausing the world

Key events reach the input states even while the world isn't ticking (a game paused behind a menu), and nothing clears them until a frame ends, so the first tick after resuming would see a key pressed on the menu as just pressed. Call `discardPendingInput(world)` when the world starts ticking again: presses and releases since the last frame are dropped, buttons still held stay held.

```dart
if (running && !wasRunning) discardPendingInput(app.world);
```

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

```dart
InputMap.builder()
  .bindWasd(move)
  .bindLeftStick(move, deadzone: 0.2) // one GamepadStickBinding, radial deadzone
  .bindDpad(move)
  .bindGamepadButton('a', jump)
  .bindGamepadAxisAsButton('right_trigger', fire) // a trigger as a button
  .build();
```

- **Sticks** (`bindLeftStick`, `bindRightStick`, or `GamepadStickBinding`) read both axes together through a **radial, rescaled deadzone**: a stick resting slightly off centre reads exactly zero, and past the deadzone the value grows smoothly to 1 at full tilt, the same in every direction.
- **Every vector2 action is clamped to length 1**, so a keyboard diagonal reads (0.707, 0.707) and keys plus a stick never go past full tilt. Opt out per action with `withUnclampedVector2`.
- **Triggers as buttons**: some platforms (Windows) report triggers only as axes. `bindGamepadAxisAsButton` presses the button past a press point (0.5 by default) and lets go a little below it, so a resting trigger doesn't chatter. An axis source passed to `bind` on an action that's already a button does the same; on a new action, `bind` takes its type from the source (a stick: vector2; an axis: axis).
- **Composites take half-axes**: a `GamepadAxisBinding` as one direction of `bindComposite` counts its positive half by how far it's pushed (`inverted` picks the other half).
- **Connections**: `InputWidget` follows pads being plugged in and out. A pad's name and USB ids (`SingleGamepadState.name`, `vendorId`, `productId`) come from the platform as it connects, and a pad unplugged mid-press lets go of everything it held (`GamepadState.disconnect`), so nothing stays pressed or deflected. `GamepadState.version` bumps on every connect, disconnect or rename.
- **Reading pads outside the frame loop** (a widget's ticker while the world is paused, say): `GamepadButtonWatcher` diffs monotonic press counts (`GamepadState.pressCount`), so a press and release between two looks counts once and nothing pressed before it was made (or last `rebase`d) counts at all.
- **Tests and other sources**: `InputWidget(gamepadSource: ...)` takes any `GamepadSource` (the `gamepads` plugin by default, `PluginGamepadSource`).

## The device in use, button names and rumble

- **`ActiveInputDevice`** (a resource, and a `ChangeNotifier`): whether the keyboard, the mouse or a controller was used last, and for a controller its id and `GamepadFamily`. `InputWidget` keeps it current from raw events, outside the frame loop, so it follows the player even while the world is paused. A pad counts once a button is pressed or a stick pushed past halfway (resting drift doesn't); the mouse once it clicks, scrolls or really moves (8 px; a desk nudge doesn't take over from a pad). Pointer devices listed in `gamepadPointerDevices` (a virtual pointer driven by a stick) never count as the mouse. Listen to it to switch prompts between "E: talk" and "A: talk".
- **Families and labels**: `detectGamepadFamily(name, vendorId:)` tells Xbox, PlayStation and Nintendo pads apart (by USB vendor id first, then name). `gamepadButtonLabel('a', family)` names a button the way its pad does: "A", "Cross" or "B" (Nintendo labels follow the button's position: the bottom face button is "B"). Steam Input presents every pad as an Xbox one, so a game showing prompts may want a player override.
- **Rumble**: `world.getResource<GamepadRumble>()!.play(const RumbleEffect(low: 0.6, high: 0.2))` vibrates the controller in use, fire and forget (never awaited in a tick). It does nothing while `enabled` is false (a player setting) or, by default (`onlyWhenActive`), while the keyboard or mouse is in use; `recent` keeps the last effects for tests.
- **Overlays with their own focus**: `InputWidget(claimFocus: false)` stops the widget taking keyboard focus (on mount, on hover and on clicks), so a menu over the game keeps it. Whenever the widget gets focus back, the keyboard is caught up (`KeyboardState.sync`): a key let go while the menu had focus isn't stuck down, and one pressed there doesn't fire in the game.
- **In the background**: `InputWidget(ignoreGamepadWhenInactive: true)` drops controller input while the app isn't the active one (some platforms keep reading pads after an alt-tab) and lets go of whatever a pad held.

## Menus on a controller

`GamepadFocusBridge` lets a controller drive Flutter menus over a game, through Flutter's own focus and intents, so a menu built from focusable widgets works on a pad with no per-widget code:

```dart
GamepadFocusBridge(
  gamepads: () => world.getResource<GamepadState>(),
  enabled: menuOpen,          // off while gameplay has the pad
  pointer: pointerController, // optional: a virtual pointer on the right stick's click
  child: VirtualPointer(controller: pointerController, child: menu),
)
```

- **Directions** (the d-pad and left stick, with auto-repeat) are offered to the focused widget first as a `GamepadDirectionIntent` (a value row or slider can take left and right), then move focus (`DirectionalFocusIntent`, which scrolls the newly focused widget into view).
- **Buttons** become intents at the focused widget (`buttons`, by default): A `ActivateIntent`, B `DismissIntent`, LB/RB `GamepadTabIntent(-1/+1)`, LT/RT `GamepadPageIntent` (triggers work as buttons even where the platform reports only an axis), X/Y/Menu/View `GamepadButtonIntent`. Handle them with `Actions`.
- **The right stick** sends `GamepadScrollIntent`; unhandled, it scrolls the focused widget's nearest `Scrollable`.
- It reads the pads every Flutter frame, so it works while the world is paused behind the menu. **When it becomes enabled, everything pressed before is forgotten** and a held direction must be let go first: the A that opened a screen, or a B held to run, never acts inside it.

**The virtual pointer** reaches what focus order doesn't (or deliberately leaves out). Clicking the right stick shows it; the right stick moves it, A clicks (and drags while held), X right-clicks, and B, the right stick's click, the d-pad or the left stick put it away. `VirtualPointer` sends its moves and presses as real mouse events from device `VirtualPointer.device`, so `MouseRegion`, `GestureDetector` and drags answer it exactly as they would a mouse; add that device to `ActiveInputDevice.gamepadPointerDevices` so it never counts as the mouse.

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs/plugins/input) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
