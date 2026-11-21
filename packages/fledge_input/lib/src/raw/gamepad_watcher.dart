import 'gamepad_state.dart';

/// Edge detection for gamepad buttons read from outside the ECS frame loop:
/// a widget's ticker, say, reading pads while the world is paused (a menu
/// over a singleplayer game), when `ActionState` isn't being updated.
///
/// It diffs the pads' monotonic press counts ([GamepadState.pressCount]),
/// so a press and release that both land between two looks still counts
/// once, and nothing pressed before the watcher was made (or last
/// [rebase]d) counts at all.
///
/// ```dart
/// final watcher = GamepadButtonWatcher(() => world.getResource<GamepadState>());
/// // each frame:
/// if (watcher.takePresses('back') > 0) toggleMenu();
/// ```
class GamepadButtonWatcher {
  GamepadButtonWatcher(this._pads) {
    rebase();
  }

  final GamepadState? Function() _pads;

  /// The press count of each key when it was last looked at.
  final Map<String, int> _seen = {};

  /// Presses of [key] (on any pad, or on [gamepadId] only) since it was
  /// last taken, or since the watcher was made or [rebase]d.
  int takePresses(String key, {String? gamepadId}) {
    final pads = _pads();
    if (pads == null) return 0;
    final seenKey = gamepadId == null ? key : '$gamepadId/$key';
    final now = pads.pressCount(key, gamepadId: gamepadId);
    final last = _seen[seenKey] ?? 0;
    _seen[seenKey] = now;
    // A pad removed from the state takes its count with it: never negative.
    return now > last ? now - last : 0;
  }

  /// Whether [key] is held down now (on any connected pad).
  bool isDown(String key, {String? gamepadId}) =>
      _pads()?.isButtonPressed(key, gamepadId: gamepadId) ?? false;

  /// Forgets every press so far: the next [takePresses] counts only presses
  /// from here on. Call it when a reader starts listening (a menu opening),
  /// so the press that opened it isn't read again inside.
  void rebase() {
    _seen.clear();
    final pads = _pads();
    if (pads == null) return;
    for (final key in pads.buttonKeys) {
      _seen[key] = pads.pressCount(key);
    }
    for (final gamepad in pads.gamepads.values) {
      for (final key in gamepad.buttons.keys) {
        _seen['${gamepad.id}/$key'] = gamepad.pressCount(key);
      }
    }
  }
}
