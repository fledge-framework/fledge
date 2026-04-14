import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fledge_ecs/fledge_ecs.dart' hide State;
import 'package:gamepads/gamepads.dart';

import '../action/input_binding.dart';
import '../context/context_registry.dart';
import '../cursor/cursor_mode.dart';
import '../cursor/cursor_state.dart';
import '../cursor/pointer_lock_delegate.dart';
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

  /// Optional delegate for pointer lock (FPS-style mouse capture).
  ///
  /// Provide a [PointerLockDelegate] implementation to enable
  /// [CursorMode.locked]. Without this, locked mode behaves like
  /// [CursorMode.hidden] (cursor hidden but no raw deltas).
  final PointerLockDelegate? pointerLockDelegate;

  /// Optional externally-owned [FocusNode].
  ///
  /// Provide one to observe focus changes (e.g. to pause the game when the
  /// widget loses focus) or to programmatically request focus from a parent.
  /// When omitted, the widget creates and disposes its own node.
  final FocusNode? focusNode;

  const InputWidget({
    super.key,
    required this.world,
    required this.child,
    this.autofocus = true,
    this.enableGamepad = true,
    this.focusOnHover = true,
    this.pointerLockDelegate,
    this.focusNode,
  });

  @override
  State<InputWidget> createState() => _InputWidgetState();
}

class _InputWidgetState extends State<InputWidget> {
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  late final bool _ownsFocusNode = widget.focusNode == null;
  StreamSubscription<GamepadEvent>? _gamepadSubscription;

  /// Pointer lock stream subscription for FPS-style mouse capture.
  StreamSubscription<PointerLockDelta>? _pointerLockSubscription;

  KeyboardState? get _keyboard => widget.world.getResource<KeyboardState>();
  MouseState? get _mouse => widget.world.getResource<MouseState>();
  GamepadState? get _gamepad => widget.world.getResource<GamepadState>();
  CursorState? get _cursor => widget.world.getResource<CursorState>();
  InputContextRegistry? get _contextRegistry =>
      widget.world.getResource<InputContextRegistry>();

  CursorMode _currentCursorMode = CursorMode.visible;
  String? _lastContextName;

  @override
  void initState() {
    super.initState();
    _initializeGamepads();
    _initializeCursor();
  }

  void _initializeCursor() {
    final cursor = _cursor;
    if (cursor != null) {
      cursor.onModeChanged = _onCursorModeChanged;
      _currentCursorMode = cursor.mode;
    }
  }

  void _onCursorModeChanged(CursorMode mode) {
    if (mounted) {
      final previousMode = _currentCursorMode;
      setState(() {
        _currentCursorMode = mode;
      });

      // Handle pointer lock state changes
      if (mode == CursorMode.locked && previousMode != CursorMode.locked) {
        _startPointerLock();
      } else if (mode != CursorMode.locked &&
          previousMode == CursorMode.locked) {
        _stopPointerLock();
      }
    }
  }

  void _updateCursorFromContext() {
    final registry = _contextRegistry;
    final cursor = _cursor;
    if (registry == null || cursor == null) return;

    final contextName = registry.activeContextName;
    if (contextName != _lastContextName) {
      _lastContextName = contextName;
      final context = registry.activeContext;
      if (context != null) {
        cursor.updateFromContext(context.cursorMode);
      }
    }
  }

  void _startPointerLock() {
    if (_pointerLockSubscription != null) return;

    final delegate = widget.pointerLockDelegate;
    if (delegate == null) {
      // No pointer lock delegate provided; locked mode will behave like hidden
      return;
    }

    try {
      final stream = delegate.start();
      _pointerLockSubscription = stream.listen((event) {
        final mouse = _mouse;
        if (mouse != null) {
          mouse.onLockedDelta(event.dx, event.dy);
        }
      });
    } catch (e) {
      debugPrint('Pointer lock not available: $e');
    }
  }

  void _stopPointerLock() {
    _pointerLockSubscription?.cancel();
    _pointerLockSubscription = null;
    widget.pointerLockDelegate?.stop();
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

    // Only consume keys that are bound in the active input map. Unbound keys
    // bubble up so ancestor Focus handlers (e.g. page-level shortcuts like
    // Ctrl+K) still work while the game has focus.
    return _isKeyBound(key) ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  bool _isKeyBound(LogicalKeyboardKey key) {
    final map = _contextRegistry?.activeMap;
    if (map == null) return false;
    for (final binding in map.bindings) {
      final source = binding.source;
      if (source is KeyboardBinding && source.key == key) return true;
    }
    for (final composite in map.compositeBindings) {
      for (final source in [
        composite.up,
        composite.down,
        composite.left,
        composite.right,
      ]) {
        if (source is KeyboardBinding && source.key == key) return true;
      }
    }
    return false;
  }

  void _handlePointerHover(PointerHoverEvent event) {
    _mouse?.onMove(event.localPosition.dx, event.localPosition.dy);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    _mouse?.onMove(event.localPosition.dx, event.localPosition.dy);
  }

  void _handlePointerDown(PointerDownEvent event) {
    // Reclaim focus on every pointer-down. A no-op if we already have
    // focus; otherwise it pulls focus back from anything up the tree
    // that tried to steal it on this click (e.g. a `SelectableRegion`
    // that wants to start tracking text selection).
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }

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
    if (_ownsFocusNode) _focusNode.dispose();
    _gamepadSubscription?.cancel();
    _stopPointerLock();
    final cursor = _cursor;
    if (cursor != null) {
      cursor.onModeChanged = null;
    }
    super.dispose();
  }

  /// No-op kept as a named member (rather than an inline closure in
  /// `build`) so `GestureDetector` can register the same callback
  /// across rebuilds — participates in the tap arena without any side
  /// effect.
  static void _noopTap() {}

  MouseCursor _getCursor() {
    return switch (_currentCursorMode) {
      CursorMode.visible => SystemMouseCursors.basic,
      CursorMode.hidden => SystemMouseCursors.none,
      CursorMode.locked => SystemMouseCursors.none,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Check for context changes and update cursor mode
    _updateCursorFromContext();

    // Games don't want text-selection semantics. Opt the entire input
    // subtree out of any ancestor `SelectionArea` so text inside the
    // game (HUD score, tooltips) isn't selectable.
    Widget child = SelectionContainer.disabled(child: widget.child);

    // Wrap with mouse listener
    child = Listener(
      onPointerHover: _handlePointerHover,
      onPointerMove: _handlePointerMove,
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      onPointerSignal: _handlePointerSignal,
      child: child,
    );

    // Add mouse region for hover focus and cursor control
    child = MouseRegion(
      cursor: _getCursor(),
      onEnter: widget.focusOnHover ? (_) => _focusNode.requestFocus() : null,
      onExit: _handlePointerExit,
      child: child,
    );

    // Claim the gesture arena for taps inside the game. Without this,
    // an ancestor `SelectableRegion` (from a `SelectionArea` used for
    // page-level text selection in docs or a marketing site) wins the
    // tap gesture and steals primary focus from the game on every
    // click — the user sees the game pause and the "Click to play"
    // overlay reappear. An empty `onTap` is enough to participate in
    // the arena; `onTapDown` also re-claims focus in the rare case
    // focus was lost out-of-band between pointer events.
    child = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _noopTap,
      onTapDown: (_) {
        if (!_focusNode.hasFocus) _focusNode.requestFocus();
      },
      child: child,
    );

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
