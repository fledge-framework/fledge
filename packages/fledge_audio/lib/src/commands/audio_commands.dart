import 'package:fledge_ecs/fledge_ecs.dart';

import '../assets/audio_assets.dart';
import '../events/audio_events.dart';
import '../resources/audio_channels.dart';
import '../resources/audio_state.dart';

/// Extension methods for audio control on [World].
extension AudioCommands on World {
  /// Gets the current audio state, or null if not initialized.
  AudioState? get audioState => getResource<AudioState>();

  /// Gets the audio assets resource.
  AudioAssets? get audioAssets => getResource<AudioAssets>();

  /// Gets the volume channels resource.
  VolumeChannels? get volumeChannels => getResource<VolumeChannels>();

  /// Play a sound effect.
  ///
  /// ```dart
  /// world.playSfx('explosion');
  /// world.playSfx('footstep', volume: 0.5);
  /// world.playSfx('gunshot', position: (100.0, 200.0));
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

  /// Play a music track.
  ///
  /// ```dart
  /// world.playMusic('main_theme');
  /// world.playMusic('battle', crossfade: Duration(seconds: 2));
  /// ```
  void playMusic(
    String musicKey, {
    bool loop = true,
    double volume = 1.0,
    Duration? crossfade,
    double startPosition = 0.0,
  }) {
    eventWriter<PlayMusicRequest>().send(
      PlayMusicRequest(
        musicKey,
        loop: loop,
        volume: volume,
        crossfadeDuration: crossfade,
        startPosition: startPosition,
      ),
    );
  }

  /// Stop the current music.
  ///
  /// ```dart
  /// world.stopMusic();
  /// world.stopMusic(fadeOut: Duration(seconds: 1));
  /// ```
  void stopMusic({Duration? fadeOut}) {
    eventWriter<StopMusicRequest>().send(
      StopMusicRequest(fadeOutDuration: fadeOut),
    );
  }

  /// Pause all audio.
  void pauseAudio() {
    eventWriter<PauseAudioRequest>().send(const PauseAudioRequest());
  }

  /// Resume all audio.
  void resumeAudio() {
    eventWriter<ResumeAudioRequest>().send(const ResumeAudioRequest());
  }

  /// Toggle audio pause state.
  void toggleAudioPause() {
    if (audioState?.isPaused ?? false) {
      resumeAudio();
    } else {
      pauseAudio();
    }
  }

  /// Set the volume for a channel.
  ///
  /// ```dart
  /// world.setVolume(AudioChannel.music, 0.5);
  /// world.setVolume(AudioChannel.master, 0.8, fade: Duration(seconds: 1));
  /// ```
  void setVolume(AudioChannel channel, double volume, {Duration? fade}) {
    eventWriter<SetChannelVolumeRequest>().send(
      SetChannelVolumeRequest(
        channel,
        volume,
        fadeDuration: fade,
      ),
    );
  }

  /// Get the current volume for a channel.
  double getVolume(AudioChannel channel) {
    return volumeChannels?.getVolume(channel) ?? 1.0;
  }

  /// Preload an audio asset.
  ///
  /// ```dart
  /// world.preloadAudio('assets/sounds/explosion.wav', key: 'explosion');
  /// world.preloadAudio('assets/music/theme.mp3', key: 'theme', isMusic: true);
  /// ```
  void preloadAudio(
    String assetPath, {
    required String key,
    bool isMusic = false,
  }) {
    eventWriter<PreloadAudioRequest>().send(
      PreloadAudioRequest(
        assetPath: assetPath,
        key: key,
        isMusic: isMusic,
      ),
    );
  }

  /// Check if music is currently playing.
  bool get isMusicPlaying => audioState?.isMusicPlaying ?? false;

  /// Get the key of the currently playing music track.
  String? get currentMusicKey => audioState?.currentMusicKey;

  /// Check if audio is paused.
  bool get isAudioPaused => audioState?.isPaused ?? false;
}
