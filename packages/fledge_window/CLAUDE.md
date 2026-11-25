# fledge_window

## Purpose
Window management: modes, display info, and runtime window configuration.

## Status: Functional

## Stats
- Source: 11 files, ~1,560 LOC
- Tests: 2 files (failure event + geometry math; schedule ordering)
- TODOs in code: 0

## What Works
- Three window modes (windowed, fullscreen, borderless)
- Display info querying (resolution, refresh rate)
- Runtime window mode switching
- Window event system (resize, move, focus)
- Window configuration (title, size, position)
- **Error-safe native calls** — every `window_manager` / `screen_retriever` call is wrapped; on failure a `WindowOperationFailed` event is emitted and `WindowState` is left unchanged instead of becoming inconsistent

## Gaps
- **[P2]** No integration tests that drive real `window_manager` — pure-logic tests only (failure plumbing is covered via `WindowOperationFailed` shape + geometry math)

## Action Items
1. Add integration tests against a real `window_manager` (or a mock implementing the same surface) covering mode transitions end-to-end
2. Consider exposing a `Future<bool>` return from command extensions so callers can `await` and branch on success without listening to events

## Architecture Notes
- **Entry point**: `lib/fledge_window.dart` (barrel export)
- **WindowPlugin** (`lib/src/plugin.dart`): Registers window events, inserts `WindowState` / `DisplayInfo`, and adds all three systems to the `FirstSets.platform` phase of `Schedules.first` (init → display sync → event handler). The phase chain orders them after frame bookkeeping (`WallTimeUpdateSystem`) and before input/content; within the phase the order is declared via `after:` on each system's `SystemMeta`, not inherited from registration order — `test/ordering_test.dart` asserts `checkScheduleOrdering()` is empty.
- **WindowMode** (`lib/src/window_mode.dart`): Enum — windowed, fullscreen, borderless.
- **WindowConfig** (`lib/src/window_config.dart`): Initial window settings (title, size, mode).
- **Resources** (`lib/src/resources/`): `WindowState` (current size, position, mode), `DisplayInfo` (list of `Display`s / monitor capabilities).
- **Systems** (`lib/src/systems/`):
  - `WindowInitSystem`: Not exclusive — declares `resourceWrites: {DisplayInfo, WindowState}` and `eventWrites: {WindowOperationFailed}`; name via `WindowInitSystem.systemName` (`'WindowInitSystem'`). Creates window with initial config. `run` returns a Future only on the first call; later calls return synchronously. Critical setup (`ensureInitialized`, display enumeration, initial mode) aborts init on failure; non-critical config (title, min/max size, always-on-top) reports via `WindowOperationFailed` and continues.
  - `WindowEventSystem`: Synchronous; processes resize/move/mode change requests one at a time, starting the native calls in the background and applying the outcome (state + event) on the first frame after they finish. A frame with no requests does no native work. Each request is guarded — on native failure the `WindowState` stays at its pre-request values and a `WindowOperationFailed` event is emitted instead of the usual `WindowModeChanged`/`WindowResized`/`WindowMoved`.
  - `DisplaySyncSystem`: Polls for monitor changes every 5s. On failure the cached `DisplayInfo` is preserved.
  - Refresh rates: `screen_retriever` 0.2 has none, so `matchRefreshRates` (`lib/src/resources/refresh_rate.dart`) takes them from `PlatformDispatcher.displays`, matching by physical size (logical size × scale, or raw size), identical monitors in order, a lone engine display covering an unmatched one, else `Display.unknownRefreshRate`.
  - `WindowEventSystem` / `DisplaySyncSystem` expose `systemName` constants (`'WindowEventSystem'` / `'DisplaySyncSystem'`).
- **Events** (`lib/src/events/window_events.dart`): Requests (`SetWindowModeRequest`, `SetWindowSizeRequest`, `SetWindowPositionRequest`) and notifications (`WindowModeChanged`, `WindowResized`, `WindowMoved`, `WindowFocusChanged`, `WindowOperationFailed`).
- **Commands** (`lib/src/commands/window_commands.dart`): `WindowCommands` extension on `World` and `AppWindowCommands` on `App` that write the request events. Fire-and-forget; failures surface as `WindowOperationFailed` events.
- **Failure events**: `WindowOperationFailed` carries `operation` (`'init'`, `'setMode'`, `'resize'`, `'reposition'`, `'syncDisplays'`, `'setTitle'`, …), `reason` (the exception `toString`), and optional `attemptedMode` when the failure originated from a mode change.
- **Tests**: Flutter package — run with `flutter test`.
