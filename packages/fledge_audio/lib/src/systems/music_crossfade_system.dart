import 'package:fledge_ecs/fledge_ecs.dart';

import '../events/audio_events.dart';
import '../resources/audio_state.dart';

/// System that handles smooth crossfading between music tracks.
class MusicCrossfadeSystem implements System {
  @override
  SystemMeta get meta => const SystemMeta(
        name: 'MusicCrossfadeSystem',
        resourceReads: {Time},
        resourceWrites: {AudioState},
        eventWrites: {MusicChanged},
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) async {
    final state = world.getResource<AudioState>();
    final time = world.getResource<Time>();
    if (state == null || time == null || !state.isInitialized) return;

    if (!state.isCrossfading) return;

    final soloud = state.soloud;
    final duration = state.crossfadeDuration!;
    final durationSecs = duration.inMilliseconds / 1000.0;

    state.crossfadeElapsed += time.delta;
    final progress = (state.crossfadeElapsed / durationSecs).clamp(0.0, 1.0);

    // Fade out old music
    if (state.fadingOutMusicHandle != null) {
      if (soloud.getIsValidVoiceHandle(state.fadingOutMusicHandle!)) {
        final fadeOutVolume = 1.0 - progress;
        soloud.setVolume(state.fadingOutMusicHandle!, fadeOutVolume);

        if (progress >= 1.0) {
          soloud.stop(state.fadingOutMusicHandle!);
        }
      }
    }

    // Fade in new music
    if (state.currentMusicHandle != null) {
      if (soloud.getIsValidVoiceHandle(state.currentMusicHandle!)) {
        final fadeInVolume = progress * state.crossfadeTargetVolume;
        soloud.setVolume(state.currentMusicHandle!, fadeInVolume);
      }
    }

    // Check if crossfade is complete
    if (progress >= 1.0) {
      final previousKey = state.fadingOutMusicHandle != null
          ? null // We don't track the old key separately
          : null;

      if (state.fadingOutMusicHandle != null) {
        soloud.stop(state.fadingOutMusicHandle!);
      }

      state.fadingOutMusicHandle = null;
      state.crossfadeDuration = null;
      state.crossfadeElapsed = 0.0;

      if (state.currentMusicKey != null) {
        world.eventWriter<MusicChanged>().send(
              MusicChanged(
                previousKey: previousKey,
                newKey: state.currentMusicKey!,
              ),
            );
      }
    }
  }
}
