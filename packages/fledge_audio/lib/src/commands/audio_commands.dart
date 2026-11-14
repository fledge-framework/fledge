import 'package:fledge_ecs/fledge_ecs.dart';

import '../events/audio_events.dart';
import '../resources/audio_channels.dart';
import '../resources/audio_library.dart';
import '../resources/audio_pump.dart';
import '../resources/audio_state.dart';

/// Audio on [World]: registering clips, playing them, volume.
extension AudioCommands on World {
  /// Playback state, or null without `AudioPlugin`.
  AudioState? get audioState => getResource<AudioState>();

  /// The sounds and music by key.
  AudioLibrary? get audioLibrary => getResource<AudioLibrary>();

  /// The volume channels.
  VolumeChannels? get volumeChannels => getResource<VolumeChannels>();

  /// Registers the sound effect at [assetPath] as [key]. It loads in the
  /// background once the engine is up (decoded into memory, for instant
  /// starts).
  void loadSound(String key, String assetPath) =>
      _library.addSound(key, assetPath);

  /// Registers the music track at [assetPath] as [key]. It loads in the
  /// background once the engine is up (streamed while it plays).
  void loadMusic(String key, String assetPath) =>
      _library.addMusic(key, assetPath);

  AudioLibrary get _library {
    final library = audioLibrary;
    if (library == null) {
      throw StateError('No AudioLibrary: add AudioPlugin to the app first');
    }
    return library;
  }

  /// Plays a sound effect; with [position], attenuated and panned relative
  /// to the active `AudioListener`.
  ///
  /// ```dart
  /// world.playSfx('footstep', volume: 0.5);
  /// world.playSfx('door', position: (120.0, 40.0));
  /// ```
  void playSfx(
    String soundKey, {
    double volume = 1.0,
    double playbackSpeed = 1.0,
    (double, double)? position,
  }) {
    eventWriter<PlaySfxRequest>().send(
      PlaySfxRequest(
        soundKey,
        volume: volume,
        playbackSpeed: playbackSpeed,
        position: position,
      ),
    );
  }

  /// Plays a music track, fading from the current one (or from silence)
  /// over [crossfade]. Asking for the track already playing changes nothing
  /// unless [restart] is set; a track still loading starts when it's ready.
  ///
  /// ```dart
  /// world.playMusic('town', crossfade: Duration(seconds: 3));
  /// ```
  void playMusic(
    String musicKey, {
    bool loop = true,
    double volume = 1.0,
    Duration? crossfade,
    double startPosition = 0.0,
    bool restart = false,
  }) {
    eventWriter<PlayMusicRequest>().send(
      PlayMusicRequest(
        musicKey,
        loop: loop,
        volume: volume,
        crossfadeDuration: crossfade,
        startPosition: startPosition,
        restart: restart,
      ),
    );
  }

  /// Stops the music, fading out over [fadeOut].
  void stopMusic({Duration? fadeOut}) {
    eventWriter<StopMusicRequest>().send(
      StopMusicRequest(fadeOutDuration: fadeOut),
    );
  }

  /// Pauses all audio.
  void pauseAudio() =>
      eventWriter<PauseAudioRequest>().send(const PauseAudioRequest());

  /// Resumes all audio.
  void resumeAudio() =>
      eventWriter<ResumeAudioRequest>().send(const ResumeAudioRequest());

  /// Pauses audio if it's playing, resumes it if it's paused.
  void toggleAudioPause() {
    if (audioState?.isPaused ?? false) {
      resumeAudio();
    } else {
      pauseAudio();
    }
  }

  /// Sets a channel's volume, fading over [fade].
  ///
  /// ```dart
  /// world.setVolume(AudioChannel.music, 0.5);
  /// world.setVolume(AudioChannel.master, 0.8, fade: Duration(seconds: 1));
  /// ```
  void setVolume(AudioChannel channel, double volume, {Duration? fade}) {
    eventWriter<SetChannelVolumeRequest>().send(
      SetChannelVolumeRequest(channel, volume, fadeDuration: fade),
    );
  }

  /// A channel's current volume.
  double getVolume(AudioChannel channel) =>
      volumeChannels?.getVolume(channel) ?? 1.0;

  /// Runs audio for one frame while the world isn't ticking: menus, a
  /// loading screen, a singleplayer pause. Requests made meanwhile are
  /// carried out, clips keep loading, fades and focus pause keep working.
  ///
  /// Only audio's own event queues advance, so gameplay events waiting for
  /// the next tick are untouched. [delta] (seconds since the last frame)
  /// drives channel volume fades.
  ///
  /// ```dart
  /// void onFrame() {
  ///   if (playing) {
  ///     app.tick();
  ///   } else {
  ///     app.world.pumpAudio(delta: dt);
  ///   }
  /// }
  /// ```
  Future<void> pumpAudio({double delta = 0}) async {
    final pump = getResource<AudioPump>();
    if (pump == null) return;
    pump.swapAudioEvents(this);
    final time = getResource<WallTime>();
    final before = time?.delta;
    time?.delta = delta;
    try {
      for (final system in pump.systems) {
        if (system.shouldRun(this)) await system.run(this);
      }
    } finally {
      if (time != null) time.delta = before!;
    }
  }

  /// Whether music is playing.
  bool get isMusicPlaying => audioState?.isMusicPlaying ?? false;

  /// The key of the music playing now.
  String? get currentMusicKey => audioState?.currentMusicKey;

  /// Whether audio is paused.
  bool get isAudioPaused => audioState?.isPaused ?? false;
}
