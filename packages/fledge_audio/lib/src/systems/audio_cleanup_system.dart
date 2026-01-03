import 'package:fledge_ecs/fledge_ecs.dart';

import '../components/audio_source.dart';
import '../resources/audio_state.dart';

/// System that cleans up finished audio handles.
class AudioCleanupSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'AudioCleanupSystem',
        resourceWrites: {AudioState},
        writes: {ComponentId.of<AudioSource>()},
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) async {
    final state = world.getResource<AudioState>();
    if (state == null || !state.isInitialized) return;

    // Clean up finished sounds from the state tracking
    state.cleanupFinishedSounds();

    // Clean up AudioSource components with invalid handles
    final soloud = state.soloud;
    for (final (_, source) in world.query1<AudioSource>().iter()) {
      if (source.handle != null &&
          !soloud.getIsValidVoiceHandle(source.handle!)) {
        source.handle = null;
      }
    }
  }
}
