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
    .addPlugin(TimePlugin())
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
  Future<void> run(World world) async {
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

  // Analog sticks to Vector2
  .bindLeftStick(ActionId('move'), deadzone: 0.15)
  .bindRightStick(ActionId('look'), deadzone: 0.1)

  // D-pad to Vector2
  .bindDpad(ActionId('navigate'))

  // Individual axes
  .bindGamepadAxis('left_trigger', ActionId('brake'))
  .bindGamepadAxis('right_trigger', ActionId('accelerate'))
  .build()
```

### Multiple Bindings

The same action can have multiple bindings - the first active input wins:

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
    InputContext(name: 'gameplay', map: gameplayMap),
    InputContext(name: 'pause', map: pauseMap),
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

## InputWidget

The `InputWidget` is a Flutter widget that captures all input and injects it into the ECS world:

```dart
InputWidget(
  world: app.world,
  autofocus: true,           // Focus on mount
  enableGamepad: true,       // Poll gamepads
  focusOnHover: true,        // Focus when mouse enters
  child: GameWidget(app: app),
)
```

Place it at the root of your game widget tree to ensure all input is captured.

## Reading Input in Systems

### ActionState Resource

The primary way to read input:

```dart
class MySystem implements System {
  @override
  Future<void> run(World world) async {
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

## Resources Reference

| Resource | Description |
|----------|-------------|
| `ActionState` | Resolved action values for current frame |
| `KeyboardState` | Raw keyboard key states |
| `MouseState` | Mouse position, buttons, scroll |
| `GamepadState` | All connected gamepads |
| `InputContextRegistry` | Manages input contexts |

## Systems Reference

| System | Stage | Description |
|--------|-------|-------------|
| `InputPollingSystem` | first | Updates raw input frame state |
| `ContextUpdateSystem<S>` | first | Updates active context from game state |
| `ActionResolutionSystem` | first | Resolves actions from raw input |

## See Also

- [Plugins Overview](/docs/plugins/overview) - Plugin system introduction
- [States Guide](/docs/guides/states) - Game state management
- [Resources Guide](/docs/guides/resources) - Working with resources
