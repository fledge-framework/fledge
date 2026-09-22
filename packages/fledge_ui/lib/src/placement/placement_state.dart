import 'package:fledge_ecs/fledge_ecs.dart';

import 'placement_events.dart';
import 'placement_tile.dart';
import 'placement_validator.dart';

part 'placement_system.dart';

// =============================================================================
// PlacementState (generic core)
// =============================================================================
//
// This library (the state + `PlacementSystem`, `placement_system.dart` is a
// part of it) is the placement-mode state and its single writer. The
// state's mutators are library-private: only `PlacementSystem` changes it,
// in response to the request events in placement_events.dart. Everything
// else — the ghost, the HUD, game systems, run conditions — only reads it.

/// What placement mode is doing.
enum PlacementMode {
  /// Not placing.
  idle,

  /// Placing, and the preview tile is valid: a confirm places it.
  previewing,

  /// Placing, but there is no preview tile yet or the validator refuses it.
  invalid,
}

/// The one placement in progress (or none). Transient: never saved.
class PlacementState {
  PlacementMode _mode = PlacementMode.idle;
  String? _key;
  PlacementTile? _tile;
  String? _reason;

  /// See [PlacementMode].
  PlacementMode get mode => _mode;

  /// Whether placement mode is active (previewing or invalid).
  bool get isPlacing => _mode != PlacementMode.idle;

  /// Whether the preview tile is valid (a confirm would place).
  bool get isValid => _mode == PlacementMode.previewing;

  /// The placeable being placed (the game's opaque key), or null.
  String? get placeableKey => _key;

  /// The preview tile, or null (not placing, or no preview yet).
  PlacementTile? get previewTile => _tile;

  /// Why the preview tile is refused (the validator's reason), or null.
  String? get refusalReason => _reason;

  // ---------------------------------------------------------------------------
  // Mutators — library-private, used only by PlacementSystem.
  // ---------------------------------------------------------------------------

  void _enter(String key) {
    _mode = PlacementMode.invalid;
    _key = key;
    _tile = null;
    _reason = null;
  }

  void _preview(PlacementTile tile, bool isValid, String? reason) {
    _tile = tile;
    _mode = isValid ? PlacementMode.previewing : PlacementMode.invalid;
    _reason = isValid ? null : reason;
  }

  void _exit() {
    _mode = PlacementMode.idle;
    _key = null;
    _tile = null;
    _reason = null;
  }

  @override
  String toString() =>
      'PlacementState(${_mode.name}, key: $_key, tile: $_tile, '
      'reason: $_reason)';
}
