import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fledge_ecs/fledge_ecs.dart' hide State;
import 'package:gamepads/gamepads.dart';

import '../raw/keyboard_state.dart';
import '../raw/mouse_state.dart';
import '../raw/gamepad_state.dart';

/// A widget that captures all input for a Fledge game.
///
/// Wraps the game content and injects raw input into ECS resources.
/// Uses Focus for keyboard, Listener for mouse, and gamepads package
/// for gamepad input.
///
/// ## Usage
///
/// ```dart
/// InputWidget(
///   world: app.world,
///   child: GameWidget(app: app),
/// )
/// ```
class InputWidget extends StatefulWidget {
  /// The ECS world to inject input into.
  final World world;

  /// The game content widget.
  final Widget child;

  /// Whether to automatically focus on mount.
  final bool autofocus;

  /// Whether to enable gamepad polling.
  final bool enableGamepad;

  /// Whether to request focus when mouse enters the widget.
  final bool focusOnHover;

  const InputWidget({
    super.key,
    required this.world,
    required this.child,
    this.autofocus = true,
    this.enableGamepad = true,
    this.focusOnHover = true,
  });

  @override
  State<InputWidget> createState() => _InputWidgetState();
}

class _InputWidgetState extends State<InputWidget> {
  final FocusNode _focusNode = FocusNode();
  StreamSubscription<GamepadEvent>? _gamepadSubscription;

  KeyboardState? get _keyboard => widget.world.getResource<KeyboardState>();
  MouseState? get _mouse => widget.world.getResource<MouseState>();
  GamepadState? get _gamepad => widget.world.getResource<GamepadState>();

  @override
  void initState() {
    super.initState();
    _initializeGamepads();
  }

  void _initializeGamepads() {
    if (!widget.enableGamepad) return;

    // Listen for gamepad events
    _gamepadSubscription = Gamepads.events.listen(_handleGamepadEvent);

    // Query initial gamepads
    Gamepads.list().then((gamepads) {
      final gamepadState = _gamepad;
      if (gamepadState == null) return;

      for (final gamepad in gamepads) {
        gamepadState.getOrCreate(gamepad.id, gamepad.name);
      }
    });
  }

  void _handleGamepadEvent(GamepadEvent event) {
    final gamepadState = _gamepad;
    if (gamepadState == null) return;

    // Ensure gamepad exists
    final gamepad = gamepadState.getOrCreate(event.gamepadId, event.gamepadId);

    // Determine if this is a button or axis based on the key type
    if (event.type == KeyType.button) {
      gamepad.setButtonPressed(event.key, event.value > 0.5);
    } else {
      gamepad.setAxisValue(event.key, event.value);
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final keyboard = _keyboard;
    if (keyboard == null) return KeyEventResult.ignored;

    final key = event.logicalKey;

    if (event is KeyDownEvent) {
      keyboard.keyDown(key);
    } else if (event is KeyUpEvent) {
      keyboard.keyUp(key);
    }
    // Note: KeyRepeatEvent doesn't change pressed state

    return KeyEventResult.handled;
  }

  void _handlePointerHover(PointerHoverEvent event) {
    _mouse?.onMove(event.localPosition.dx, event.localPosition.dy);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    _mouse?.onMove(event.localPosition.dx, event.localPosition.dy);
  }

  void _handlePointerDown(PointerDownEvent event) {
    final mouse = _mouse;
    if (mouse == null) return;

    // Decode which button was pressed
    if (event.buttons & kPrimaryButton != 0) mouse.buttonDown(0);
    if (event.buttons & kSecondaryButton != 0) mouse.buttonDown(2);
    if (event.buttons & kMiddleMouseButton != 0) mouse.buttonDown(1);
    if (event.buttons & kBackMouseButton != 0) mouse.buttonDown(3);
    if (event.buttons & kForwardMouseButton != 0) mouse.buttonDown(4);
  }

  void _handlePointerUp(PointerUpEvent event) {
    final mouse = _mouse;
    if (mouse == null) return;

    // On pointer up, the button field is the button that was released
    mouse.buttonUp(event.pointer);

    // More reliable: check which buttons are no longer pressed
    // Since buttons field is 0 on up, we need to track differently
    // For now, release all buttons that might have been pressed
    if (!(event.buttons & kPrimaryButton != 0)) mouse.buttonUp(0);
    if (!(event.buttons & kSecondaryButton != 0)) mouse.buttonUp(2);
    if (!(event.buttons & kMiddleMouseButton != 0)) mouse.buttonUp(1);
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      _mouse?.onScroll(event.scrollDelta.dx, event.scrollDelta.dy);
    }
  }

  void _handlePointerExit(PointerExitEvent event) {
    // Optionally clear mouse buttons when pointer leaves
    // _mouse?.clear();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _gamepadSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = widget.child;

    // Wrap with mouse listener
    child = Listener(
      onPointerHover: _handlePointerHover,
      onPointerMove: _handlePointerMove,
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      onPointerSignal: _handlePointerSignal,
      child: child,
    );

    // Add mouse region for hover focus
    if (widget.focusOnHover) {
      child = MouseRegion(
        onEnter: (_) => _focusNode.requestFocus(),
        onExit: _handlePointerExit,
        child: child,
      );
    }

    // Wrap with keyboard focus
    child = Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _handleKeyEvent,
      child: child,
    );

    return child;
  }
}
