import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_ui/fledge_ui.dart';

import '../components.dart';
import '../resources.dart';

import 'pickup_collection_system.dart';

/// Reads [RunScore] and [HighScore] each frame and mutates the HUD
/// [UiText] entities that carry [ScoreLabel] / [HighScoreLabel]
/// markers.
///
/// The retained-mode contract: text is a `String` field on the
/// `UiText` component; mutating it is enough — no despawn/respawn.
class HudUpdateSystem implements System {
  /// Name used in [SystemMeta] and for `before:`/`after:`.
  static const String systemName = 'hud_update';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    reads: {ComponentId.of<ScoreLabel>(), ComponentId.of<HighScoreLabel>()},
    writes: {ComponentId.of<UiText>()},
    resourceReads: {RunScore, HighScore},
    // `PickupCollectionSystem` writes both scores in the same
    // schedule; declare the read explicitly so `checkScheduleOrdering`
    // sees the intent instead of falling back to registration order.
    after: const [PickupCollectionSystem.systemName],
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  void run(World world) {
    final run = world.getResource<RunScore>();
    final high = world.getResource<HighScore>();
    if (run == null || high == null) return;

    final runText = 'Score: ${run.value}';
    for (final (_, text, _)
        in world
            .query2<UiText, ScoreLabel>(filter: const With<ScoreLabel>())
            .iter()) {
      if (text.text != runText) text.text = runText;
    }

    final highText = 'Best: ${high.value}';
    for (final (_, text, _)
        in world
            .query2<UiText, HighScoreLabel>(
              filter: const With<HighScoreLabel>(),
            )
            .iter()) {
      if (text.text != highText) text.text = highText;
    }
  }
}
