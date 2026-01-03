# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2025-01-03

### Fixed

- Fixed `justPressed` and `justReleased` detection for asynchronous input events
  - Flutter key/button events arrive asynchronously between frames
  - Previously, if an event arrived before `beginFrame()`, the transition was lost
  - Now explicitly tracks press/release transitions that persist until consumed
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
