import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kPrimaryButton, kSecondaryButton;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../raw/gamepad_state.dart';
import '../raw/gamepad_watcher.dart';
import 'gamepad_intents.dart';
import 'virtual_pointer.dart';

/// Lets a controller drive Flutter menus over a game: the d-pad and left
/// stick move focus, buttons become intents at the focused widget (A
/// activates, B dismisses, the shoulders switch tabs), the right stick
/// scrolls, and, given a [pointer], clicking the right stick shows a
/// pointer the stick moves, for anything not in focus order.
///
/// It reads the pads every Flutter frame with a ticker, outside the ECS
/// frame loop, so it works while the world is paused behind a menu. When it
/// becomes [enabled], everything pressed before is forgotten and a held
/// direction must be let go first: the A that opened a screen, or a B held
/// to run, never acts inside it.
///
/// Intents go to the primary focus (when it's inside the bridge), else to
/// the bridge's own child; handle them with `Actions` (`ActivateIntent`
/// already works on `FocusableActionDetector` and Material controls).
class GamepadFocusBridge extends StatefulWidget {
  const GamepadFocusBridge({
    super.key,
    required this.gamepads,
    required this.child,
    this.enabled = true,
    this.buttons = defaultButtons,
    this.repeatDelay = const Duration(milliseconds: 380),
    this.repeatInterval = const Duration(milliseconds: 90),
    this.stickPress = 0.5,
    this.stickRelease = 0.35,
    this.scrollSpeed = 900,
    this.pointer,
    this.pointerToggle = 'right_stick',
    this.pointerSpeed = 1100,
  });

  /// The pads (e.g. `() => world.getResource<GamepadState>()`).
  final GamepadState? Function() gamepads;

  final Widget child;

  /// Off, the bridge does nothing (gameplay has the pad).
  final bool enabled;

  /// What each button does (standard keys): an intent sent to the focus.
  final Map<String, Intent> buttons;

  /// A held direction repeats after [repeatDelay], every [repeatInterval].
  final Duration repeatDelay;
  final Duration repeatInterval;

  /// The left stick counts as a direction past [stickPress] and lets go
  /// below [stickRelease].
  final double stickPress;
  final double stickRelease;

  /// Logical pixels a second the right stick scrolls at full tilt.
  final double scrollSpeed;

  /// The virtual pointer to drive, if any.
  final VirtualPointerController? pointer;

  /// The button that shows and hides [pointer].
  final String pointerToggle;

  /// Logical pixels a second [pointer] moves at full tilt.
  final double pointerSpeed;

  static const defaultButtons = <String, Intent>{
    'a': ActivateIntent(),
    'b': DismissIntent(),
    'left_bumper': GamepadTabIntent(-1),
    'right_bumper': GamepadTabIntent(1),
    'x': GamepadButtonIntent('x'),
    'y': GamepadButtonIntent('y'),
    'start': GamepadButtonIntent('start'),
    'back': GamepadButtonIntent('back'),
  };

  @override
  State<GamepadFocusBridge> createState() => _GamepadFocusBridgeState();
}

class _GamepadFocusBridgeState extends State<GamepadFocusBridge>
    with SingleTickerProviderStateMixin {
  late final GamepadButtonWatcher _watcher = GamepadButtonWatcher(
    widget.gamepads,
  );
  late final Ticker _ticker = createTicker(_tick);
  final GlobalKey _childKey = GlobalKey();

  Duration _last = Duration.zero;

  /// The direction held now, when it started, and when it last fired.
  TraversalDirection? _held;
  Duration _heldSince = Duration.zero;
  Duration _lastFired = Duration.zero;

  /// A direction held when the bridge was enabled: ignored until let go.
  bool _needNeutral = false;

  /// The triggers as buttons (some platforms report them only as axes).
  final Map<String, bool> _triggerDown = {};

  @override
  void initState() {
    super.initState();
    _ticker.start();
    if (widget.enabled) _needNeutral = true;
  }

  @override
  void didUpdateWidget(GamepadFocusBridge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) _restart();
    if (!widget.enabled && oldWidget.enabled) widget.pointer?.hide();
  }

  /// Forgets everything pressed so far; a held direction must be let go.
  void _restart() {
    _watcher.rebase();
    _held = null;
    _needNeutral = true;
    _triggerDown.clear();
    final pads = widget.gamepads();
    for (final key in const ['left_trigger', 'right_trigger']) {
      _triggerDown[key] = (pads?.getAxis(key) ?? 0) >= 0.5;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration now) {
    final dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    if (!widget.enabled) return;
    final pads = widget.gamepads();
    if (pads == null) return;

    // The pointer, when showing, has the pad to itself.
    final pointer = widget.pointer;
    if (pointer != null) {
      if (_watcher.takePresses(widget.pointerToggle) > 0) {
        if (pointer.active) {
          pointer.hide();
        } else {
          pointer.show();
          _watcher.rebase();
          _held = null;
          _needNeutral = true;
          return;
        }
      }
      if (pointer.active) {
        _drivePointer(pads, pointer, dt);
        return;
      }
    }

    _directions(pads, now);
    for (final MapEntry(key: button, value: intent) in widget.buttons.entries) {
      for (var n = _watcher.takePresses(button); n > 0; n--) {
        _send(intent);
      }
    }
    _triggers(pads);
    _scroll(pads, dt);
  }

  // ---------------------------------------------------------------------------
  // Directions.

  void _directions(GamepadState pads, Duration now) {
    // D-pad taps between frames still count.
    const dpad = {
      'dpad_up': TraversalDirection.up,
      'dpad_down': TraversalDirection.down,
      'dpad_left': TraversalDirection.left,
      'dpad_right': TraversalDirection.right,
    };
    final tapped = <TraversalDirection>[
      for (final MapEntry(:key, :value) in dpad.entries)
        for (var n = _watcher.takePresses(key); n > 0; n--) value,
    ];
    TraversalDirection? held;
    for (final MapEntry(:key, :value) in dpad.entries) {
      if (pads.isButtonPressed(key)) held = value;
    }
    held ??= _stickDirection(pads);

    if (_needNeutral) {
      if (held != null) return;
      _needNeutral = false;
      tapped.clear();
    }
    if (held == null) {
      _held = null;
      for (final d in tapped) {
        _sendDirection(d, repeat: false);
      }
      return;
    }
    if (held != _held) {
      _held = held;
      _heldSince = now;
      _lastFired = now;
      _sendDirection(held, repeat: false);
      return;
    }
    if (now - _heldSince >= widget.repeatDelay &&
        now - _lastFired >= widget.repeatInterval) {
      _lastFired = now;
      _sendDirection(held, repeat: true);
    }
  }

  TraversalDirection? _stickDirection(GamepadState pads) {
    final x = pads.getAxis('left_stick_x');
    final y = pads.getAxis('left_stick_y');
    final held = _held;
    // Keep the direction held while its axis stays past the release line.
    if (held != null) {
      final along = switch (held) {
        TraversalDirection.left => -x,
        TraversalDirection.right => x,
        TraversalDirection.up => -y,
        TraversalDirection.down => y,
      };
      if (along >= widget.stickRelease) return held;
    }
    if (math.max(x.abs(), y.abs()) < widget.stickPress) return null;
    if (x.abs() > y.abs()) {
      return x > 0 ? TraversalDirection.right : TraversalDirection.left;
    }
    return y > 0 ? TraversalDirection.down : TraversalDirection.up;
  }

  void _sendDirection(TraversalDirection direction, {required bool repeat}) {
    final own = GamepadDirectionIntent(direction, repeat: repeat);
    final target = _target();
    if (target == null) return;
    final action = Actions.maybeFind<GamepadDirectionIntent>(
      target,
      intent: own,
    );
    if (action != null && action.isEnabled(own)) {
      Actions.invoke(target, own);
      return;
    }
    Actions.maybeInvoke(target, DirectionalFocusIntent(direction));
  }

  // ---------------------------------------------------------------------------
  // Buttons, triggers, scrolling.

  void _triggers(GamepadState pads) {
    for (final (key, delta) in const [
      ('left_trigger', -1),
      ('right_trigger', 1),
    ]) {
      final value = pads.getAxis(key);
      final was = _triggerDown[key] ?? false;
      final down = value >= (was ? 0.4 : 0.5);
      _triggerDown[key] = down;
      // As an axis, or as a button where the platform reports one.
      final pressed = (down && !was) || _watcher.takePresses(key) > 0;
      if (pressed) _send(GamepadPageIntent(delta));
    }
  }

  void _scroll(GamepadState pads, double dt) {
    final x = pads.getAxis('right_stick_x');
    final y = pads.getAxis('right_stick_y');
    final length = math.sqrt(x * x + y * y);
    if (length < 0.2 || dt <= 0) return;
    // Gentle near the middle, quick at full tilt.
    final m = ((length - 0.2) / 0.75).clamp(0.0, 1.0);
    final delta = Offset(x, y) / length * m * m * widget.scrollSpeed * dt;
    final intent = GamepadScrollIntent(delta);
    final target = _target();
    if (target == null) return;
    final action = Actions.maybeFind<GamepadScrollIntent>(
      target,
      intent: intent,
    );
    if (action != null && action.isEnabled(intent)) {
      Actions.invoke(target, intent);
      return;
    }
    // The nearest scroll view round the focus that can move the way the
    // stick pushes: one that can't (along the other axis, already at its
    // end, or nothing to scroll) passes it out to the one round it, so a
    // short list inside a long page still lets the page scroll.
    var scrollable = Scrollable.maybeOf(target);
    while (scrollable != null) {
      final position = scrollable.position;
      final along = position.axis == Axis.vertical ? delta.dy : delta.dx;
      final room = along > 0
          ? position.maxScrollExtent - position.pixels
          : position.pixels - position.minScrollExtent;
      if (along != 0 && room > 0) {
        position.jumpTo(
          (position.pixels + along).clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          ),
        );
        return;
      }
      scrollable = Scrollable.maybeOf(scrollable.context);
    }
  }

  void _send(Intent intent) {
    final target = _target();
    if (target == null) return;
    Actions.maybeInvoke(target, intent);
  }

  /// Where intents go: the focused widget if it's inside the bridge, else
  /// the bridge's child.
  BuildContext? _target() {
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused != null && focused.mounted && _contains(focused)) {
      return focused;
    }
    return _childKey.currentContext;
  }

  bool _contains(BuildContext inner) {
    final mine = _childKey.currentContext;
    if (mine == null) return false;
    var found = false;
    inner.visitAncestorElements((element) {
      if (element == mine) {
        found = true;
        return false;
      }
      return true;
    });
    return found || inner == mine;
  }

  // ---------------------------------------------------------------------------
  // The pointer.

  void _drivePointer(
    GamepadState pads,
    VirtualPointerController pointer,
    double dt,
  ) {
    // Back out: B, or the d-pad or left stick (focus navigation again).
    final steered =
        _stickDirection(pads) != null ||
        const [
          'dpad_up',
          'dpad_down',
          'dpad_left',
          'dpad_right',
        ].any((k) => pads.isButtonPressed(k) || _watcher.takePresses(k) > 0);
    if (_watcher.takePresses('b') > 0 || steered) {
      pointer.hide();
      _watcher.rebase();
      _held = null;
      _needNeutral = true;
      return;
    }
    // A clicks, X right-clicks; held, they drag.
    for (final (key, button) in const [
      ('a', kPrimaryButton),
      ('x', kSecondaryButton),
    ]) {
      final presses = _watcher.takePresses(key);
      if (presses > 0) {
        // A press and release since the last frame is still a click.
        pointer
          ..release(button)
          ..press(button);
        if (!pads.isButtonPressed(key)) pointer.release(button);
      } else if (!pads.isButtonPressed(key)) {
        pointer.release(button);
      }
    }
    final x = pads.getAxis('right_stick_x');
    final y = pads.getAxis('right_stick_y');
    final length = math.sqrt(x * x + y * y);
    if (length < 0.15 || dt <= 0) return;
    final m = ((length - 0.15) / 0.8).clamp(0.0, 1.0);
    pointer.moveBy(Offset(x, y) / length * m * m * widget.pointerSpeed * dt);
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _childKey, child: widget.child);
}
