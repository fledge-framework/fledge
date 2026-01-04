# Changelog

## [0.1.5] - 2026-01-04



## [0.1.4] - 2026-01-04



## [0.1.3] - 2026-01-04

## [Unreleased]

### Bug Fixes

- **fledge_render_2d:** Fix null safety error on private field



## [0.1.2] - 2026-01-03

## [Unreleased]

### Bug Fixes

- **fledge_input:** Persist input transition flags through the entire frame
- Update dependencies to latest stable versions
- **fledge:** Update dependencies, upgrade melos to v7

### Miscellaneous

- **license:** Remove whitespace from license files
- Update license text
- Bump versions



All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
