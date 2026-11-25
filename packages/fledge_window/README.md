# fledge_window

Window management plugin for [Fledge](https://fledge-framework.dev) games. Fullscreen, borderless, and windowed modes with runtime switching.

[![pub package](https://img.shields.io/pub/v/fledge_window.svg)](https://pub.dev/packages/fledge_window)

## Installation

```yaml
dependencies:
  fledge_window: ^0.7.0
```

## Requirements

Flutter 3.50+, desktop only (Windows, macOS, Linux): it's built on
`window_manager` and `screen_retriever`, which don't support the web or
mobile.

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_window/fledge_window.dart';

final app = App()
  ..addPlugin(WallTimePlugin())
  ..addPlugin(WindowPlugin.fullscreen(title: 'My Game'));
```

Tick the app from your game widget. The plugin talks to the window over
platform channels, so if you drive it with `app.run()` from `main` instead,
call `WidgetsFlutterBinding.ensureInitialized()` first.

Toggle modes at runtime. Each sends a request. The plugin starts the native
call in the background (no frame waits on the OS) and applies the result,
updating `WindowState` and sending `WindowModeChanged`, on the first frame
after the OS finishes:

```dart
world.toggleFullscreen();
world.setWindowMode(WindowMode.borderless);
world.cycleWindowMode();
```

Focus, resize and move changes made by the user or the OS arrive as
`WindowFocusChanged`, `WindowResized` and `WindowMoved` events, and
`WindowState` stays current. A native call that fails sends
`WindowOperationFailed` and leaves `WindowState` unchanged.

`Display.refreshRate` comes from Flutter's engine (`PlatformDispatcher.displays`),
matched to each display by physical size, and falls back to 60.0 when no
engine display matches.

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs/platform/window) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
