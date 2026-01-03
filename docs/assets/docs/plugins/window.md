# Window Management

The `fledge_window` plugin provides comprehensive window management with fullscreen, borderless, and windowed modes. It handles display detection, runtime mode switching, and provides events for tracking window state changes.

## Installation

Add `fledge_window` to your `pubspec.yaml`:

```yaml
dependencies:
  fledge_window: ^0.1.0
```

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_window/fledge_window.dart';

void main() async {
  // Start in fullscreen mode
  await App()
    .addPlugin(WindowPlugin.fullscreen(title: 'My Game'))
    .addPlugin(TimePlugin())
    .run();
}
```

## Window Modes

The plugin supports three window modes:

| Mode | Description |
|------|-------------|
| `fullscreen` | True exclusive fullscreen |
| `borderless` | Frameless window matching display size (default) |
| `windowed` | Standard window with title bar and borders |

### Fullscreen

```dart
WindowPlugin.fullscreen(title: 'My Game')
```

True fullscreen mode where the window takes exclusive control of the display. May provide better performance on some platforms.

### Borderless (Default)

```dart
WindowPlugin.borderless(title: 'My Game')
```

A frameless window that covers the entire display. Allows for faster alt-tabbing and better multi-monitor support than true fullscreen.

### Windowed

```dart
WindowPlugin.windowed(
  title: 'My Game',
  size: Size(1920, 1080),
  minSize: Size(800, 600),
)
```

Standard windowed mode with title bar. The window can be resized, moved, minimized, and maximized.

## Configuration

Use `WindowConfig` for fine-grained control:

```dart
WindowPlugin(config: WindowConfig(
  mode: WindowMode.windowed,
  title: 'My Game',
  windowedSize: Size(1280, 720),
  windowedPosition: Offset(100, 100),
  targetDisplay: 0,  // Primary display
  minSize: Size(640, 480),
  maxSize: Size(3840, 2160),
  alwaysOnTop: false,
  resizable: true,
))
```

## Runtime Mode Switching

### Toggle Methods

```dart
// Toggle between fullscreen and windowed
world.toggleFullscreen();

// Toggle between borderless and windowed
world.toggleBorderless();

// Cycle through all modes: windowed -> borderless -> fullscreen -> windowed
world.cycleWindowMode();
```

### Set Specific Mode

```dart
world.setWindowMode(WindowMode.fullscreen);
world.setWindowMode(WindowMode.borderless);
world.setWindowMode(WindowMode.windowed);

// Target a specific display in multi-monitor setup
world.setWindowMode(WindowMode.borderless, targetDisplay: 1);
```

### Resize Window (Windowed Mode)

```dart
world.setWindowSize(Size(1920, 1080));
world.setWindowPosition(Offset(100, 100));
```

## Responding to Window Events

### Mode Changes

```dart
class WindowModeSystem implements System {
  @override
  Future<void> run(World world) async {
    for (final event in world.eventReader<WindowModeChanged>().read()) {
      print('Mode changed: ${event.previousMode} -> ${event.newMode}');
    }
  }
}
```

### Window Resize

```dart
for (final event in world.eventReader<WindowResized>().read()) {
  print('Size changed: ${event.previousSize} -> ${event.newSize}');
  // Update camera viewport, UI layout, etc.
}
```

### Focus Changes

```dart
for (final event in world.eventReader<WindowFocusChanged>().read()) {
  if (!event.isFocused) {
    // Pause game when losing focus
    world.setNextState(GameState.paused);
  }
}
```

## Querying Window State

### WindowState Resource

```dart
final state = world.windowState;
if (state != null) {
  print('Mode: ${state.mode}');
  print('Size: ${state.size}');
  print('Position: ${state.position}');
  print('Focused: ${state.isFocused}');
  print('Visible: ${state.isVisible}');
  print('Display: ${state.displayIndex}');
}
```

### DisplayInfo Resource

```dart
final info = world.displayInfo;
if (info != null) {
  print('Primary display: ${info.primary.name}');
  print('Resolution: ${info.primary.size}');
  print('Refresh rate: ${info.primary.refreshRate}Hz');
  print('Scale factor: ${info.primary.scaleFactor}');
  print('Connected displays: ${info.displays.length}');

  for (final display in info.displays) {
    print('${display.name}: ${display.size}');
  }
}
```

## Complete Example

```dart
import 'package:flutter/services.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_input/fledge_input.dart';
import 'package:fledge_window/fledge_window.dart';

enum Actions { toggleFullscreen, toggleBorderless }

void main() async {
  final inputMap = InputMap.builder()
    .bindKey(LogicalKeyboardKey.f11, ActionId.fromEnum(Actions.toggleFullscreen))
    .bindKey(LogicalKeyboardKey.f10, ActionId.fromEnum(Actions.toggleBorderless))
    .build();

  await App()
    .addPlugin(TimePlugin())
    .addPlugin(WindowPlugin.borderless(title: 'My Game'))
    .addPlugin(InputPlugin.simple(
      context: InputContext(name: 'default', map: inputMap),
    ))
    .addSystem(WindowToggleSystem())
    .addSystem(WindowEventLoggerSystem())
    .run();
}

class WindowToggleSystem implements System {
  @override
  SystemMeta get meta => const SystemMeta(name: 'WindowToggleSystem');

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) async {
    final actions = world.getResource<ActionState>()!;

    if (actions.justPressed(ActionId.fromEnum(Actions.toggleFullscreen))) {
      world.toggleFullscreen();
    }

    if (actions.justPressed(ActionId.fromEnum(Actions.toggleBorderless))) {
      world.toggleBorderless();
    }
  }
}

class WindowEventLoggerSystem implements System {
  @override
  SystemMeta get meta => const SystemMeta(name: 'WindowEventLoggerSystem');

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) async {
    for (final event in world.eventReader<WindowModeChanged>().read()) {
      print('Window mode: ${event.previousMode} -> ${event.newMode}');
    }

    for (final event in world.eventReader<WindowFocusChanged>().read()) {
      print('Window focus: ${event.isFocused}');
    }
  }
}
```

## Resources Reference

| Resource | Description |
|----------|-------------|
| `WindowState` | Current window mode, size, position, focus state |
| `DisplayInfo` | Information about connected displays |

## Events Reference

| Event | Description |
|-------|-------------|
| `WindowModeChanged` | Fired when window mode changes |
| `WindowResized` | Fired when window is resized |
| `WindowFocusChanged` | Fired when window gains/loses focus |
| `WindowMoved` | Fired when window is moved |

## Platform Notes

- **Windows/macOS/Linux**: Full support for all modes
- **Web**: Limited (browser controls fullscreen via Fullscreen API)
- **Mobile**: Not applicable (apps are always fullscreen)

## See Also

- [Plugins Overview](/docs/plugins/overview) - Plugin system introduction
- [Input Handling](/docs/plugins/input) - Input plugin for hotkey bindings
- [App & Plugins Guide](/docs/guides/app-plugins) - Plugin architecture details
