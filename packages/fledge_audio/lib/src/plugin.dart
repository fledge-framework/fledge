import 'package:fledge_assets/fledge_assets.dart';
import 'package:fledge_ecs/fledge_ecs.dart';

import 'assets/audio_clip.dart';
import 'backend/audio_backend.dart';
import 'backend/soloud_backend.dart';
import 'config/audio_config.dart';
import 'events/audio_events.dart';
import 'resources/audio_channels.dart';
import 'resources/audio_library.dart';
import 'resources/audio_pump.dart';
import 'resources/audio_state.dart';
import 'systems/audio_cleanup_system.dart';
import 'systems/audio_event_system.dart';
import 'systems/audio_focus_system.dart';
import 'systems/audio_init_system.dart';
import 'systems/channel_fade_system.dart';
import 'systems/music_volume_system.dart';
import 'systems/spatial_audio_system.dart';

/// Music, sound effects and 2D spatial audio.
///
/// ```dart
/// final app = App()
///   ..addPlugin(WallTimePlugin()) // fades and channel volumes follow time
///   ..addPlugin(AudioPlugin());
///
/// // Register clips any time, before the engine has started too; they load
/// // in the background once it has.
/// app.world
///   ..loadMusic('theme', 'assets/music/theme.ogg')
///   ..loadSound('door', 'assets/sounds/door.wav');
///
/// // Music waits for its clip, so this can be asked for straight away.
/// app.world.playMusic('theme', crossfade: Duration(seconds: 2));
/// app.world.playSfx('door', position: (120, 40));
/// ```
///
/// Nothing here ever holds up a frame: the engine starts and clips load in
/// the background. Every resource is inserted when the app is built, so
/// requests can be made from the first frame.
///
/// [backend] is the engine ([SoLoudBackend] by default); tests pass a fake.
class AudioPlugin implements Plugin {
  /// Audio configuration.
  final AudioConfig config;

  final AudioBackend? _backend;
  AudioBackend? _built;
  AudioFocusSystem? _focus;

  /// Creates an audio plugin with custom configuration.
  AudioPlugin({this.config = const AudioConfig(), this._backend});

  /// Creates an audio plugin with default settings.
  AudioPlugin.defaults()
    : config = const AudioConfig.defaults(),
      _backend = null;

  /// Creates an audio plugin without spatial audio.
  AudioPlugin.nonSpatial()
    : config = const AudioConfig.nonSpatial(),
      _backend = null;

  @override
  void build(App app) {
    final backend = _backend ?? SoLoudBackend();
    _built = backend;
    app
        // Requests
        .addEvent<PlaySfxRequest>()
        .addEvent<PlayMusicRequest>()
        .addEvent<StopMusicRequest>()
        .addEvent<PauseAudioRequest>()
        .addEvent<ResumeAudioRequest>()
        .addEvent<SetChannelVolumeRequest>()
        // Responses
        .addEvent<SfxStarted>()
        .addEvent<SfxFinished>()
        .addEvent<AudioSourceFinished>()
        .addEvent<MusicStarted>()
        .addEvent<MusicFinished>()
        .addEvent<MusicChanged>()
        .addEvent<AudioFailed>()
        .addEvent<AudioPaused>()
        .addEvent<AudioResumed>()
        .addEvent<AudioAssetLoaded>();

    app
        .insertResource(config)
        .insertResource(config.spatialConfig)
        .insertResource(VolumeChannels(config.channels))
        .insertResource(AudioState(backend))
        .insertResource(AudioLibrary())
        .insertResource(AudioFocus());
    if (app.world.getResource<Assets<AudioClip>>() == null) {
      app.insertResource(Assets<AudioClip>());
    }

    final init = AudioInitSystem(config);
    final events = AudioEventSystem();
    final fades = ChannelFadeSystem();
    final musicVolume = MusicVolumeSystem();
    final sources = SpatialAudioSystem();
    final cleanup = AudioCleanupSystem();
    final focus = config.pauseOnFocusLoss ? AudioFocusSystem() : null;
    _focus = focus;
    app
      ..addSystem(init, schedule: Schedules.first)
      ..addSystem(events, schedule: Schedules.first)
      ..addSystem(fades, schedule: Schedules.update)
      ..addSystem(musicVolume, schedule: Schedules.update)
      // Sources (spatial or not) run in `last` so they read final
      // Transform2D values, after every per-frame transform writer
      // (physics, camera, movement).
      ..addSystem(sources, schedule: Schedules.last)
      ..addSystem(cleanup, schedule: Schedules.last);
    if (focus != null) app.addSystem(focus, schedule: Schedules.first);
    // The same instances, for `world.pumpAudio` (so sources can be played
    // and stopped from a menu while the world is still).
    app.insertResource(
      AudioPump([init, events, ?focus, fades, musicVolume, sources, cleanup]),
    );
  }

  @override
  void cleanup() {
    _focus?.dispose();
    try {
      _built?.deinit();
    } catch (e) {
      // The app is shutting down anyway.
      // ignore: avoid_print
      print('fledge_audio: error stopping the engine: $e');
    }
  }
}
