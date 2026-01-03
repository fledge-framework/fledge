# fledge_window

Window management plugin for [Fledge](https://fledge-framework.dev) games. Fullscreen, borderless, and windowed modes with runtime switching.

[![pub package](https://img.shields.io/pub/v/fledge_window.svg)](https://pub.dev/packages/fledge_window)

## Features

- **Window Modes**: Fullscreen, borderless, and windowed
- **Runtime Switching**: Toggle modes during gameplay
- **Display Info**: Query monitor resolution and properties
- **Window Events**: React to resize, focus, and mode changes

## Installation

```yaml
dependencies:
  fledge_window: ^0.1.0
```

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_window/fledge_window.dart';

void main() async {
  // Fullscreen game
  final app = App()
    ..addPlugin(WindowPlugin.fullscreen(title: 'My Game'))
    ..addPlugin(TimePlugin());

  await app.run();
}
```

## Window Modes

Three modes are supported:

- **Fullscreen**: True exclusive fullscreen
- **Borderless**: Frameless window matching display size
- **Windowed**: Standard window with title bar

## Runtime Mode Switching

```dart
// Toggle fullscreen
world.toggleFullscreen();

// Set specific mode
world.setWindowMode(WindowMode.borderless);

// Cycle through modes
world.cycleWindowMode();
```

## Listening to Events

```dart
for (final event in world.eventReader<WindowModeChanged>().read()) {
  print('Mode: ${event.previousMode} -> ${event.newMode}');
}

for (final event in world.eventReader<WindowResized>().read()) {
  // Update camera viewport
}

for (final event in world.eventReader<WindowFocusChanged>().read()) {
  if (!event.isFocused) {
    // Pause game
  }
}
```

## Querying State

```dart
final state = world.windowState;
print('Mode: ${state?.mode}');
print('Size: ${state?.size}');

final info = world.displayInfo;
print('Primary: ${info?.primary.name}');
print('Resolution: ${info?.primary.size}');
```

## Documentation

See the [Window Guide](https://fledge-framework.dev/docs/guides/window) for detailed documentation.

## Related Packages

- [fledge_ecs](https://pub.dev/packages/fledge_ecs) - Core ECS framework
- [fledge_input](https://pub.dev/packages/fledge_input) - Input handling
- [fledge_audio](https://pub.dev/packages/fledge_audio) - Audio (pauses on focus loss)

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
