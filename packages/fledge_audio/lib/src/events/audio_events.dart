import 'package:flutter_soloud/flutter_soloud.dart';

import '../resources/audio_channels.dart';

// ============ Request Events (sent by game code) ============

/// Request to play a sound effect.
///
/// ```dart
/// world.eventWriter<PlaySfxRequest>().send(PlaySfxRequest('explosion'));
/// // Or use convenience method:
/// world.playSfx('explosion');
/// ```
class PlaySfxRequest {
  /// Key of the sound in AudioAssets.
  final String soundKey;

  /// Volume multiplier (0.0 to 1.0).
  final double volume;

  /// Playback speed/pitch (1.0 = normal).
  final double playbackSpeed;

  /// Position for spatial audio (null = non-spatial).
  final (double x, double y)? position;

  const PlaySfxRequest(
    this.soundKey, {
    this.volume = 1.0,
    this.playbackSpeed = 1.0,
    this.position,
  });
}

/// Request to play music.
///
/// ```dart
/// world.eventWriter<PlayMusicRequest>().send(PlayMusicRequest('battle_theme'));
/// // Or:
/// world.playMusic('battle_theme', crossfade: Duration(seconds: 2));
/// ```
class PlayMusicRequest {
  /// Key of the music track in AudioAssets.
  final String musicKey;

  /// Whether to loop the track.
  final bool loop;

  /// Volume (0.0 to 1.0).
  final double volume;

  /// Crossfade duration (null = instant switch).
  final Duration? crossfadeDuration;

  /// Starting position in seconds.
  final double startPosition;

  const PlayMusicRequest(
    this.musicKey, {
    this.loop = true,
    this.volume = 1.0,
    this.crossfadeDuration,
    this.startPosition = 0.0,
  });
}

/// Request to stop music.
class StopMusicRequest {
  /// Fade out duration (null = instant stop).
  final Duration? fadeOutDuration;

  const StopMusicRequest({this.fadeOutDuration});
}

/// Request to pause all audio.
class PauseAudioRequest {
  const PauseAudioRequest();
}

/// Request to resume all audio.
class ResumeAudioRequest {
  const ResumeAudioRequest();
}

/// Request to change channel volume.
class SetChannelVolumeRequest {
  /// The channel to adjust.
  final AudioChannel channel;

  /// Target volume (0.0 to 1.0).
  final double volume;

  /// Fade duration (null = instant change).
  final Duration? fadeDuration;

  const SetChannelVolumeRequest(
    this.channel,
    this.volume, {
    this.fadeDuration,
  });
}

/// Request to preload an audio asset.
class PreloadAudioRequest {
  /// Asset path.
  final String assetPath;

  /// Key to store under.
  final String key;

  /// Whether this is music (vs sound effect).
  final bool isMusic;

  const PreloadAudioRequest({
    required this.assetPath,
    required this.key,
    this.isMusic = false,
  });
}

// ============ Response Events (fired by systems) ============

/// Event fired when a sound effect starts playing.
class SfxStarted {
  /// Key of the sound.
  final String soundKey;

  /// Playback handle for this instance.
  final SoundHandle handle;

  const SfxStarted(this.soundKey, this.handle);
}

/// Event fired when a sound effect finishes.
class SfxFinished {
  /// Key of the sound that finished.
  final String soundKey;

  const SfxFinished(this.soundKey);
}

/// Event fired when music starts playing.
class MusicStarted {
  /// Key of the music track.
  final String musicKey;

  const MusicStarted(this.musicKey);
}

/// Event fired when music finishes (if not looping).
class MusicFinished {
  /// Key of the music track that finished.
  final String musicKey;

  const MusicFinished(this.musicKey);
}

/// Event fired when music changes (crossfade complete).
class MusicChanged {
  /// Previous track key (null if none was playing).
  final String? previousKey;

  /// New track key.
  final String newKey;

  const MusicChanged({this.previousKey, required this.newKey});
}

/// Event fired when audio fails to play.
class AudioFailed {
  /// Key of the audio that failed.
  final String key;

  /// Error message.
  final String error;

  const AudioFailed(this.key, this.error);
}

/// Event fired when audio is paused.
class AudioPaused {
  /// Whether paused due to focus loss.
  final bool byFocusLoss;

  const AudioPaused({this.byFocusLoss = false});
}

/// Event fired when audio is resumed.
class AudioResumed {
  const AudioResumed();
}

/// Event fired when an asset is preloaded.
class AudioAssetLoaded {
  /// Asset key.
  final String key;

  /// Whether this is music (vs sound effect).
  final bool isMusic;

  const AudioAssetLoaded(this.key, {required this.isMusic});
}
