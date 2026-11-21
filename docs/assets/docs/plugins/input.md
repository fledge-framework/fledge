# Input Handling

The `fledge_input` plugin provides a comprehensive action-based input system with keyboard, mouse, and gamepad support. It uses a Unity-style approach where physical inputs are mapped to named actions.

## Installation

Add `fledge_input` to your `pubspec.yaml`:

```yaml
dependencies:
  fledge_input: ^0.1.0
```

## Quick Start

```dart
import 'package:flutter/services.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_input/fledge_input.dart';

// Define your actions as an enum
enum Actions { move, jump, attack }

void main() async {
  // Create an input map
  final inputMap = InputMap.builder()
    .bindWasd(ActionId.fromEnum(Actions.move))
    .bindKey(LogicalKeyboardKey.space, ActionId.fromEnum(Actions.jump))
    .bindMouseButton(0, ActionId.fromEnum(Actions.attack))
    .build();

  // Configure the plugin
  final inputPlugin = InputPlugin.simple(
    context: InputContext(name: 'default', map: inputMap),
  );

  // Build the app
  final app = App()
    .addPlugin(WallTimePlugin())
    .addPlugin(inputPlugin)
    .addSystem(playerSystem);

  // Run with Flutter - wrap with InputWidget
  runApp(MaterialApp(
    home: InputWidget(
      world: app.world,
      child: GameWidget(app: app),
    ),
  ));
}

// Read actions in your systems
class PlayerSystem implements System {
  @override
  void run(World world) {
    final actions = world.getResource<ActionState>()!;

    if (actions.justPressed(ActionId.fromEnum(Actions.jump))) {
      print('Jump!');
    }

    final (mx, my) = actions.vector2Value(ActionId.fromEnum(Actions.move));
    if (mx != 0 || my != 0) {
      print('Move: ($mx, $my)');
    }
  }
}
```

## Core Concepts

### Actions

Actions are logical inputs identified by `ActionId`. You can create them from enums or strings:

```dart
// From enum (recommended)
final jump = ActionId.fromEnum(Actions.jump);

// From string
final jump = ActionId('jump');
```

### Action Types

| Type | Description | Value Class |
|------|-------------|-------------|
| `button` | Digital on/off input | `ButtonValue` |
| `axis` | Single analog value (-1.0 to 1.0) | `AxisValue` |
| `vector2` | 2D analog input (x, y) | `Vector2Value` |

### Button Phases

Button actions track their phase within a frame:

```dart
final actions = world.getResource<ActionState>()!;
final action = ActionId.fromEnum(Actions.jump);

// Check specific phases
if (actions.justPressed(action)) { /* First frame pressed */ }
if (actions.isPressed(action)) { /* Currently down */ }
if (actions.isHeld(action)) { /* Down for multiple frames */ }
if (actions.justReleased(action)) { /* First frame released */ }
```

## Input Bindings

### Keyboard

```dart
InputMap.builder()
  // Single key to button action
  .bindKey(LogicalKeyboardKey.space, ActionId('jump'))

  // Key to axis (for +/- values)
  .bindKeyToAxis(LogicalKeyboardKey.keyD, ActionId('horizontal'), value: 1.0)
  .bindKeyToAxis(LogicalKeyboardKey.keyA, ActionId('horizontal'), value: -1.0)

  // WASD to Vector2
  .bindWasd(ActionId('move'))

  // Arrow keys to Vector2
  .bindArrows(ActionId('navigate'))
  .build()
```

### Mouse

```dart
InputMap.builder()
  // Mouse buttons (0=left, 1=middle, 2=right)
  .bindMouseButton(0, ActionId('attack'))
  .bindMouseButton(2, ActionId('aim'))

  // Mouse axes
  .bindMouseAxis(MouseAxis.deltaX, ActionId('lookX'))
  .bindMouseAxis(MouseAxis.deltaY, ActionId('lookY'))
  .bindMouseAxis(MouseAxis.scrollY, ActionId('zoom'))
  .build()
```

### Gamepad

```dart
InputMap.builder()
  // Buttons
  .bindGamepadButton('a', ActionId('jump'))
  .bindGamepadButton('x', ActionId('attack'))
  .bindGamepadButton('start', ActionId('pause'))

  // Analog sticks to Vector2 (radial deadzone)
  .bindLeftStick(ActionId('move'), deadzone: 0.15)
  .bindRightStick(ActionId('look'), deadzone: 0.1)

  // D-pad to Vector2
  .bindDpad(ActionId('navigate'))

  // Individual axes
  .bindGamepadAxis('left_trigger', ActionId('brake'))
  .bindGamepadAxis('right_trigger', ActionId('accelerate'))

  // A trigger as a button (pressed past 0.5, let go a little below)
  .bindGamepadAxisAsButton('right_trigger', ActionId('fire'))
  .build()
```

A stick binding reads both axes together through a **radial, rescaled deadzone**: a stick resting slightly off centre reads exactly zero, and past the deadzone the value grows smoothly to 1 at full tilt, the same in every direction. **Every vector2 action is clamped to length 1** (a keyboard diagonal reads (0.707, 0.707); keys plus a stick never pass full tilt); opt out with `withUnclampedVector2(action)`.

Windows reports triggers only as axes, so bind them as buttons with `bindGamepadAxisAsButton` rather than `bindGamepadButton('right_trigger', ...)`. A direction of `bindComposite` can be half of an axis (`GamepadAxisBinding('left_stick_y', inverted: true)` for up), read by how far it's pushed.

`InputWidget` follows pads being connected and disconnected: each pad gets its platform name and USB ids (`SingleGamepadState.name`, `vendorId`, `productId`), and a pad unplugged mid-press releases everything it held, so nothing stays pressed. `GamepadState.version` bumps on every connect, disconnect or rename.

### Multiple Bindings

The same action can have multiple bindings. For button actions, the highest-priority phase wins (`justPressed` > `held` > `justReleased` > `up`). For axis actions, values from all active bindings are summed:

```dart
InputMap.builder()
  // Jump: Space OR gamepad A
  .bindKey(LogicalKeyboardKey.space, ActionId('jump'))
  .bindGamepadButton('a', ActionId('jump'))

  // Move: WASD OR left stick OR D-pad
  .bindWasd(ActionId('move'))
  .bindLeftStick(ActionId('move'))
  .bindDpad(ActionId('move'))
  .build()
```

### Player Rebinding

Every `BindingSource` round-trips through JSON (`toJson`, `BindingSource.fromJson`), so the player's own keys can be saved (for example with fledge_save's `PreferencesFile`). Rebuild the map from them with `bind` (any source as a button) and `bindComposite` (four sources as a Vector2), then swap it into the running context:

```dart
final map = InputMap.builder()
    .bind(useKey, ActionId('use'))
    .bindComposite(ActionId('move'), up: up, down: down, left: left, right: right)
    .build();
world.getResource<InputContextRegistry>()!.replaceMap('gameplay', map);
```

`replaceMap` keeps the context's priority and cursor mode; the next action resolution uses the new map. `fromJson` returns `null` for anything it doesn't recognise, so a stale file falls back to defaults.

## Context Switching

Different game states often need different input mappings. The input plugin integrates with Fledge's state system:

```dart
enum GameState { menu, playing, paused }

// Define different input maps
final menuMap = InputMap.builder()
  .bindArrows(ActionId('navigate'))
  .bindKey(LogicalKeyboardKey.enter, ActionId('select'))
  .bindKey(LogicalKeyboardKey.escape, ActionId('back'))
  .build();

final gameplayMap = InputMap.builder()
  .bindWasd(ActionId('move'))
  .bindKey(LogicalKeyboardKey.space, ActionId('jump'))
  .bindKey(LogicalKeyboardKey.escape, ActionId('pause'))
  .bindMouseButton(0, ActionId('attack'))
  .build();

final pauseMap = InputMap.builder()
  .bindArrows(ActionId('navigate'))
  .bindKey(LogicalKeyboardKey.enter, ActionId('select'))
  .bindKey(LogicalKeyboardKey.escape, ActionId('resume'))
  .build();

// Configure plugin with state bindings
final inputPlugin = InputPlugin<GameState>(
  contexts: [
    InputContext(name: 'menu', map: menuMap),
    InputContext(name: 'gameplay', map: gameplayMap, priority: 1),
    InputContext(name: 'pause', map: pauseMap, priority: 2),
  ],
  stateBindings: {
    GameState.menu: 'menu',
    GameState.playing: 'gameplay',
    GameState.paused: 'pause',
  },
  defaultContext: 'menu',
);

// Add to app with state
await App()
  .addState<GameState>(GameState.menu)
  .addPlugin(inputPlugin)
  .run();
```

When the game state changes, the active input context automatically switches.

### Manual Context Switching

For temporary overlays like chat or inventory, use the context stack directly:

```dart
final registry = world.getResource<InputContextRegistry>()!;

// Push a temporary context (takes priority over state-based context)
registry.push('inventory');

// Pop when done
registry.pop();

// Or clear all manual overrides
registry.clearManualStack();
```

The manual stack takes precedence over state-based bindings. When the stack is empty, the state-based context resumes.

## Plugin Configuration

Customize input behavior with `InputPluginConfig`:

```dart
final inputPlugin = InputPlugin.simple(
  context: InputContext(name: 'default', map: inputMap),
  config: InputPluginConfig(
    defaultDeadzone: 0.1,      // Default deadzone for analog inputs
    consumeKeyEvents: true,    // Whether to consume handled key events
  ),
);
```

## InputWidget

The `InputWidget` is a Flutter widget that captures all input and injects it into the ECS world:

```dart
InputWidget(
  world: app.world,
  autofocus: true,           // Focus on mount
  enableGamepad: true,       // Read gamepads
  focusOnHover: true,        // Focus when mouse enters
  gamepadSource: null,       // Where pads come from: the `gamepads` plugin by default; a fake in tests
  claimFocus: true,          // false: leave keyboard focus to an overlay (a menu)
  ignoreGamepadWhenInactive: false, // true: drop pad input while alt-tabbed away
  child: GameWidget(app: app),
)
```

With `claimFocus: false` the widget takes no keyboard focus (not on mount, hover or clicks), so a Flutter menu over the game keeps it and handles its own keys. Whenever the widget gets focus back it catches the keyboard up (`KeyboardState.sync`), so a key let go while the menu had focus isn't stuck down.

Place it at the root of your game widget tree to ensure all input is captured.

### Key event bubbling

`InputWidget.onKeyEvent` returns `KeyEventResult.handled` only for keys that are bound in the active `InputMap`. Unbound keys return `KeyEventResult.ignored`, so they bubble up through the `Focus` tree to ancestor handlers — page-level shortcuts like `Ctrl+K` or `/` keep working even while the game owns focus.

### External FocusNode

Pass a `focusNode` in if you need to observe focus changes from outside the widget (e.g. to pause the game when it loses focus and show a click-to-play overlay):

```dart
final gameFocus = FocusNode()..addListener(onFocusChanged);

InputWidget(
  world: app.world,
  focusNode: gameFocus,      // caller owns + disposes the node
  autofocus: true,
  child: GameWidget(...),
)
```

If you don't pass a `focusNode`, `InputWidget` creates and disposes its own. If you do pass one, you own its lifecycle. See the grid-game demo (`docs/lib/demos/grid_game/grid_game_widget.dart`) for a full pause-on-blur implementation.

## Cursor Management

The input plugin manages cursor visibility and pointer lock through `CursorMode`:

| Mode | Description |
|------|-------------|
| `visible` | Cursor is visible and moves freely (default) |
| `hidden` | Cursor is hidden but still tracks position |
| `locked` | Cursor is hidden and captured for relative movement (FPS-style) |

### Per-Context Cursor Mode

Set the cursor mode on an `InputContext` so it changes automatically with context switches:

```dart
InputContext(
  name: 'gameplay',
  map: gameplayMap,
  cursorMode: CursorMode.locked,  // Lock cursor during gameplay
)

InputContext(
  name: 'menu',
  map: menuMap,
  cursorMode: CursorMode.visible,  // Show cursor in menus
)
```

### Manual Override

Temporarily override the cursor mode via the `CursorState` resource:

```dart
final cursor = world.getResource<CursorState>()!;

// Override cursor mode (takes priority over context-based mode)
cursor.requestMode(CursorMode.visible);

// Clear override and return to context-based mode
cursor.clearOverride();
```

### Pointer Lock

For FPS-style mouse capture, provide a `PointerLockDelegate` to `InputWidget`:

```dart
InputWidget(
  world: app.world,
  pointerLockDelegate: myPointerLockDelegate,
  child: GameWidget(app: app),
)
```

When the cursor mode is `locked`, the delegate captures the mouse and streams movement deltas via `MouseState.deltaX` / `MouseState.deltaY`.

## Reading Input in Systems

### ActionState Resource

The primary way to read input:

```dart
class MySystem implements System {
  @override
  void run(World world) {
    final actions = world.getResource<ActionState>()!;

    // Button actions
    if (actions.justPressed(ActionId('jump'))) {
      // Handle jump
    }

    // Axis actions
    final throttle = actions.axisValue(ActionId('throttle'));

    // Vector2 actions
    final (mx, my) = actions.vector2Value(ActionId('move'));

    // Full value access
    final moveValue = actions.getVector2(ActionId('move'));
    if (moveValue != null && moveValue.isActive()) {
      final normalized = moveValue.normalized;
      // Use normalized.x, normalized.y
    }
  }
}
```

### Raw Input Resources

For advanced use cases, you can access raw input state:

```dart
final keyboard = world.getResource<KeyboardState>()!;
if (keyboard.isPressed(LogicalKeyboardKey.shift)) {
  // Shift is held
}

final mouse = world.getResource<MouseState>()!;
print('Mouse at: ${mouse.x}, ${mouse.y}');
print('Delta: ${mouse.deltaX}, ${mouse.deltaY}');

final gamepad = world.getResource<GamepadState>()!;
final primary = gamepad.primary; // First connected gamepad
if (primary != null) {
  print('Left stick X: ${primary.getAxis("left_stick_x")}');
}
```

Reading pads from Flutter rather than a system (a widget's ticker while the world is paused behind a menu, when `ActionState` isn't updated): use a `GamepadButtonWatcher`. It diffs monotonic press counts, so a press and release between two looks counts once, and `rebase()` forgets every earlier press (call it as a menu opens, so the press that opened it isn't read again).

```dart
final watcher = GamepadButtonWatcher(() => world.getResource<GamepadState>());
// each Flutter frame:
if (watcher.takePresses('back') > 0) closeMenu();
```

### The device in use, button names and rumble

`ActiveInputDevice` (a resource and a `ChangeNotifier`) says which device the player used last: the keyboard, the mouse or a controller (with its id and family). `InputWidget` keeps it current from raw events, so it follows the player even while the world is paused; a stick resting slightly off centre or a mouse nudged by the desk doesn't switch it. Use it to show the right prompt:

```dart
final device = world.getResource<ActiveInputDevice>()!;
final use = device.isGamepad
    ? gamepadButtonLabel('a', device.family) // "A", "Cross", or "B" on a Switch pad
    : 'E';
```

`detectGamepadFamily(name, vendorId:)` tells Xbox, PlayStation and Nintendo pads apart, by USB vendor id first, then name. Nintendo labels follow position (the bottom face button, standard key `a`, is labelled "B"). Under Steam Input every pad reports as an Xbox pad, so offer players an override if prompts matter.

`GamepadRumble` vibrates the controller in use, fire and forget:

```dart
world.getResource<GamepadRumble>()!
  .play(const RumbleEffect(low: 0.6, high: 0.2, duration: Duration(milliseconds: 150)));
```

It does nothing while `enabled` is false (a player setting) or, by default (`onlyWhenActive`), while the keyboard or mouse is in use. `recent` keeps the last effects played, for tests.

### Buttons in the fixed step

`justPressed` and `justReleased` describe the current frame. A frame can run the fixed-timestep chain zero times, missing the press, or several times, seeing it twice. Systems in the fixed schedules use `fixedJustPressed` and `fixedJustReleased` instead: a press is held until a fixed step has run, then cleared by `InputFixedLatchSystem` in `Schedules.fixedLast`, so exactly one fixed step sees each press.

```dart
// On Schedules.fixedUpdate:
if (actions.fixedJustPressed(ActionId('jump'))) {
  velocity.y = jumpSpeed;
}
```

Held buttons and axes are state rather than edges, so `isPressed` and `getVector2` read the same in either schedule.

## Resources Reference

| Resource | Description |
|----------|-------------|
| `ActionState` | Resolved action values for current frame |
| `KeyboardState` | Raw keyboard key states |
| `MouseState` | Mouse position, buttons, scroll |
| `GamepadState` | All connected gamepads |
| `ActiveInputDevice` | The device used last (keyboard, mouse or a controller, with its family) |
| `GamepadRumble` | Controller vibration |
| `InputContextRegistry` | Manages input contexts |
| `CursorState` | Cursor visibility and lock mode |

## Systems Reference

| System | Stage | Description |
|--------|-------|-------------|
| `InputPollingSystem` | first (`FirstSets.input`) | Updates raw input frame state |
| `ContextUpdateSystem<S>` | first (`FirstSets.input`) | Updates active context from game state |
| `ActionResolutionSystem` | first (`FirstSets.input`) | Resolves actions from raw input |
| `InputFrameEndSystem` | last | Clears input transition flags |
| `InputFixedLatchSystem` | fixedLast | Clears the presses held for the fixed step (`fixedJustPressed`) |

The `FirstSets.input` phase runs after window / audio platform systems and before content spawning (tilemaps, hot reload) — see [Standard Phases of `first`](/docs/guides/scheduling#standard-phases-of-first). To read resolved actions in `first`, add `after: [ActionResolutionSystem.systemName]` (or `after: [FirstSets.input]`); systems in `preUpdate` or later need no ordering.

## Menus on a Controller

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

## UI Input Architecture

**Important:** When integrating Fledge input with Flutter UI, follow this pattern to keep your architecture clean and maintainable.

### The Correct Pattern

All input should flow through the Fledge input system. UI widgets should be **purely visual** - they render state but never handle input directly.

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ InputWidget │ -> │ ActionState │ -> │   Systems   │ -> │  Resources  │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                             │                  │
                                             │                  v
                                             │           ┌─────────────┐
                                             └─────────> │ UI Widgets  │
                                                         │(purely visual)
                                                         └─────────────┘
```

1. **InputWidget** captures all keyboard/mouse/gamepad input
2. **ActionState** resource holds resolved action values
3. **Systems** read ActionState and update game/UI resources
4. **UI Widgets** read resources to render - they do NOT handle input

### Example: Menu Navigation

❌ **Wrong** - Widget handles input directly:

```dart
// DON'T DO THIS - Widget handling its own input
class VerticalMenu extends StatefulWidget {
  @override
  _VerticalMenuState createState() => _VerticalMenuState();
}

class _VerticalMenuState extends State<VerticalMenu> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        // BAD: Widget handles input directly
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          setState(() => _selectedIndex++);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: /* menu items */,
    );
  }
}
```

✅ **Correct** - System handles input, widget renders state:

```dart
// 1. Define a resource to hold UI state
class MenuState {
  int selectedIndex = 0;
  int itemCount = 4;
  bool confirmed = false;

  void moveDown() {
    selectedIndex = (selectedIndex + 1) % itemCount;
  }
}

// 2. System reads ActionState and updates MenuState
class MenuInputSystem implements System {
  @override
  void run(World world) {
    final actions = world.getResource<ActionState>()!;
    final menu = world.getResource<MenuState>()!;

    final move = actions.getVector2(ActionId('menuMove'));
    if (move != null && move.y > 0.5) {
      menu.moveDown();
    }

    if (actions.justPressed(ActionId('confirm'))) {
      menu.confirmed = true;
    }
  }
}

// 3. Widget is purely visual - reads state, no input handlers
class VerticalMenu extends StatelessWidget {
  final int selectedIndex;  // Passed from MenuState
  final List<String> options;

  const VerticalMenu({
    required this.selectedIndex,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    // No Focus, no onKeyEvent, no GestureDetector for navigation
    return Column(
      children: options.asMap().entries.map((e) {
        return MenuItem(
          label: e.value,
          isSelected: e.key == selectedIndex,
        );
      }).toList(),
    );
  }
}

// 4. In your game widget, pass state to UI
Widget build(BuildContext context) {
  final menuState = world.getResource<MenuState>()!;
  return VerticalMenu(
    selectedIndex: menuState.selectedIndex,
    options: ['New Game', 'Continue', 'Settings'],
  );
}
```

### Why This Pattern?

1. **Single source of truth** - Input is always processed through the ECS
2. **Testable** - Systems can be unit tested without Flutter widgets
3. **Input context switching** - State-based context switching works automatically
4. **Consistent** - Same input handling whether on keyboard, gamepad, or touch
5. **No focus conflicts** - No competing Focus nodes capturing keyboard input

### What About Mouse/Touch?

For mouse clicks and touch, the same pattern applies. If you need clickable buttons, the system should process the click and update state:

```dart
// System handles click state
class UIClickSystem implements System {
  @override
  void run(World world) {
    final mouse = world.getResource<MouseState>()!;
    final uiState = world.getResource<UIState>()!;

    if (mouse.justPressed(0)) {  // Left click
      // Check if click is on a UI element
      if (uiState.isPointInButton(mouse.x, mouse.y)) {
        uiState.buttonClicked = true;
      }
    }
  }
}
```

For simple menus, consider making buttons navigable by keyboard/gamepad and using the confirm action for selection, rather than implementing separate click handling.

## See Also

- [Plugins Overview](/docs/plugins/overview) - Plugin system introduction
- [States Guide](/docs/guides/states) - Game state management
- [Resources Guide](/docs/guides/resources) - Working with resources
