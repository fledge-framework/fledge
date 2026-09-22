part of 'placement_state.dart';

/// Whether placement mode is active (a [RunCondition]; callable as a plain
/// check too). False without a [PlacementState].
final RunCondition placementActive = RunConditions.resource<PlacementState>(
  (state) => state.isPlacing,
);

/// The only writer of [PlacementState] (generic core).
///
/// Per run, applying last tick's requests in this order:
/// 1. [PlacementCancelRequested] — while placing: [PlacementCancelled],
///    back to idle.
/// 2. [PlacementEnterRequested] (the last one) — a different key than the
///    one being placed: cancels the current one ([PlacementCancelled]),
///    enters ([PlacementEntered]) with no preview tile yet.
/// 3. While placing: the preview tile is the last
///    [PlacementPreviewRequested]'s, else the current one. It is validated
///    on every run (the `PlacementValidator` resource; without one, every
///    tile is valid), so a tile turns invalid when something moves onto it.
///    [PlacementPreviewMoved] is sent when the tile, its validity or the
///    refusal reason changes.
/// 4. [PlacementConfirmRequested] — with a valid preview:
///    [PlacementConfirmed] (key + tile), back to idle. Otherwise ignored.
///
/// Runs only while placing or when an enter is requested, so idle costs
/// nothing but the check.
class PlacementSystem implements System {
  final PlacementAccess validatorAccess;
  final List<String> before;
  final List<String> after;

  const PlacementSystem({
    this.validatorAccess = const PlacementAccess(),
    this.before = const [],
    this.after = const [],
  });

  static const String systemName = 'PlacementSystem';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    reads: validatorAccess.reads,
    resourceReads: {PlacementValidator, ...validatorAccess.resourceReads},
    resourceWrites: const {PlacementState},
    eventReads: const {
      PlacementEnterRequested,
      PlacementPreviewRequested,
      PlacementConfirmRequested,
      PlacementCancelRequested,
    },
    eventWrites: const {
      PlacementEntered,
      PlacementPreviewMoved,
      PlacementConfirmed,
      PlacementCancelled,
    },
    before: before,
    after: after,
  );

  @override
  RunCondition? get runCondition => _shouldRun;

  static bool _shouldRun(World world) =>
      placementActive(world) ||
      world.eventReader<PlacementEnterRequested>().isNotEmpty;

  @override
  bool shouldRun(World world) => _shouldRun(world);

  @override
  Future<void> run(World world) {
    final state = world.getResource<PlacementState>();
    if (state == null) return Future.value();

    // 1. Cancel.
    if (world.eventReader<PlacementCancelRequested>().isNotEmpty &&
        state.isPlacing) {
      _cancel(world, state);
    }

    // 2. Enter (the last request wins).
    final enter = world.eventReader<PlacementEnterRequested>().read();
    if (enter.isNotEmpty) {
      final key = enter.last.key;
      if (!state.isPlacing || state.placeableKey != key) {
        if (state.isPlacing) _cancel(world, state);
        state._enter(key);
        world.eventWriter<PlacementEntered>().send(PlacementEntered(key));
      }
    }
    if (!state.isPlacing) return Future.value();
    final key = state.placeableKey!;

    // 3. Preview: the requested tile (the last one), else the current one,
    // re-validated.
    final previews = world.eventReader<PlacementPreviewRequested>().read();
    final tile = previews.isNotEmpty ? previews.last.tile : state.previewTile;
    if (tile != null) {
      final validator = world.getResource<PlacementValidator>();
      final valid = validator?.isValid(world, key, tile) ?? true;
      final reason = valid ? null : validator?.refusalReason(world, key, tile);
      final changed =
          tile != state.previewTile ||
          valid != state.isValid ||
          reason != state.refusalReason;
      state._preview(tile, valid, reason);
      if (changed) {
        world.eventWriter<PlacementPreviewMoved>().send(
          PlacementPreviewMoved(tile, isValid: valid, reason: reason),
        );
      }
    }

    // 4. Confirm.
    if (world.eventReader<PlacementConfirmRequested>().isNotEmpty &&
        state.isValid) {
      final placed = state.previewTile!;
      state._exit();
      world.eventWriter<PlacementConfirmed>().send(
        PlacementConfirmed(key, placed),
      );
    }
    return Future.value();
  }

  static void _cancel(World world, PlacementState state) {
    final key = state.placeableKey!;
    state._exit();
    world.eventWriter<PlacementCancelled>().send(PlacementCancelled(key));
  }
}
