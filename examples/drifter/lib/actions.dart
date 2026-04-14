import 'package:flutter/services.dart';
import 'package:fledge_input/fledge_input.dart';

/// Logical actions the player can trigger.
enum DrifterAction {
  /// WASD / arrow keys → vector2 movement.
  move,

  /// Save the current state to slot 0.
  save,

  /// Load slot 0 into the current state.
  load,

  /// Wipe the current run and start over.
  reset,
}

/// Build the input map used by the game. Exposed as a function so tests
/// can reuse it without constructing a full plugin.
InputMap buildInputMap() => InputMap.builder()
    .bindArrows(ActionId.fromEnum(DrifterAction.move))
    .bindWasd(ActionId.fromEnum(DrifterAction.move))
    .bindKey(LogicalKeyboardKey.keyS, ActionId.fromEnum(DrifterAction.save))
    .bindKey(LogicalKeyboardKey.keyL, ActionId.fromEnum(DrifterAction.load))
    .bindKey(LogicalKeyboardKey.keyR, ActionId.fromEnum(DrifterAction.reset))
    .build();
