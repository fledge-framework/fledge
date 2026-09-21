# fledge_window

Window management plugin for [Fledge](https://fledge-framework.dev) games. Fullscreen, borderless, and windowed modes with runtime switching.

[![pub package](https://img.shields.io/pub/v/fledge_window.svg)](https://pub.dev/packages/fledge_window)

## Installation

```yaml
dependencies:
  fledge_window: ^0.2.1
```

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_window/fledge_window.dart';

void main() async {
  final app = App()
    ..addPlugin(WallTimePlugin())
    ..addPlugin(WindowPlugin.fullscreen(title: 'My Game'));

  await app.run();
}
```

Toggle modes at runtime:

```dart
world.toggleFullscreen();
world.setWindowMode(WindowMode.borderless);
world.cycleWindowMode();
```

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs/plugins/window) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
