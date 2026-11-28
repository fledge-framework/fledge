# Input

`fledge_input` turns keyboard, mouse and gamepad input into named **actions**.
Your systems ask "was `jump` just pressed?" or "where is `move` pointing?"
instead of checking keys, so one action can be bound to Space, the A button
and a mouse click at once, players can rebind it, and a menu can use a
different set of bindings from gameplay.

## What you need

```yaml
dependencies:
  fledge_input: ^0.7.2
```

- **Flutter** 3.50+ (Dart `^3.14`). Input comes from Flutter's focus and
  pointer events, so there is no headless (pure Dart) mode.
- **Platforms**: desktop first (Windows, macOS, Linux). Keyboard and mouse
  work wherever Flutter does. Gamepads come from the
  [`gamepads`](https://pub.dev/packages/gamepads) plugin, which also has web,
  Android and iOS implementations; those are best-effort and untested here.
- **Setup**: add `InputPlugin` to the app, and wrap your game widget in
  `InputWidget`, which feeds Flutter's events into the world.

<!-- snippet-setup
const jump = ActionId('jump');
const move = ActionId('move');
const fire = ActionId('fire');
const pause = ActionId('pause');

class Player {}
-->

## Quick start

Bind actions in an `InputMap`, hand it to the plugin, and read `ActionState`
in a system:

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_input/fledge_input.dart';
import 'package:fledge_physics/fledge_physics.dart';
import 'package:flutter/services.dart';

const jump = ActionId('jump');
const move = ActionId('move');

class Player {}

final inputMap = InputMap.builder()
    .bindKey(LogicalKeyboardKey.space, jump)
    .bindGamepadButton('a', jump)
    .bindWasd(move)
    .bindArrows(move)
    .bindLeftStick(move)
    .build();

class PlayerMoveSystem extends System {
  static const String systemName = 'playerMove';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    reads: {ComponentId.of<Player>()},
    writes: {ComponentId.of<Velocity>()},
    resourceReads: {ActionState},
  );

  @override
  void run(World world) {
    final actions = world.getResource<ActionState>()!;
    final (mx, my) = actions.vector2Value(move);
    for (final (_, _, vel) in world.query2<Player, Velocity>().iter()) {
      vel.x = mx * vel.max;
      vel.y = my * vel.max;
      if (actions.justPressed(jump)) {
        // start a jump
      }
    }
  }
}

App buildApp() => App()
  ..addPlugin(
    InputPlugin.simple(context: InputContext(name: 'gameplay', map: inputMap)),
  )
  ..addPlugin(const PhysicsPlugin())
  ..addSystem(PlayerMoveSystem(), schedule: Schedules.preUpdate);
```

Then put `InputWidget` around whatever shows the game. Without it, nothing
reaches the input resources:

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_input/fledge_input.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:material_ui/material_ui.dart';

Widget gameView(App app) => MaterialApp(
  home: Scaffold(
    body: InputWidget(
      world: app.world,
      child: FledgeRenderView(app: app),
    ),
  ),
);
```

`FledgeRenderView` only paints; your widget still ticks the app every frame
(see [Rendering overview](/docs/rendering/overview)).

### Where input-driven systems go

The plugin resolves actions in `Schedules.first`, so every later schedule in
the frame sees this frame's input. Put a system that turns input into
movement (writing `Velocity`) in `Schedules.preUpdate`, as above, so it runs
before [physics](/docs/gameplay/physics) clamps and applies velocity in
`update`. With `PhysicsMode.fixed`, use `Schedules.fixedPreUpdate` (and the
[fixed-step reads](#buttons-in-the-fixed-step)). A system that has to live in
the same schedule as physics declares
`before: [CollisionResolutionSystem.systemName]`.

## Actions

An `ActionId` is just a name. `ActionId.fromEnum(MyActions.jump)` makes one
from an enum value (its `name`), so `ActionId.fromEnum(MyActions.jump) ==
ActionId('jump')`.

Every action has one of three **types**, picked by its first binding (or set
with `withActionType`):

| Type | Value | Read with |
|---|---|---|
| `ActionType.button` | A `ButtonPhase`: `up`, `justPressed`, `held`, `justReleased` | `isPressed`, `justPressed`, `justReleased`, `isHeld` |
| `ActionType.axis` | One `double`, usually -1..1 | `axisValue` |
| `ActionType.vector2` | `(x, y)`, clamped to length 1 | `vector2Value` (a record), `getVector2` (a `Vector2Value` with `magnitude`, `normalized`) |

`justPressed` is true for exactly one frame, `held` for the frames after.
Several bindings on one action combine: a button is pressed if any binding
is, and vector2 values are summed (then clamped). Y is **+1 down**, like the
screen, for keys, sticks and the d-pad alike.

## Bindings

`InputMap.builder()` has a method for each kind of source:

| Method | Binds |
|---|---|
| `bindKey(key, action)` | A `LogicalKeyboardKey` to a button |
| `bindKeyToAxis(key, action, value:)` | A key to an axis (D for +1, A for -1) |
| `bindWasd`, `bindArrows` | Four keys to a vector2 |
| `bindComposite(action, up:, down:, left:, right:)` | Any four sources to a vector2 |
| `bindMouseButton(button, action)` | Mouse button `0` left, `1` middle, `2` right, `3` back, `4` forward |
| `bindMouseAxis(axis, action, scale:)` | A `MouseAxis` (`positionX/Y`, `deltaX/Y`, `scrollX/Y`) to an axis |
| `bindScroll(direction, action)` | The wheel turning one `ScrollDirection` to a button |
| `bindGamepadButton(key, action)` | A gamepad button by standard name |
| `bindGamepadAxis(key, action, deadzone:, inverted:)` | A gamepad axis to an axis |
| `bindGamepadAxisAsButton(key, action, pressPoint:)` | An axis (a trigger) to a button |
| `bindLeftStick`, `bindRightStick` | A stick to a vector2, with a radial deadzone |
| `bindDpad` | The d-pad to a vector2 |
| `bind(source, action)` | Any `BindingSource` (used for rebinding) |
| `withDeadzone`, `withActionType`, `withUnclampedVector2` | Per-action settings |

### Scroll wheel

`bindScroll` makes every wheel step one press, and a fast spin that lands
several steps in one frame counts them all. `fixedPressCount` (below) reads
how many:

```dart
final map = InputMap.builder()
    .bindScroll(ScrollDirection.down, const ActionId('next_item'))
    .bindScroll(ScrollDirection.up, const ActionId('previous_item'))
    .build();
```

### Gamepads

Gamepad buttons and axes have standard names, so one binding works on Windows,
macOS and Linux with any recognised controller, and Xbox and PlayStation
layouts share them (`left_bumper` is LB and L1). The names are the constants on
`GamepadButtonBinding` (`a`, `b`, `x`, `y`, `left_bumper`, `right_bumper`,
`left_trigger`, `right_trigger`, `dpad_up` ... `dpad_right`, `start`, `back`,
`left_stick`, `right_stick`, `home`, `touchpad`) and `GamepadAxisBinding`
(`left_stick_x/y`, `right_stick_x/y`, `left_trigger`, `right_trigger`). The
names are positions: `a` is the bottom face button on every pad.

```dart
final map = InputMap.builder()
    .bindWasd(move)
    .bindLeftStick(move, deadzone: 0.2)
    .bindDpad(move)
    .bindGamepadButton('a', jump)
    .bindGamepadAxisAsButton('right_trigger', fire)
    .bindGamepadButton('start', pause)
    .build();
```

- **Sticks** (`bindLeftStick`/`bindRightStick`, which bind a
  `GamepadStickBinding`) read both axes together through a radial, rescaled
  deadzone: a stick resting slightly off centre reads exactly zero, and past
  the deadzone the value grows smoothly to 1 at full tilt, the same in every
  direction.
- **Vector2 clamping**: a keyboard diagonal reads (0.707, 0.707), and keys
  plus a stick never go past full tilt. `withUnclampedVector2(action)` opts
  out.
- **Triggers as buttons**: Windows reports triggers only as axes.
  `bindGamepadAxisAsButton` presses past `pressPoint` (0.5) and lets go a
  little below it, so a resting trigger doesn't chatter.
- **Half-axes in composites**: a `GamepadAxisBinding` as one direction of
  `bindComposite` counts its positive half (`inverted: true` for the other).
- **One pad or any**: every gamepad method takes an optional `gamepadId`.
  Without one, the binding listens to every connected pad.

`InputWidget` follows pads being plugged in and out. A pad unplugged
mid-press lets go of everything it held (`GamepadState.disconnect`), so
nothing stays stuck down.

### Rebinding

Every `BindingSource` (`KeyboardBinding`, `MouseButtonBinding`,
`MouseAxisBinding`, `MouseScrollBinding`, `GamepadButtonBinding`,
`GamepadAxisBinding`, `GamepadStickBinding`) round-trips through JSON. Save the
player's choices, rebuild the map, and swap it into its context; the next
frame resolves with it:

```dart
void applyRebinds(World world, List<Map<String, Object?>> saved) {
  final keys = [for (final json in saved) BindingSource.fromJson(json)!];
  final map = InputMap.builder()
      .bind(keys[0], const ActionId('use'))
      .bindComposite(
        move,
        up: keys[1],
        down: keys[2],
        left: keys[3],
        right: keys[4],
      )
      .build();
  world.getResource<InputContextRegistry>()!.replaceMap('gameplay', map);
}
```

`toJson()` on a source gives the map to save. `fromJson` returns null for a
map it doesn't recognise (one written by a newer version, say).

## Buttons in the fixed step

`justPressed` describes the current frame, and a frame can run the fixed
chain zero times (missing the press) or several times (seeing it twice).
Systems in the fixed schedules read `fixedJustPressed`, `fixedJustReleased`
and `fixedPressCount` instead. A press is held until a fixed step has run,
then `InputFixedLatchSystem` clears it in `Schedules.fixedLast`, so exactly
one fixed step sees it:

```dart
final jumpSystem = FunctionSystem(
  'jump',
  writes: {ComponentId.of<Velocity>()},
  reads: {ComponentId.of<Player>()},
  resourceReads: {ActionState},
  run: (world) {
    final actions = world.getResource<ActionState>()!;
    if (!actions.fixedJustPressed(jump)) return;
    for (final (_, _, vel) in world.query2<Player, Velocity>().iter()) {
      vel.y = -vel.max;
    }
  },
);

final app = App()..addSystem(jumpSystem, schedule: Schedules.fixedPreUpdate);
```

Held buttons and axes are state, not edges, so `isPressed`, `axisValue` and
`vector2Value` work the same in either schedule. `fixedPressCount` counts
presses that arrived before a step ran (wheel steps, or a button mashed
faster than the step rate).

## Contexts

An `InputContext` is a named `InputMap`. Only one context is active at a
time, and only its bindings resolve. Use one per mode: menu, gameplay,
driving.

### Following a game state

Give the plugin your [state](/docs/ecs/states-run-conditions) type and a map
from state values to context names. The plugin then adds a
`ContextUpdateSystem<S>` that switches context whenever the state changes,
before actions resolve that frame:

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_input/fledge_input.dart';
import 'package:flutter/services.dart';

enum GameState { menu, playing, paused }

const move = ActionId('move');
const jump = ActionId('jump');

final menuMap = InputMap.builder()
    .bindArrows(const ActionId('navigate'))
    .bindKey(LogicalKeyboardKey.enter, const ActionId('select'))
    .build();
final gameplayMap = InputMap.builder()
    .bindWasd(move)
    .bindKey(LogicalKeyboardKey.space, jump)
    .build();

App buildApp() => App()
  ..addState<GameState>(GameState.menu)
  ..addPlugin(
    InputPlugin<GameState>(
      contexts: [
        InputContext(name: 'menu', map: menuMap),
        InputContext(
          name: 'gameplay',
          map: gameplayMap,
          cursorMode: CursorMode.hidden,
        ),
      ],
      stateBindings: {GameState.menu: 'menu', GameState.playing: 'gameplay'},
      defaultContext: 'menu',
    ),
  );
```

`defaultContext` is active until the first state match. A state with no entry
in `stateBindings` keeps whichever context was active.

### Switching by hand

`InputContextRegistry` (a resource) also switches directly:

| Member | Effect |
|---|---|
| `push(name)` / `pop()` | Push a context over the current one (a pause menu), and remove it. While anything is pushed, state changes don't switch context |
| `clearManualStack()` | Remove every pushed context |
| `setActive(name)` | Make a context active now (the next state change can switch it again) |
| `addListener(fn)` / `removeListener(fn)` | Hear each change of active context |
| `replaceMap(name, map)` | Swap a context's bindings, keeping its other settings |
| `activeContext`, `activeContextName`, `activeMap` | What's active |

Popping the last pushed context (or `clearManualStack()`) goes back to the
base context: the current state's context, the default, or the last
`setActive`. A state change while something is pushed updates that base, so
the pop lands on the new state's context.

`InputContext.priority` (default `0`) picks among the base context and the
pushed ones: the highest wins, and among equals the most recently pushed. With
every priority left at `0`, the top of the stack is active. A context with a
higher priority (a cutscene, say) stays active when a lower one is pushed over
it, and takes over again when that one is popped.

## Reading raw input

Actions cover most needs, but the raw device states are resources too, for
things like a rebinding screen ("press any key") or a mouse-aimed cursor:

| Resource | Useful members |
|---|---|
| `KeyboardState` | `isPressed(key)`, `justPressed(key)`, `justReleased(key)` |
| `MouseState` | `x`, `y` (widget-local), `deltaX`, `deltaY`, `scrollX`, `scrollY`, `isButtonPressed(b)`, `justPressed(b)`, `scrollSteps(direction)` |
| `GamepadState` | `gamepads`, `connected`, `primary`, `isButtonPressed(key, gamepadId:)`, `getAxis(key, gamepadId:)`, `pressCount(key)`, `version` |

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_input/fledge_input.dart';
import 'package:flutter/services.dart';

final aimSystem = FunctionSystem(
  'aim',
  resourceReads: {MouseState, KeyboardState},
  run: (world) {
    final mouse = world.getResource<MouseState>()!;
    final keys = world.getResource<KeyboardState>()!;
    if (mouse.justPressed(0) && keys.isPressed(LogicalKeyboardKey.shiftLeft)) {
      print('shift-click at ${mouse.x}, ${mouse.y}');
    }
  },
);
```

`SingleGamepadState` (one entry of `gamepads`) carries the pad's `name`,
`vendorId`, `productId` and `connected`. `GamepadState.version` bumps on every
connect, disconnect or rename, so a reader can notice changes without diffing.

**Outside the frame loop** (a widget's ticker while the world is paused),
`GamepadButtonWatcher` reads presses from the monotonic
`GamepadState.pressCount`: `takePresses('a')` returns how many presses
happened since it last looked, so a press and release between two looks still
counts once, and `rebase()` forgets everything pressed so far.

### Pausing the world

Key events keep reaching the input states while the world isn't ticking (a
game paused behind a Flutter menu), and nothing clears them until a frame
ends, so the first tick after resuming would see a key pressed on the menu as
just pressed. Call `discardPendingInput(world)` when the world starts ticking
again, before that tick: presses and releases since the last frame are
dropped, and buttons still held stay held (but never count as just pressed).

```dart
void resume(App app) {
  discardPendingInput(app.world);
  // ...then start ticking again
}
```

## The device in use

`ActiveInputDevice` (a resource and a Flutter `ChangeNotifier`) says whether
the keyboard, the mouse or a controller was used last (`kind`, an
`InputDeviceKind`), and for a controller its `gamepadId` and `family`.
`InputWidget` keeps it current from raw events outside the frame loop, so it
follows the player even while the world is paused. A pad counts once a button
is pressed or a stick pushed past halfway; the mouse once it clicks, scrolls
or moves 8 px. Listen to it to switch prompts between "E: talk" and "A: talk".

### Controller families and button labels

`detectGamepadFamily(name, vendorId:)` tells `GamepadFamily.xbox`,
`playStation`, `nintendo` and `generic` pads apart, by USB vendor id first,
then by name. `gamepadButtonLabel(key, family)` names a button the way its pad
prints it:

```dart
final device = ActiveInputDevice();
final label = device.isGamepad
    ? gamepadButtonLabel('a', device.family) // "A", "Cross" or "B"
    : 'Space';
```

Nintendo labels follow position: the bottom face button (`a`) is labelled "B".
Steam Input presents every pad as an Xbox pad, and macOS doesn't report vendor
ids, so a game that shows prompts may want a player-facing override.

### Rumble

`GamepadRumble` vibrates the controller in use. It's fire and forget:
`InputWidget` sends the effect to the pad without awaiting it inside the tick.

```dart
final hitFeedback = FunctionSystem(
  'hitFeedback',
  resourceReads: {GamepadRumble},
  run: (world) {
    world.getResource<GamepadRumble>()!.play(
      const RumbleEffect(low: 0.6, high: 0.2),
    );
  },
);
```

It does nothing while `enabled` is false (make it a player setting) or, by
default (`onlyWhenActive`), while the keyboard or mouse is in use. `play` and
`stop` take an optional `gamepadId`; `recent` keeps the last 16 effects for
tests. Whether a pad actually vibrates depends on the platform and the
`gamepads` plugin.

## Cursor modes

Each context has a `cursorMode`:

| `CursorMode` | Behaviour |
|---|---|
| `visible` | The normal cursor (or whatever cursor the app shows around the game) |
| `hidden` | No cursor over the game; position still tracked |
| `locked` | Hidden and captured, for mouse-look: `MouseState.deltaX/Y` are raw movement |

The `CursorState` resource holds the effective mode. `requestMode(mode)`
overrides the context's mode (a pause menu that needs the cursor) until
`clearOverride()`.

Flutter has no pointer-lock API, so `locked` needs a `PointerLockDelegate`
passed to `InputWidget(pointerLockDelegate:)` (for example one wrapping the
`pointer_lock` package). Without a delegate, `locked` behaves like `hidden`
and the cursor stops at the screen edges.

`InputPlugin` keeps `CursorState` in step with the active context, so the
cursor changes as soon as the context does (a `push`, `pop`, `setActive` or
state switch), without the widget rebuilding.

## InputWidget

`InputWidget` takes keyboard focus, listens to the pointer, and subscribes to
gamepads. Key events for keys bound in the active map are consumed; unbound
keys bubble up, so app-level shortcuts still work while the game has focus.
Text inside it isn't selectable.

| Parameter | Default | Meaning |
|---|---|---|
| `world` | required | The world to feed |
| `autofocus` | `true` | Take focus on mount |
| `focusOnHover` | `true` | Take focus when the mouse enters |
| `claimFocus` | `true` | False leaves focus to an overlay with its own focus navigation (the game then hears no keys). When focus comes back, the keyboard is caught up (`KeyboardState.sync`), so a key let go in the menu isn't stuck down |
| `focusNode` | own node | An external `FocusNode`, to watch focus (pause on focus loss) or request it from a parent |
| `enableGamepad` | `true` | Subscribe to gamepads (only if `InputPlugin(enableGamepad:)` is true as well) |
| `gamepadSource` | `PluginGamepadSource()` | Where gamepad events come from; implement `GamepadSource` for a fake in tests. The widget owns and disposes it |
| `ignoreGamepadWhenInactive` | `false` | Drop controller input while the app isn't the active one (some platforms keep reading pads after an alt-tab), letting go of what a pad held |
| `pointerLockDelegate` | none | See [cursor modes](#cursor-modes) |

## Menus on a controller

Two approaches work:

- **Through actions**: a menu context with `navigate`/`select` actions, and a
  system that moves a selection resource your widgets draw. Everything stays
  in the ECS and works with any device.
- **Through Flutter focus**: `GamepadFocusBridge` and `VirtualPointer` let a
  controller drive ordinary Flutter menus (buttons, sliders, lists) over the
  game, even while the world is paused. See
  [Controller Menus](/docs/ui/controller-menus).

## Plugin reference

`InputPlugin<S>({contexts, stateBindings, defaultContext, enableGamepad})`,
or `InputPlugin.simple(context:)` for a single context. `enableGamepad: false`
turns gamepads off for every `InputWidget` on the world. It inserts
`KeyboardState`, `MouseState`, `GamepadState`, `ActionState`, `CursorState`,
`InputContextRegistry`, `InputSettings`, `ActiveInputDevice` and
`GamepadRumble`, and adds:

| System | Schedule | Name |
|---|---|---|
| `InputPollingSystem` | `first` (`FirstSets.input`) | `InputPollingSystem.systemName` (`'inputPolling'`) |
| `ContextUpdateSystem<S>` (with `stateBindings`) | `first` (`FirstSets.input`), before action resolution | `'contextUpdate<S>'` with your type |
| `ActionResolutionSystem` | `first` (`FirstSets.input`), after polling | `ActionResolutionSystem.systemName` (`'actionResolution'`) |
| `InputFrameEndSystem` | `last` | `InputFrameEndSystem.systemName` (`'inputFrameEnd'`) |
| `InputFixedLatchSystem` | `fixedLast` | `InputFixedLatchSystem.systemName` (`'inputFixedLatch'`) |

A system in `Schedules.first` that reads `ActionState` declares
`after: [ActionResolutionSystem.systemName]`; in any later schedule, it needs
nothing. `InputFrameEndSystem` clears the frame's just-pressed flags in
`last`, so a system in `last` that reads them orders
`before: [InputFrameEndSystem.systemName]`.

**Settings that do nothing**: `InputPluginConfig.defaultDeadzone` and
`InputPluginConfig.consumeKeyEvents` are deprecated and never read (set
deadzones per binding or with `withDeadzone`; `InputWidget` decides key
propagation, as above).

Full signatures: [fledge_input API reference](https://pub.dev/documentation/fledge_input/latest/).

## See also

- [Controller Menus](/docs/ui/controller-menus)
- [Physics](/docs/gameplay/physics)
- [States & Run Conditions](/docs/ecs/states-run-conditions)
- [Schedules & the Frame](/docs/scheduling/schedules)
