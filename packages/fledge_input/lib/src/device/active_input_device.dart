import 'package:flutter/foundation.dart';

import 'gamepad_family.dart';

/// A kind of input device.
enum InputDeviceKind { keyboard, mouse, gamepad }

/// Which device the player used last: the keyboard, the mouse or a
/// controller, and for a controller which one and its family. For prompts
/// that follow the player's hands ("E: talk" or "A: talk") and anything
/// else that should change with the device.
///
/// `InputWidget` keeps it up to date from raw events, outside the frame
/// loop, so it follows the player even while the world is paused behind a
/// menu. Listen to it (it's a [ChangeNotifier]) to rebuild prompts when it
/// changes.
///
/// Visibility: local (this machine's devices).
class ActiveInputDevice extends ChangeNotifier {
  InputDeviceKind _kind = InputDeviceKind.keyboard;
  String? _gamepadId;
  GamepadFamily _family = GamepadFamily.xbox;

  /// The device used last (the keyboard until anything is used).
  InputDeviceKind get kind => _kind;

  /// Whether a controller was used last.
  bool get isGamepad => _kind == InputDeviceKind.gamepad;

  /// The controller used last, or null if none has been (it stays set
  /// while the keyboard or mouse is in use, for whatever needs the pad).
  String? get gamepadId => _gamepadId;

  /// The family of the controller used last ([GamepadFamily.xbox] until one
  /// is), for naming its buttons.
  GamepadFamily get family => _family;

  /// Pointer devices that are really a controller: a virtual pointer moved
  /// with a stick sends mouse events, which mustn't switch to the mouse.
  final Set<int> gamepadPointerDevices = {};

  /// Records that [kind] was used ([gamepadId] and [family] for a
  /// controller); listeners hear only of a change.
  void note(InputDeviceKind kind, {String? gamepadId, GamepadFamily? family}) {
    var changed = kind != _kind;
    _kind = kind;
    if (gamepadId != null && gamepadId != _gamepadId) {
      _gamepadId = gamepadId;
      changed = true;
    }
    if (family != null && family != _family) {
      _family = family;
      changed = true;
    }
    if (changed) notifyListeners();
  }
}
