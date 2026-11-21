import 'package:flutter/widgets.dart';

/// A direction pushed on the d-pad or left stick (`GamepadFocusBridge`),
/// offered to the focused widget before focus moves: a widget that uses
/// left and right itself (a slider, a value row) handles this and focus
/// stays put. Unhandled, the bridge moves focus that way
/// (`DirectionalFocusIntent`).
class GamepadDirectionIntent extends Intent {
  const GamepadDirectionIntent(this.direction, {this.repeat = false});

  final TraversalDirection direction;

  /// Whether this is an auto-repeat of a held direction rather than the
  /// first push.
  final bool repeat;
}

/// The shoulder buttons: the previous (-1) or next (+1) tab.
class GamepadTabIntent extends Intent {
  const GamepadTabIntent(this.delta);
  final int delta;
}

/// The triggers: the previous (-1) or next (+1) page or sub-tab.
class GamepadPageIntent extends Intent {
  const GamepadPageIntent(this.delta);
  final int delta;
}

/// Any other controller button pressed over a focused widget (`x`, `y`,
/// `start`, `back`; standard keys): for actions of the game's own, like
/// splitting a stack.
class GamepadButtonIntent extends Intent {
  const GamepadButtonIntent(this.button);

  /// The button's standard key.
  final String button;
}

/// The right stick: scroll by [delta] logical pixels this frame. Unhandled,
/// the bridge scrolls the focused widget's nearest `Scrollable`.
class GamepadScrollIntent extends Intent {
  const GamepadScrollIntent(this.delta);
  final Offset delta;
}
