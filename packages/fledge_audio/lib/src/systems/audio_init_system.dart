import 'package:fledge_assets/fledge_assets.dart';
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

  /// The `SystemMeta.name` of [AudioInitSystem]. Games that order
  /// their own systems relative to this one use it in `before:` /
  /// `after:`.
  static const String systemName = 'AudioInitSystem';

  @override
  SystemMeta get meta => const SystemMeta(name: systemName, exclusive: true);

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

    // Create and insert resources that need the initialized engine.
    //
    // - `Assets<AudioClip>` is the new post-Phase-5 store; downstream
    //   code loads clips as ref-counted handles via `AudioClipLoader`.
    // - `AudioAssets` stays as a deprecated key-based facade for one
    //   release (see the class-level `@Deprecated` on it).
    // ignore: deprecated_member_use_from_same_package
    final audioAssets = AudioAssets(soloud);
    final audioState = AudioState(soloud);
    audioState.isInitialized = true;

    world.insertResource<Assets<AudioClip>>(Assets<AudioClip>());
    // ignore: deprecated_member_use_from_same_package
    world.insertResource(audioAssets);
    world.insertResource(audioState);
  }
}
