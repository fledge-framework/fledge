import 'package:fledge_ecs/fledge_ecs.dart';

import 'transition_state.dart';

/// System that updates fade animation progress during transitions.
///
/// Advances [TransitionState.fadeProgress] based on frame time during
/// fadeOut and fadeIn phases. The loading phase is not handled by this
/// system - games should handle async loading in their game loop.
class TransitionFadeSystem implements System {
  /// Creates a transition fade system.
  const TransitionFadeSystem();

  /// The `SystemMeta.name` of [TransitionFadeSystem]. Games that
  /// order their own systems relative to this one use it in
  /// `before:` / `after:`.
  static const String systemName = 'TransitionFadeSystem';

  @override
  SystemMeta get meta => const SystemMeta(
    name: systemName,
    resourceReads: {WallTime},
    resourceWrites: {TransitionState},
    eventWrites: {TransitionCompleted},
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    _runSync(world);
    return Future.value();
  }

  void _runSync(World world) {
    final time = world.getResource<WallTime>();
    final transitionState = world.getResource<TransitionState>();

    if (time == null || transitionState == null) return;
    if (!transitionState.isTransitioning) return;

    final delta = time.delta;
    final progressDelta = delta / transitionState.fadeDuration;

    switch (transitionState.phase) {
      case TransitionPhase.fadeOut:
        transitionState.fadeProgress += progressDelta;
        if (transitionState.fadeProgress >= 1.0) {
          transitionState.fadeProgress = 1.0;
          transitionState.beginLoading();
        }

      case TransitionPhase.fadeIn:
        transitionState.fadeProgress -= progressDelta;
        if (transitionState.fadeProgress <= 0.0) {
          // Capture scene + metadata before complete() clears them so
          // the emitted event carries the finished transition's target.
          final finishedScene = transitionState.targetScene;
          final finishedMetadata = transitionState.metadata;
          transitionState.complete();
          world.eventWriter<TransitionCompleted>().send(
            TransitionCompleted(
              scene: finishedScene,
              metadata: finishedMetadata,
            ),
          );
        }

      case TransitionPhase.loading:
      case TransitionPhase.idle:
        // No-op - loading is handled by game loop
        break;
    }
  }
}
