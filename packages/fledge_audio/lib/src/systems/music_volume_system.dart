import 'package:fledge_ecs/fledge_ecs.dart';

import '../resources/audio_channels.dart';
import '../resources/audio_state.dart';
import 'channel_fade_system.dart';

/// Keeps the playing music at its volume times the music channel's, so a
/// volume setting (or a channel fade) reaches a track that is already
/// playing.
///
/// Runs in `Schedules.update`, after [ChannelFadeSystem] has advanced this
/// frame's channel fades. A change during the track's fade-in re-targets
/// the fade over the time it has left, instead of cutting it short.
class MusicVolumeSystem implements System {
  /// The `SystemMeta.name` of [MusicVolumeSystem].
  static const String systemName = 'MusicVolumeSystem';

  @override
  SystemMeta get meta => const SystemMeta(
    name: systemName,
    resourceReads: {WallTime, VolumeChannels},
    resourceWrites: {AudioState},
    after: [ChannelFadeSystem.systemName],
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  void run(World world) {
    final state = world.getResource<AudioState>();
    final channels = world.getResource<VolumeChannels>();
    if (state == null || channels == null || !state.isInitialized) return;
    final delta = world.getResource<WallTime>()?.delta ?? 0.0;

    final channel = channels.getEffectiveVolume(AudioChannel.music);
    final voice = state.currentMusicVoice;
    if (voice != null && channel != state.appliedMusicChannel) {
      final seconds = state.musicFadeRemaining > 0.05
          ? state.musicFadeRemaining
          : 0.05;
      state.backend.fadeVolume(
        voice,
        state.musicVolume * channel,
        Duration(microseconds: (seconds * 1e6).round()),
      );
    }
    state
      ..appliedMusicChannel = channel
      ..musicFadeRemaining = (state.musicFadeRemaining - delta).clamp(
        0.0,
        double.infinity,
      );
  }
}
