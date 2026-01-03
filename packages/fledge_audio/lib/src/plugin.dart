import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'config/audio_config.dart';
import 'events/audio_events.dart';
import 'resources/audio_channels.dart';
import 'systems/audio_init_system.dart';
import 'systems/audio_event_system.dart';
import 'systems/spatial_audio_system.dart';
import 'systems/music_crossfade_system.dart';
import 'systems/audio_cleanup_system.dart';
import 'systems/audio_focus_system.dart';

/// Plugin that adds audio functionality to a Fledge app.
///
/// ## Quick Start
///
/// ```dart
/// // Basic setup
/// await App()
///   .addPlugin(TimePlugin())      // Required for crossfading
///   .addPlugin(AudioPlugin())
///   .run();
///
/// // Load assets
/// final assets = app.world.audioAssets!;
/// await assets.loadSound('explosion', 'assets/sounds/explosion.wav');
/// await assets.loadMusic('theme', 'assets/music/theme.mp3');
///
/// // Play audio
/// app.world.playSfx('explosion');
/// app.world.playMusic('theme');
/// ```
///
/// ## Spatial Audio
///
/// ```dart
/// // Add listener to player/camera
/// world.spawn()
///   ..insert(Transform2D.from(0, 0))
///   ..insert(AudioListener());
///
/// // Add audio source to entities
/// world.spawn()
///   ..insert(Transform2D.from(100, 50))
///   ..insert(AudioSource(
///     soundKey: 'engine',
///     looping: true,
///     autoPlay: true,
///   ));
/// ```
///
/// ## Volume Control
///
/// ```dart
/// world.setVolume(AudioChannel.master, 0.8);
/// world.setVolume(AudioChannel.music, 0.5);
/// world.setVolume(AudioChannel.sfx, 1.0);
/// ```
class AudioPlugin implements Plugin {
  /// Audio configuration.
  final AudioConfig config;

  /// Creates an audio plugin with custom configuration.
  const AudioPlugin({this.config = const AudioConfig()});

  /// Creates an audio plugin with default settings.
  const AudioPlugin.defaults() : config = const AudioConfig.defaults();

  /// Creates an audio plugin without spatial audio.
  const AudioPlugin.nonSpatial() : config = const AudioConfig.nonSpatial();

  @override
  void build(App app) {
    // Register events
    app
        // Request events
        .addEvent<PlaySfxRequest>()
        .addEvent<PlayMusicRequest>()
        .addEvent<StopMusicRequest>()
        .addEvent<PauseAudioRequest>()
        .addEvent<ResumeAudioRequest>()
        .addEvent<SetChannelVolumeRequest>()
        .addEvent<PreloadAudioRequest>()
        // Response events
        .addEvent<SfxStarted>()
        .addEvent<SfxFinished>()
        .addEvent<MusicStarted>()
        .addEvent<MusicFinished>()
        .addEvent<MusicChanged>()
        .addEvent<AudioFailed>()
        .addEvent<AudioPaused>()
        .addEvent<AudioResumed>()
        .addEvent<AudioAssetLoaded>();

    // Insert configuration resources
    app
        .insertResource(config)
        .insertResource(config.spatialConfig)
        .insertResource(VolumeChannels(config.channels));

    // Add systems
    // Note: AudioAssets and AudioState are inserted by AudioInitSystem
    // after SoLoud is initialized
    app.addSystem(AudioInitSystem(config), stage: CoreStage.first);
    app.addSystem(AudioEventSystem(), stage: CoreStage.first);

    if (config.spatialConfig.enabled) {
      app.addSystem(SpatialAudioSystem(), stage: CoreStage.update);
    }

    app.addSystem(MusicCrossfadeSystem(), stage: CoreStage.update);
    app.addSystem(AudioCleanupSystem(), stage: CoreStage.last);

    if (config.pauseOnFocusLoss) {
      app.addSystem(AudioFocusSystem(), stage: CoreStage.first);
    }
  }

  @override
  void cleanup() {
    // Shutdown SoLoud when app closes
    try {
      final soloud = SoLoud.instance;
      if (soloud.isInitialized) {
        soloud.deinit();
      }
    } catch (e) {
      // Ignore cleanup errors - app is shutting down anyway
      // ignore: avoid_print
      print('Error during SoLoud cleanup: $e');
    }
  }
}
