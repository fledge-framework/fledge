import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../assets/audio_assets.dart';
import '../config/audio_config.dart';
import '../resources/audio_state.dart';

/// System that initializes the SoLoud audio engine.
///
/// Runs once on startup to initialize the audio backend.
class AudioInitSystem implements System {
  final AudioConfig config;
  bool _initialized = false;

  AudioInitSystem(this.config);

  @override
  SystemMeta get meta => const SystemMeta(
        name: 'AudioInitSystem',
        exclusive: true,
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => !_initialized;

  @override
  Future<void> run(World world) async {
    if (_initialized) return;
    _initialized = true;

    final soloud = SoLoud.instance;

    // Skip if already initialized (e.g., hot reload)
    if (!soloud.isInitialized) {
      try {
        await soloud.init();
      } catch (e) {
        // Log error but continue - audio will be disabled
        // ignore: avoid_print
        print('Failed to initialize SoLoud audio engine: $e');
        return;
      }
    }

    // Configure global settings
    try {
      soloud.setMaxActiveVoiceCount(config.maxConcurrentSounds);
      soloud.setGlobalVolume(config.masterVolume);
    } catch (e) {
      // ignore: avoid_print
      print('Failed to configure SoLoud: $e');
    }

    // Create and insert resources that need the initialized engine
    final audioAssets = AudioAssets(soloud);
    final audioState = AudioState(soloud);
    audioState.isInitialized = true;

    world.insertResource(audioAssets);
    world.insertResource(audioState);
  }
}
