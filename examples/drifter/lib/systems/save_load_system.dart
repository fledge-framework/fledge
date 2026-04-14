import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_input/fledge_input.dart';
import 'package:fledge_save/fledge_save.dart';

import '../actions.dart';
import '../resources.dart';

/// Bridges input actions to the save/load plumbing.
///
/// - **S**: set `SaveManager.saveRequested`. The Flutter layer sees the
///   flag in its ticker and drives `SaveManager.save` asynchronously.
/// - **L**: flip `LoadRequested.pending` so the Flutter layer can
///   `SaveManager.load` on the next frame and notify the widget.
/// - **R**: wipe the current run — pickups and run score — via a
///   resource flag so the widget's game-app helper can rebuild entities
///   from scratch. (Handled in the widget rather than here because
///   respawning entities cleanly requires knowing the play-field bounds
///   and rand seed that the widget owns.)
class SaveLoadSystem implements System {
  @override
  SystemMeta get meta => const SystemMeta(
        name: 'SaveLoadSystem',
        resourceReads: {ActionState},
        resourceWrites: {SaveManager, LoadRequested, ResetRequested},
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) async {
    final actions = world.getResource<ActionState>();
    final saveManager = world.getResource<SaveManager>();
    if (actions == null) return;

    if (actions.justPressed(ActionId.fromEnum(DrifterAction.save))) {
      saveManager?.requestSave();
    }

    if (actions.justPressed(ActionId.fromEnum(DrifterAction.load))) {
      world.getResource<LoadRequested>()?.pending = true;
    }

    if (actions.justPressed(ActionId.fromEnum(DrifterAction.reset))) {
      world.getResource<ResetRequested>()?.pending = true;
    }
  }
}
