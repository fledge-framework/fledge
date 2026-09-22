import 'package:fledge_ecs/fledge_ecs.dart';

import 'placement_events.dart';
import 'placement_ghost.dart';
import 'placement_state.dart';
import 'placement_validator.dart';

/// The generic placement layer (design §8.2):
///
/// - the [PlacementState] resource, written only by [PlacementSystem];
/// - the request events ([PlacementEnterRequested],
///   [PlacementPreviewRequested], [PlacementConfirmRequested],
///   [PlacementCancelRequested]) and notifications ([PlacementEntered],
///   [PlacementPreviewMoved], [PlacementConfirmed], [PlacementCancelled]);
/// - the game's [validator], registered as the `PlacementValidator`
///   resource (optional: without one every tile is valid);
/// - [PlacementSystem] in [schedule] and, with a [ghost] config,
///   [PlacementGhostSystem] in [ghostSchedule] (after the state is final
///   for the frame, before render extraction).
///
/// The game supplies what placement *means*: its input (sending the
/// requests), what a confirm spawns, and where records are kept
/// (`PlacedEntityRegistry` + its own save). [placementBefore] /
/// [placementAfter] / [ghostBefore] / [ghostAfter] order the two systems
/// against the game's; [validatorAccess] declares what [validator] reads.
class PlacementCorePlugin implements Plugin {
  final PlacementValidator? validator;
  final PlacementAccess validatorAccess;
  final PlacementGhostConfig? ghost;
  final Schedule schedule;
  final Schedule ghostSchedule;
  final List<String> placementBefore;
  final List<String> placementAfter;
  final List<String> ghostBefore;
  final List<String> ghostAfter;

  PlacementCorePlugin({
    this.validator,
    this.validatorAccess = const PlacementAccess(),
    this.ghost,
    this.schedule = Schedules.update,
    this.ghostSchedule = Schedules.postUpdate,
    this.placementBefore = const [],
    this.placementAfter = const [],
    this.ghostBefore = const [],
    this.ghostAfter = const [],
  });

  App? _app;

  @override
  void build(App app) {
    _app = app;
    app
      ..insertResource(PlacementState())
      ..addEvent<PlacementEnterRequested>()
      ..addEvent<PlacementPreviewRequested>()
      ..addEvent<PlacementConfirmRequested>()
      ..addEvent<PlacementCancelRequested>()
      ..addEvent<PlacementEntered>()
      ..addEvent<PlacementPreviewMoved>()
      ..addEvent<PlacementConfirmed>()
      ..addEvent<PlacementCancelled>()
      ..addSystem(
        PlacementSystem(
          validatorAccess: validatorAccess,
          before: placementBefore,
          after: placementAfter,
        ),
        schedule: schedule,
      );
    final validator = this.validator;
    if (validator != null) {
      app.world.insertResource<PlacementValidator>(validator);
    }
    final ghost = this.ghost;
    if (ghost != null) {
      app
        ..insertResource(ghost)
        ..addSystem(
          PlacementGhostSystem(
            spriteResourceReads: ghost.resourceReads,
            before: ghostBefore,
            after: ghostAfter,
          ),
          schedule: ghostSchedule,
        );
    }
  }

  @override
  void cleanup() {
    final world = _app?.world;
    world?.removeResource<PlacementState>();
    world?.removeResource<PlacementValidator>();
    world?.removeResource<PlacementGhostConfig>();
    _app = null;
  }
}
