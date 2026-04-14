import 'package:fledge_ecs/fledge_ecs.dart';

import '../resources/audio_channels.dart';

/// Ticks any in-progress linear fades on `VolumeChannels` once per frame.
///
/// Runs in [CoreStage.update] before systems that read effective channel
/// volumes (e.g. `SpatialAudioSystem`) so they observe the ramped value on
/// the same frame the fade advances.
class ChannelFadeSystem implements System {
  @override
  SystemMeta get meta => const SystemMeta(
        name: 'ChannelFadeSystem',
        resourceReads: {Time},
        resourceWrites: {VolumeChannels},
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) async {
    final time = world.getResource<Time>();
    final channels = world.getResource<VolumeChannels>();
    if (time == null || channels == null) return;
    channels.advanceFades(time.delta);
  }
}
