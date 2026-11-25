# fledge_input

## Purpose
Action-based input mapping with context switching, supporting keyboard, mouse, and gamepad.

## Status: Functional

## Stats
- Source: 22 files
- Tests: 10 files (and `focus_bridge_test`: focus moves and repeats, intents, direction precedence, no replay on enable, scrolling, the virtual pointer's hover, click and drag) (and `device_test`: the device in use, families and labels, rumble, claimFocus, key resync, background pads) (ordering, fixed latch, discard, rebinding, scroll and gamepad normalization, gamepad bindings (sticks, clamp, triggers, composites), gamepad connections and the button watcher, InputWidget)
- TODOs in code: 0

## What Works
- Action mapping system (bind physical inputs to named actions)
- Input context switching (e.g., menu vs. gameplay bindings)
- Keyboard input handling
- Mouse input with position tracking and button state
- Gamepad input: normalized standard names, connection tracking (names, USB ids, release on unplug), stick bindings with a radial deadzone, vector2 clamped to length 1, triggers as buttons, half-axis composites, `GamepadButtonWatcher` for reading pads outside the frame loop, an injectable `GamepadSource`
- Cursor mode management (visible, hidden, locked)
- InputWidget for Flutter integration (claimFocus, key resync, background pads ignored)
- The device in use (`ActiveInputDevice`), controller families and button labels, rumble (`GamepadRumble`)
- Menus on a controller: `GamepadFocusBridge` (pad → Flutter focus and intents) and `VirtualPointer` (a stick-driven pointer sending real mouse events)

## Gaps
- **[P1]** No context-switching tests
- Controller support (Tharsis Plateau's `art/plans/controller.md`): the framework side is done (FW-1..3)
- **[P2]** No input conflict detection (overlapping bindings silently coexist)

## Action Items
1. Add unit tests for action mapping and context resolution
2. Add tests for keyboard/mouse/gamepad state tracking
3. Add input conflict detection with warnings for overlapping bindings

## Architecture Notes
- **Entry point**: `lib/fledge_input.dart` (barrel export)
- **InputPlugin\<S\>** (`lib/src/plugin.dart`): Generic over a state enum. Registers 3–4 systems and all resources. `stateBindings` map auto-activates contexts on state change (adds `ContextUpdateSystem<S>` in `Schedules.first` only when non-empty).
- **ActionState** (`lib/src/action/action_state.dart`): Primary game-facing resource — resolved actions for the current frame. ActionValue is sealed: `ButtonValue`, `AxisValue`, `Vector2Value`.
- **InputMap** (`lib/src/action/input_map.dart`): Immutable config mapping physical inputs to logical actions via fluent builder. `BindingSource` sealed hierarchy: KeyboardBinding, MouseButtonBinding, MouseAxisBinding, GamepadButtonBinding, GamepadAxisBinding. Composite bindings combine 4 directional sources into Vector2.
- **InputContext** (`lib/src/context/input_context.dart`): Named config (map + cursor mode + priority). `InputContextRegistry` (`lib/src/context/context_registry.dart`) manages state→context mapping and manual push/pop stack.
- **Raw input** (`lib/src/raw/`): `KeyboardState`, `MouseState`, `GamepadState`. `ButtonInputState` tracks frame-aware transitions: `beginFrame()` / `endFrame()` ensure justPressed/justReleased stability across async Flutter events.
- **Cursor** (`lib/src/cursor/`): `CursorMode` enum (visible, hidden, locked). `CursorState` tracks effective mode (context + override). Optional `PointerLockDelegate` for FPS-style pointer lock.
- **InputWidget** (`lib/src/widget/input_widget.dart`): Flutter StatefulWidget using Focus (keyboard), Listener (mouse), Gamepads.events (gamepad). Accepts an optional caller-owned `FocusNode` so games can observe focus state (pause-on-blur). `onKeyEvent` returns `KeyEventResult.handled` only for keys present in the active `InputMap` — unbound keys return `ignored` so ancestor shortcut handlers (e.g. `Ctrl+K`) still bubble. Subtree is wrapped in `SelectionContainer.disabled` (no text selection inside a game) and a `GestureDetector` that wins the tap gesture arena, which keeps ancestor `SelectableRegion`s from stealing focus on click. `_handlePointerDown` reclaims focus if it was lost out-of-band between pointer events.
- **Three-step pipeline**: (1) `InputPollingSystem` (`Schedules.first`) — beginFrame on raw states. (2) `ActionResolutionSystem` (`Schedules.first`, declares `after: [InputPollingSystem.systemName]`; `ContextUpdateSystem<S>` declares `before:` it) — reads active InputMap, combines multi-binding values, applies deadzone, writes ActionState. (3) `InputFrameEndSystem` (`Schedules.last`) — endFrame, clears transition flags.
- **System names**: `InputPollingSystem.systemName = 'inputPolling'`, `ActionResolutionSystem.systemName = 'actionResolution'`, `InputFrameEndSystem.systemName = 'inputFrameEnd'`. `ContextUpdateSystem<S>` is named `'contextUpdate<S>'` (type-dependent, no constant).
- **Multi-binding aggregation**: Axis actions sum values; button actions use phase priority (justPressed > held > justReleased > up).
- **Schedule ordering rule**: a game system that turns `ActionState` into `Velocity` (or anything the physics plugin touches) should live in `Schedules.preUpdate` (or `Schedules.fixedPreUpdate` when physics runs in `PhysicsMode.fixed`) or declare `before: [CollisionResolutionSystem.systemName]`. Otherwise the scheduler may run physics first inside the same schedule and the player walks through walls. `App.checkScheduleOrdering()` in `fledge_ecs` flags the class of bug in tests.
