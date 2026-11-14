import 'package:fledge_ecs/fledge_ecs.dart';

import '../config/audio_config.dart';
import '../resources/audio_state.dart';

/// Starts the audio engine, without holding up the frame.
///
/// Runs in the [FirstSets.platform] phase of `Schedules.first`. On the
/// first frame it starts the engine and returns at once; when the engine is
/// up, [AudioState.isInitialized] turns true and the audio systems begin
/// loading and playing. Everything asked for meanwhile waits (music) or is
/// reported as skipped (sound effects). If the engine can't start, audio
/// stays off and [AudioState.initError] says why.
class AudioInitSystem implements System {
  AudioInitSystem(this.config);

  final AudioConfig config;
  bool _started = false;

  /// The `SystemMeta.name` of [AudioInitSystem].
  static const String systemName = 'AudioInitSystem';

  @override
  SystemMeta get meta => const SystemMeta(
    name: systemName,
    sets: [FirstSets.platform],
    resourceWrites: {AudioState},
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => !_started;

  @override
  Future<void> run(World world) async {
    if (_started) return;
    final state = world.getResource<AudioState>();
    if (state == null) return;
    _started = true;
    final backend = state.backend;
    // Not awaited: the engine starts on its own time.
    backend.init().then(
      (_) {
        try {
          backend
            ..setMaxVoices(config.maxConcurrentSounds)
            ..setMasterVolume(config.masterVolume);
        } catch (e) {
          // ignore: avoid_print
          print('fledge_audio: could not configure the engine: $e');
        }
        state.isInitialized = true;
      },
      onError: (Object e) {
        state.initError = e;
        // ignore: avoid_print
        print('fledge_audio: audio is off, the engine failed to start: $e');
      },
    );
  }
}
