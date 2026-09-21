# Changelog

## [0.2.0] - 2026-09-20

### Changed

- Consumer migration to the new `schedule:` API (previously `stage:`).


## [0.1.14] - 2026-04-14

## [0.1.13] - 2026-04-14



## [0.1.12] - 2026-04-14

## [0.1.11] - 2026-01-21



## [0.1.10] - 2026-01-06

## [0.1.9] - 2026-01-06



## [0.1.8] - 2026-01-06



## [0.1.7] - 2026-01-05

## [0.1.7] - 2026-01-05

### Miscellaneous

- Bump dependencies



## [0.1.6] - 2026-01-05



## [0.1.5] - 2026-01-04



## [0.1.4] - 2026-01-04



## [0.1.3] - 2026-01-04

## [0.1.2] - 2026-01-03

## [0.1.1] - 2025-01-03

### Fixed

- Fixed `justPressed` and `justReleased` detection for asynchronous input events
  - Flutter key/button events arrive asynchronously between frames
  - Previously, `beginFrame()` cleared transition flags before `ActionResolutionSystem` could read them
  - Added `endFrame()` method to clear flags AFTER systems have read input
  - Added `InputFrameEndSystem` that runs at `CoreStage.last` to call `endFrame()`
- Updated `ButtonInputState` to use `press()` and `release()` methods instead of direct property access
- Applied fix to `KeyboardState`, `MouseState`, and `GamepadState`

## [0.1.0] - 2025-01-02

### Added

- Initial release of fledge_input
- Action-based input system with named actions
- InputMap builder for declarative input configuration
- Keyboard input support with key bindings
- Mouse input support with button and position tracking
- Gamepad input support with button and stick bindings
- WASD and arrow key binding helpers
- Context switching based on game state
- InputWidget for Flutter integration
- ActionState resource for reading input in systems
