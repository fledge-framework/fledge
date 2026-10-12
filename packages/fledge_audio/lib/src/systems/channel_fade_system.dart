import 'package:fledge_ecs/fledge_ecs.dart';

import '../resources/audio_channels.dart';
import 'spatial_audio_system.dart';

/// Ticks any in-progress linear fades on `VolumeChannels` once per frame.
///
/// Runs in `Schedules.update` before systems that read effective channel
/// volumes (e.g. [SpatialAudioSystem]) so they observe the ramped value on
/// the same frame the fade advances.
class ChannelFadeSystem implements System {
  /// The `SystemMeta.name` of [ChannelFadeSystem]. Games that read
  /// `VolumeChannels` in `Schedules.update` should order `after:` it.
  static const String systemName = 'ChannelFadeSystem';

  @override
  SystemMeta get meta => const SystemMeta(
    name: systemName,
    before: [SpatialAudioSystem.systemName],
    resourceReads: {WallTime},
    resourceWrites: {VolumeChannels},
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) async {
    final time = world.getResource<WallTime>();
    final channels = world.getResource<VolumeChannels>();
    if (time == null || channels == null) return;
    channels.advanceFades(time.delta);
  }
}
