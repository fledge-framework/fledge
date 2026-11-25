import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:fledge_ecs/fledge_ecs.dart' hide State;
import 'package:gamepads/gamepads.dart';

import '../action/input_binding.dart';
import '../context/context_registry.dart';
import '../cursor/cursor_mode.dart';
import '../cursor/cursor_state.dart';
import '../cursor/pointer_lock_delegate.dart';
import '../device/active_input_device.dart';
import '../device/gamepad_family.dart';
import '../device/gamepad_rumble.dart';
import '../input_settings.dart';
import '../raw/keyboard_state.dart';
import '../raw/mouse_state.dart';
import '../raw/gamepad_source.dart';
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
///   child: FledgeRenderView(app: app),
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
  ///
  /// Gamepads are polled only when this and the plugin's
  /// `InputPlugin.enableGamepad` (held in the [InputSettings] resource) are
  /// both true. Read once, when the widget mounts.
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

  /// Where gamepad input comes from: the `gamepads` plugin when omitted, or
  /// a fake in tests. Read once, when the widget mounts; the widget owns it
  /// and disposes it.
  final GamepadSource? gamepadSource;

  /// Whether the widget takes keyboard focus: on mount ([autofocus]), when
  /// the mouse enters ([focusOnHover]) and on every press inside it. False
  /// leaves focus to an overlay over the game (a menu with its own focus
  /// navigation); the game then hears no keys. Turning it back to true
  /// takes focus again and catches the keyboard up
  /// ([KeyboardState.sync]), so a key let go in the menu isn't stuck down.
  final bool claimFocus;

  /// Whether to drop controller input while the app isn't the active one
  /// (alt-tabbed away): some platforms keep reading pads in the background.
  /// What a pad held when the app went inactive is let go.
  final bool ignoreGamepadWhenInactive;

  const InputWidget({
    super.key,
    required this.world,
    required this.child,
    this.autofocus = true,
    this.enableGamepad = true,
    this.focusOnHover = true,
    this.pointerLockDelegate,
    this.focusNode,
    this.gamepadSource,
    this.claimFocus = true,
    this.ignoreGamepadWhenInactive = false,
  });

  @override
  State<InputWidget> createState() => _InputWidgetState();
}

class _InputWidgetState extends State<InputWidget> {
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  late final bool _ownsFocusNode = widget.focusNode == null;
  StreamSubscription<GamepadEvent>? _gamepadSubscription;
  StreamSubscription<GamepadConnectionEvent>? _connectionSubscription;
  GamepadSource? _gamepadSource;

  /// Maps raw platform keys to standard button and axis names.
  final GamepadNormalizer _normalizer = GamepadNormalizer();

  /// Pointer lock stream subscription for FPS-style mouse capture.
  StreamSubscription<PointerLockDelta>? _pointerLockSubscription;

  /// The app is the active one (for [InputWidget.ignoreGamepadWhenInactive]).
  bool _appActive = true;
  AppLifecycleListener? _lifecycle;

  /// Mouse movement since the device in use was last something else: a
  /// mouse nudged by a desk doesn't take over from a controller.
  double _mouseTravel = 0;
  static const _mouseSwitchDistance = 8.0;

  KeyboardState? get _keyboard => widget.world.getResource<KeyboardState>();
  ActiveInputDevice? get _device =>
      widget.world.getResource<ActiveInputDevice>();
  GamepadRumble? get _rumble => widget.world.getResource<GamepadRumble>();
  MouseState? get _mouse => widget.world.getResource<MouseState>();
  GamepadState? get _gamepad => widget.world.getResource<GamepadState>();
  CursorState? get _cursor => widget.world.getResource<CursorState>();
  InputContextRegistry? get _contextRegistry =>
      widget.world.getResource<InputContextRegistry>();

  CursorMode _currentCursorMode = CursorMode.visible;
  String? _lastContextName;

  /// The [MouseState] buttons each pointer holds down, by pointer id, so a
  /// release lets go of exactly those.
  final Map<int, Set<int>> _pointerButtons = {};

  /// Flutter's button bits and the [MouseState] index each maps to.
  static const _buttonIndices = [
    (kPrimaryButton, 0),
    (kMiddleMouseButton, 1),
    (kSecondaryButton, 2),
    (kBackMouseButton, 3),
    (kForwardMouseButton, 4),
  ];

  @override
  void initState() {
    super.initState();
    _initializeGamepads();
    _initializeCursor();
    _focusNode.addListener(_onFocusChange);
    HardwareKeyboard.instance.addHandler(_noteKeyboard);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_notePointer);
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
  }

  @override
  void didUpdateWidget(InputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.claimFocus && !oldWidget.claimFocus && !_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
  }

  /// Back in focus: the keyboard as it is now, since key events went
  /// elsewhere meanwhile.
  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _keyboard?.sync(HardwareKeyboard.instance.logicalKeysPressed);
    }
  }

  /// Notes the keyboard as the device in use; never consumes the event.
  bool _noteKeyboard(KeyEvent event) {
    if (event is KeyDownEvent) _noteDevice(InputDeviceKind.keyboard);
    return false;
  }

  /// Notes the mouse as the device in use: a click, a scroll, or a real
  /// move (not a virtual pointer driven by a controller).
  void _notePointer(PointerEvent event) {
    if (event.kind != PointerDeviceKind.mouse) return;
    final device = _device;
    if (device == null || device.gamepadPointerDevices.contains(event.device)) {
      return;
    }
    if (event is PointerDownEvent || event is PointerSignalEvent) {
      _noteDevice(InputDeviceKind.mouse);
    } else if (event is PointerHoverEvent || event is PointerMoveEvent) {
      if (device.kind == InputDeviceKind.mouse) return;
      _mouseTravel += event.delta.distance;
      if (_mouseTravel >= _mouseSwitchDistance) {
        _noteDevice(InputDeviceKind.mouse);
      }
    }
  }

  void _noteDevice(InputDeviceKind kind, {String? gamepadId}) {
    final device = _device;
    if (device == null) return;
    if (kind != InputDeviceKind.mouse) _mouseTravel = 0;
    GamepadFamily? family;
    if (gamepadId != null) {
      final pad = _gamepad?.get(gamepadId);
      family = detectGamepadFamily(
        pad?.name ?? '',
        vendorId: pad?.vendorId,
        productId: pad?.productId,
      );
    }
    device.note(kind, gamepadId: gamepadId, family: family);
  }

  void _onLifecycle(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (active == _appActive) return;
    _appActive = active;
    if (!active && widget.ignoreGamepadWhenInactive) {
      // Nothing a pad held stays held while we're away.
      for (final pad in _gamepad?.gamepads.values ?? <SingleGamepadState>[]) {
        pad.releaseAll();
      }
    }
  }

  void _initializeCursor() {
    final cursor = _cursor;
    if (cursor != null) {
      cursor.onModeChanged = _onCursorModeChanged;
      _currentCursorMode = cursor.mode;
      if (_currentCursorMode == CursorMode.locked) _startPointerLock();
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
    final settings = widget.world.getResource<InputSettings>();
    if (settings != null && !settings.enableGamepad) return;
    final source = _gamepadSource =
        widget.gamepadSource ?? PluginGamepadSource();

    // Input as it happens, and pads coming and going.
    _gamepadSubscription = source.events.listen(_handleGamepadEvent);
    _connectionSubscription = source.connections.listen(_handleConnection);

    // Rumble goes to the pad, fire and forget.
    final rumble = _rumble;
    if (rumble != null) {
      rumble.handler = (effect, id) {
        unawaited(
          source.rumble(
            id,
            low: effect.low,
            high: effect.high,
            duration: effect.duration,
          ),
        );
      };
      rumble.stopHandler = (id) => unawaited(source.stopRumble(id));
    }

    // The pads connected already, by name.
    _listGamepads();
  }

  /// Names every connected pad (and its USB ids) from the source. Run at
  /// mount and on every connect, so a pad first seen through an event, or
  /// plugged in later, is named rather than left as its opaque id.
  Future<void> _listGamepads() async {
    final source = _gamepadSource;
    if (source == null) return;
    final List<GamepadInfo> gamepads;
    try {
      gamepads = await source.list();
    } catch (e) {
      debugPrint('Gamepads unavailable: $e');
      return;
    }
    if (!mounted) return;
    final state = _gamepad;
    if (state == null) return;
    for (final gamepad in gamepads) {
      state.connect(
        gamepad.id,
        name: gamepad.name,
        vendorId: gamepad.vendorId,
        productId: gamepad.productId,
      );
    }
    // The pad in use may have just been named: its family with it.
    final device = _device;
    final active = device?.gamepadId;
    if (device != null && device.isGamepad && active != null) {
      _noteDevice(InputDeviceKind.gamepad, gamepadId: active);
    }
  }

  void _handleGamepadEvent(GamepadEvent event) {
    if (widget.ignoreGamepadWhenInactive && !_appActive) return;
    _gamepad?.applyEvent(event, _normalizer);
    // A press, or a stick or trigger pushed well over: the controller is in
    // use (resting drift doesn't count).
    if (event.value.abs() >= 0.5) {
      _noteDevice(InputDeviceKind.gamepad, gamepadId: event.gamepadId);
    }
  }

  void _handleConnection(GamepadConnectionEvent event) {
    final state = _gamepad;
    if (state == null) return;
    switch (event.type) {
      case GamepadConnectionEventType.connected:
        state.connect(event.gamepadId, name: event.name);
        _listGamepads();
      case GamepadConnectionEventType.disconnected:
        // Nothing it held stays held.
        state.disconnect(event.gamepadId);
        _normalizer.removeDevice(event.gamepadId);
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
    final mouse = _mouse;
    if (mouse == null) return;
    mouse.onMove(event.localPosition.dx, event.localPosition.dy);
    if (_pointerButtons.containsKey(event.pointer) || event.buttons != 0) {
      _syncPointerButtons(mouse, event.pointer, event.buttons);
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    // Reclaim focus on every pointer-down. A no-op if we already have
    // focus; otherwise it pulls focus back from anything up the tree
    // that tried to steal it on this click (e.g. a `SelectableRegion`
    // that wants to start tracking text selection). Not while an overlay
    // has the focus on purpose ([InputWidget.claimFocus]).
    if (widget.claimFocus && !_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }

    final mouse = _mouse;
    if (mouse == null) return;

    // Record where the press happened. A touch tap, or a pointer that
    // jumps into the widget and presses straight away, arrives without a
    // preceding hover/move, so the last known position would be stale.
    mouse.onMove(event.localPosition.dx, event.localPosition.dy);

    _syncPointerButtons(mouse, event.pointer, event.buttons);
  }

  /// Presses the buttons newly down in [buttons] for [pointer] and lets go
  /// of the ones it held that no longer are. A second button pressed while
  /// one is held arrives as a move with more [buttons], not a new down.
  void _syncPointerButtons(MouseState mouse, int pointer, int buttons) {
    final held = _pointerButtons.putIfAbsent(pointer, () => <int>{});
    for (final (bit, index) in _buttonIndices) {
      final down = buttons & bit != 0;
      if (down && !held.contains(index)) {
        if (!_heldElsewhere(index)) mouse.buttonDown(index);
        held.add(index);
      } else if (!down && held.remove(index)) {
        if (!_heldElsewhere(index)) mouse.buttonUp(index);
      }
    }
    if (held.isEmpty) _pointerButtons.remove(pointer);
  }

  /// Lets go of every button [pointer] held.
  void _releasePointer(int pointer) {
    final held = _pointerButtons.remove(pointer);
    final mouse = _mouse;
    if (held == null || mouse == null) return;
    for (final index in held) {
      if (!_heldElsewhere(index)) mouse.buttonUp(index);
    }
  }

  /// Whether any pointer holds the [MouseState] button [index] (two
  /// fingers both count as button 0).
  bool _heldElsewhere(int index) =>
      _pointerButtons.values.any((held) => held.contains(index));

  void _handlePointerUp(PointerUpEvent event) {
    _mouse?.onMove(event.localPosition.dx, event.localPosition.dy);
    _releasePointer(event.pointer);
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _releasePointer(event.pointer);
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
    _focusNode.removeListener(_onFocusChange);
    if (_ownsFocusNode) _focusNode.dispose();
    HardwareKeyboard.instance.removeHandler(_noteKeyboard);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_notePointer);
    _lifecycle?.dispose();
    _gamepadSubscription?.cancel();
    _connectionSubscription?.cancel();
    final rumble = _rumble;
    if (rumble != null) {
      rumble
        ..handler = null
        ..stopHandler = null;
    }
    _gamepadSource?.dispose();
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
      // Visible: whatever cursor the app shows around the game (a custom
      // one, say), or the system arrow when it shows none.
      CursorMode.visible => MouseCursor.defer,
      CursorMode.hidden => SystemMouseCursors.none,
      CursorMode.locked => SystemMouseCursors.none,
    };
  }

  @override
  Widget build(BuildContext context) {
    // InputPlugin keeps CursorState in step with the active context as it
    // changes; this also covers a registry inserted without the plugin.
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
      onPointerCancel: _handlePointerCancel,
      onPointerSignal: _handlePointerSignal,
      child: child,
    );

    // Add mouse region for hover focus and cursor control
    child = MouseRegion(
      cursor: _getCursor(),
      onEnter: widget.focusOnHover && widget.claimFocus
          ? (_) => _focusNode.requestFocus()
          : null,
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
        if (widget.claimFocus && !_focusNode.hasFocus) {
          _focusNode.requestFocus();
        }
      },
      child: child,
    );

    // Wrap with keyboard focus
    child = Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus && widget.claimFocus,
      onKeyEvent: _handleKeyEvent,
      child: child,
    );

    return child;
  }
}
