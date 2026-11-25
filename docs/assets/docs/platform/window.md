# Window

`fledge_window` controls the game's desktop window: fullscreen, borderless or
windowed, switching between them at runtime, size and position, and which
monitor it's on. It also reports what the user and the OS do to the window
(focus, resize, move) as events, and keeps a `WindowState` resource current.

## What you need

```yaml
dependencies:
  fledge_window: ^0.7.0
```

- **Flutter 3.50+** (Dart 3.14+).
- **Desktop only**: Windows, macOS and Linux. The plugin is built on
  [`window_manager`](https://pub.dev/packages/window_manager) and
  [`screen_retriever`](https://pub.dev/packages/screen_retriever), which
  support only those three. `window_manager` imports `dart:io`, so an app that
  depends on `fledge_window` doesn't build for the web. On mobile the native
  calls fail: the plugin sends a `WindowOperationFailed` for `'init'` and
  does nothing else.
- **A Flutter app**: the plugin talks to the window over platform channels,
  so the Flutter binding must exist before the first tick. That's the case
  when a game widget ticks the app (see
  [Rendering overview](/docs/rendering/overview)). If you call `app.run()`
  from `main` instead, call `WidgetsFlutterBinding.ensureInitialized()`
  first.

## Quick start

```dart
final app = App()
  ..addPlugin(WallTimePlugin())
  ..addPlugin(WindowPlugin.fullscreen(title: 'My Game'));
```

On the first frame the plugin initializes the window, reads the connected
displays, applies the mode, title and size limits, then shows and focuses the
window.

## Window modes

| `WindowMode` | What it is |
|---|---|
| `fullscreen` | Exclusive fullscreen on the target display |
| `borderless` | A frameless window covering the whole display. Alt-tabs faster and plays better with other monitors than exclusive fullscreen. **The default** |
| `windowed` | A normal window with a title bar, 1280×720 and centred on the display unless you say otherwise |

`WindowPlugin` has a constructor per mode:

```dart
App()
  ..addPlugin(WindowPlugin.fullscreen(title: 'My Game'));

App()
  ..addPlugin(WindowPlugin.borderless(title: 'My Game'));

App()
  ..addPlugin(
    WindowPlugin.windowed(
      title: 'My Game',
      size: const Size(1600, 900),
      minSize: const Size(800, 450),
    ),
  );
```

For anything else (a target monitor, a starting position, always-on-top, a
fixed-size window) pass a `WindowConfig`:

```dart
App()
  ..addPlugin(
    const WindowPlugin(
      config: WindowConfig(
        mode: WindowMode.windowed,
        title: 'My Game',
        windowedSize: Size(1920, 1080),
        windowedPosition: Offset(100, 100), // null: centred
        targetDisplay: 1, // null: the primary display
        minSize: Size(800, 600),
        maxSize: null, // no maximum
        alwaysOnTop: false,
        resizable: true,
      ),
    ),
  );
```

`WindowConfig.fullscreen(title:, targetDisplay:)`,
`WindowConfig.borderless(title:, targetDisplay:)` and
`WindowConfig.windowed(title:, size:, position:, minSize:, maxSize:,
resizable:)` are shorthands.

## Changing the window at runtime

Window changes are requests: each helper on `World` sends an event that the
plugin picks up at the start of the next frame. It starts the native window
calls in the background without waiting for them, and applies the result
(updating `WindowState` and sending the result event) on the first frame
after the OS has finished. Requests are applied one at a time, in order, so
each one sees the state the previous one left.

| Helper | Request event | Effect |
|---|---|---|
| `world.setWindowMode(mode, targetDisplay:)` | `SetWindowModeRequest` | Switch mode, optionally onto another display |
| `world.toggleFullscreen()` | `SetWindowModeRequest` | Fullscreen ↔ windowed (borderless goes to fullscreen) |
| `world.toggleBorderless()` | `SetWindowModeRequest` | Borderless ↔ windowed (fullscreen goes to borderless) |
| `world.cycleWindowMode()` | `SetWindowModeRequest` | Windowed → borderless → fullscreen → windowed |
| `world.setWindowSize(size)` | `SetWindowSizeRequest` | Resize. Windowed mode only |
| `world.setWindowPosition(offset)` | `SetWindowPositionRequest` | Move. Windowed mode only |

Size and position requests are ignored outside windowed mode, and a request
for what the window already is does nothing. When the window leaves windowed
mode its size and position are saved, and returning to windowed restores
them.

A system that toggles fullscreen on an [input](/docs/platform/input) action:

```dart
const toggleFullscreen = ActionId('toggleFullscreen');

final toggleSystem = FunctionSystem(
  'toggleFullscreen',
  resourceReads: {ActionState, WindowState},
  eventWrites: {SetWindowModeRequest},
  run: (world) {
    final actions = world.getResource<ActionState>();
    if (actions != null && actions.justPressed(toggleFullscreen)) {
      world.toggleFullscreen();
    }
  },
);

final app = App()
  ..addPlugin(WindowPlugin.borderless(title: 'My Game'))
  ..addSystem(toggleSystem, schedule: Schedules.update);
```

The toggles read `WindowState`, so declare it in `resourceReads`.

### Closing the app

`AppWindowCommands` adds `close()` to `App`: it stops the game loop and
closes the window, for an "Exit to desktop" button.

```dart
Future<void> exitToDesktop(App app) async {
  await app.close();
}
```

## Window events

| Event | Sent when |
|---|---|
| `WindowModeChanged` (`previousMode`, `newMode`) | A mode request was applied |
| `WindowResized` (`previousSize`, `newSize`) | A size request was applied, or the user/OS resized the window |
| `WindowMoved` (`previousPosition`, `newPosition`) | A position request was applied, or the user/OS moved the window |
| `WindowFocusChanged` (`isFocused`) | The window gained or lost focus |
| `WindowOperationFailed` (`operation`, `reason`, `attemptedMode`) | A native window call threw or was rejected |

Events from the OS are queued as they arrive and applied on the next frame.
When the OS reports a change that `WindowState` already shows (the echo of a
resize you requested, say) nothing extra is sent, so a programmatic change
produces one event, not two. A mode switch sends `WindowModeChanged` and
updates `WindowState.size` itself; read the size from `WindowState` after a
mode change rather than waiting for a `WindowResized`.

Like all events, these are readable on the frame after they're sent (see
[Events](/docs/ecs/events#timing-events-are-double-buffered)). A request made
in frame N is started in frame N + 1 and applied on the first frame after
the OS finishes it (usually N + 2); its result event (or
`WindowOperationFailed`) is readable the frame after that. A failed request
leaves `WindowState` unchanged.

```dart
class PauseOnFocusLossSystem extends System {
  static const String systemName = 'pauseOnFocusLoss';

  @override
  SystemMeta get meta => const SystemMeta(
    name: systemName,
    eventReads: {WindowFocusChanged, WindowResized},
  );

  @override
  void run(World world) {
    for (final event in world.eventReader<WindowFocusChanged>().read()) {
      if (!event.isFocused) {
        // Open the pause menu.
      }
    }
    for (final event in world.eventReader<WindowResized>().read()) {
      // Re-layout for event.newSize.
    }
  }
}
```

`fledge_audio` pauses on focus loss by itself, from Flutter's app lifecycle;
see [Audio](/docs/platform/audio#pausing).

### Failures

Every native call is guarded. If one throws, the plugin sends
`WindowOperationFailed` and leaves `WindowState` as it was, so the state
always matches what the OS actually applied. `operation` is one of `'init'`,
`'syncDisplays'`, `'setTitle'`, `'setMinimumSize'`, `'setMaximumSize'`,
`'setResizable'`, `'setAlwaysOnTop'`, `'setMode'`, `'show'`, `'focus'`,
`'listen'`, `'resize'` or `'reposition'`; `attemptedMode` is set for mode
changes.

```dart
final logFailures = FunctionSystem(
  'logWindowFailures',
  eventReads: {WindowOperationFailed},
  run: (world) {
    for (final f in world.eventReader<WindowOperationFailed>().read()) {
      print('window ${f.operation} failed: ${f.reason}');
    }
  },
);
```

During startup, a failure of the backend initialization, the display query or
the initial mode stops the setup there; a failed title or size limit is
reported and setup carries on.

## Window state and displays

`world.windowState` (the `WindowState` resource):

| Field | Meaning |
|---|---|
| `mode` | The current `WindowMode` |
| `size`, `position` | Logical size and screen position |
| `isFocused`, `isVisible`, `isMinimized`, `isMaximized` | Kept current from the OS |
| `displayIndex` | The display the window was last placed on |
| `savedWindowedSize`, `savedWindowedPosition` | What windowed mode restores to |
| `isFullDisplay` | `true` in fullscreen or borderless |

`world.displayInfo` (the `DisplayInfo` resource) lists the monitors.
`displays`, `primary`, `primaryIndex`, `getDisplay(index)` and
`isInitialized` (false until the first frame has read them). Each `Display`
has:

| Field | Meaning |
|---|---|
| `index` | Position in `displays`, for `targetDisplay` |
| `name` | The monitor's name |
| `size` | Full resolution |
| `bounds` | The usable area (without taskbar or menu bar) in virtual-screen coordinates, so it includes the monitor's offset in a multi-monitor setup |
| `scaleFactor` | DPI scale: 1.0, 1.5, 2.0… |
| `refreshRate` | In Hz, from Flutter's engine (`PlatformDispatcher.displays`), matched to the display by its physical size. `Display.unknownRefreshRate` (60.0) if no engine display matches. `View.of(context).display.refreshRate` gives the display your game's view is on |
| `isPrimary` | Whether it's the primary display |

The display list is re-read in the background every 5 seconds, so a monitor
plugged in or removed shows up within a few seconds.

```dart
void describeDisplays(World world) {
  final info = world.displayInfo;
  if (info == null || !info.isInitialized) return;
  for (final display in info.displays) {
    print('${display.index}: $display at ${display.bounds}');
  }
  print('window: ${world.windowState}');
}
```

## Systems

All four run in `Schedules.first`, in the `FirstSets.platform` phase (after
frame-start bookkeeping, before input polling). Order your own systems
against them with these constants:

| System | `systemName` | Job |
|---|---|---|
| `WindowInitSystem` | `WindowInitSystem.systemName` | First frame only: sets the window up and starts listening to the OS |
| `DisplaySyncSystem` | `DisplaySyncSystem.systemName` | Re-reads the displays every 5 s, without waiting on the platform |
| `WindowEventSystem` | `WindowEventSystem.systemName` | Applies size, position and mode requests |
| `WindowOsEventSystem` | `WindowOsEventSystem.systemName` | Applies queued OS changes to `WindowState` and sends their events |

No system waits on the platform inside a frame after the first.
`WindowInitSystem` awaits its setup calls on the first frame only, and returns
at once on every later frame. `WindowEventSystem` is synchronous: a frame with
no requests does no work, and requests run in the background with their
results applied on a later frame.

The plugin also inserts a `WindowOsEvents` resource, the queue the OS
callbacks feed. Tests and custom platform layers can call its
`focusChanged`, `resized`, `moved`, `minimizedChanged` and
`maximizedChanged` directly to simulate the OS.

## Limitations

- Desktop only (see [What you need](#what-you-need)). No web fullscreen API,
  no mobile support.
- `Display.refreshRate` falls back to 60.0 for a display Flutter's engine doesn't report (matched by physical size); see [Window state and displays](#window-state-and-displays).
- One window. There's no multi-window support.

## See also

- [Input](/docs/platform/input): bind a key to `toggleFullscreen`
- [Audio](/docs/platform/audio): pause on focus loss
- [Cameras](/docs/rendering/cameras): viewport size and letterboxing
- [API reference](https://pub.dev/documentation/fledge_window/latest/)
