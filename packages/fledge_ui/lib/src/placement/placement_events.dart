import 'placement_tile.dart';

// =============================================================================
// Placement events (generic core)
// =============================================================================
//
// Requests are sent by anyone — input systems, game systems, widgets
// between ticks. Only `PlacementSystem` reads them, and it is the only
// writer of `PlacementState`.
//
// Notifications are sent by `PlacementSystem` when the state changes. Like
// every fledge event, both are readable on the tick after they are sent.
//
// Within one `PlacementSystem` run the requests are applied in this order:
// cancel, enter, preview, confirm. So a cancel and an enter in the same
// tick leave placement entered; an enter and a preview in the same tick
// preview the new placeable.

/// Enter placement mode for the placeable [key] (an opaque id supplied by
/// the game). Placing something else is cancelled first
/// ([PlacementCancelled]); already placing [key] is a no-op. Several in one
/// tick: the last one wins.
class PlacementEnterRequested {
  final String key;

  const PlacementEnterRequested(this.key);

  @override
  String toString() => 'PlacementEnterRequested($key)';
}

/// Move the preview to tile ([x], [y]) of map [mapKey]. Ignored unless
/// placing. Several in one tick: the last one wins.
class PlacementPreviewRequested {
  final String mapKey;
  final int x;
  final int y;

  const PlacementPreviewRequested(this.mapKey, this.x, this.y);

  PlacementTile get tile => PlacementTile(mapKey, x, y);

  @override
  String toString() => 'PlacementPreviewRequested($mapKey, $x, $y)';
}

/// Place the placeable at the preview tile. Ignored unless placing with a
/// valid preview (`PlacementState.isValid`, re-checked in the same run).
/// Confirming ends placement mode ([PlacementConfirmed]).
class PlacementConfirmRequested {
  const PlacementConfirmRequested();

  @override
  String toString() => 'PlacementConfirmRequested()';
}

/// Leave placement mode without placing ([PlacementCancelled]). Ignored
/// unless placing.
class PlacementCancelRequested {
  const PlacementCancelRequested();

  @override
  String toString() => 'PlacementCancelRequested()';
}

/// Placement mode was entered for [key] (no preview tile yet, unless a
/// preview request came in the same tick).
class PlacementEntered {
  final String key;

  const PlacementEntered(this.key);

  @override
  String toString() => 'PlacementEntered($key)';
}

/// The preview moved to [tile], or its validity (or refusal [reason])
/// changed on the same tile.
class PlacementPreviewMoved {
  final PlacementTile tile;
  final bool isValid;

  /// Why the tile is refused (the validator's `refusalReason`), or null.
  final String? reason;

  const PlacementPreviewMoved(this.tile, {required this.isValid, this.reason});

  @override
  String toString() =>
      'PlacementPreviewMoved($tile, valid: $isValid, reason: $reason)';
}

/// The player confirmed placing [key] on [tile] (validated in that run).
/// Placement mode has ended. The game spawns the entity (and takes the
/// item, registers the record, ...) in response.
class PlacementConfirmed {
  final String key;
  final PlacementTile tile;

  const PlacementConfirmed(this.key, this.tile);

  @override
  String toString() => 'PlacementConfirmed($key, $tile)';
}

/// Placement of [key] was cancelled (a cancel request, or entering a
/// different placeable). Placement mode has ended.
class PlacementCancelled {
  final String key;

  const PlacementCancelled(this.key);

  @override
  String toString() => 'PlacementCancelled($key)';
}
