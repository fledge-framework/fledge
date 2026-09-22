import 'package:fledge_ecs/fledge_ecs.dart';

import 'placement_tile.dart';

/// Decides where a placeable may go — supplied by the game and registered
/// as the `PlacementValidator` resource (`PlacementCorePlugin(validator:)`).
///
/// `PlacementSystem` asks it about the preview tile on every run while
/// placing (so a tile turns invalid when something steps onto it) and
/// again on confirm. Implementations must be pure reads of [World]: no
/// resource or component writes, no events. Declare what they read in
/// `PlacementCorePlugin.validatorAccess` so the scheduler can order
/// `PlacementSystem` against the writers.
///
/// Without a validator resource every tile is valid.
abstract class PlacementValidator {
  const PlacementValidator();

  /// Whether the placeable [key] may be placed on [tile].
  bool isValid(World world, String key, PlacementTile tile);

  /// Why [key] may not be placed on [tile] (player-facing), or null for no
  /// particular reason. Only asked after [isValid] returned false.
  String? refusalReason(World world, String key, PlacementTile tile) => null;
}

/// What a game [PlacementValidator] (and anything else `PlacementSystem`
/// runs for the game) reads, declared on `PlacementSystem`'s `SystemMeta`.
class PlacementAccess {
  /// Components read.
  final Set<ComponentId> reads;

  /// Resources read.
  final Set<Type> resourceReads;

  const PlacementAccess({this.reads = const {}, this.resourceReads = const {}});
}
