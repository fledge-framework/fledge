import '../backend/audio_backend.dart';
import '../resources/audio_channels.dart';

// ============ Requests (sent by game code) ============

/// Request to play a sound effect.
///
/// ```dart
/// world.playSfx('hoe');
/// world.playSfx('door', position: (120, 40)); // panned and attenuated
/// ```
///
/// A sound whose clip isn't ready yet (or while audio is paused) is
/// skipped, with an [AudioFailed] saying why: a late sound effect would be
/// wrong, unlike late music.
class PlaySfxRequest {
  /// Key of the sound in the `AudioLibrary`.
  final String soundKey;

  /// Volume multiplier (0.0 to 1.0), before the sfx channel.
  final double volume;

  /// Playback speed/pitch (1.0 = normal).
  final double playbackSpeed;

  /// World position: attenuated and panned relative to the active
  /// `AudioListener` (when spatial audio is enabled). Null = not spatial.
  final (double x, double y)? position;

  const PlaySfxRequest(
    this.soundKey, {
    this.volume = 1.0,
    this.playbackSpeed = 1.0,
    this.position,
  });
}

/// A music request: play a track, or stop.
///
/// Music requests wait (for the engine to start, or the track's clip to
/// load); only the latest waiting one counts.
sealed class MusicRequest {
  const MusicRequest();
}

/// Request to play a music track.
///
/// ```dart
/// world.playMusic('town', crossfade: Duration(seconds: 3));
/// ```
///
/// Asking for the track that's already playing changes nothing (its volume
/// aside) unless [restart] is set, so a game can ask for "the music for
/// here" every frame.
class PlayMusicRequest extends MusicRequest {
  /// Key of the track in the `AudioLibrary`.
  final String musicKey;

  /// Whether to loop the track.
  final bool loop;

  /// Volume multiplier (0.0 to 1.0), before the music channel.
  final double volume;

  /// Fade from the current track (or from silence) over this long. Null
  /// cuts straight to the new track.
  final Duration? crossfadeDuration;

  /// Where to start, in seconds.
  final double startPosition;

  /// Start the track over even if it's already playing.
  final bool restart;

  const PlayMusicRequest(
    this.musicKey, {
    this.loop = true,
    this.volume = 1.0,
    this.crossfadeDuration,
    this.startPosition = 0.0,
    this.restart = false,
  });
}

/// Request to stop the music.
class StopMusicRequest extends MusicRequest {
  /// Fade out over this long. Null stops at once.
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

/// Request to change a channel's volume. Applies to music that is already
/// playing, and to spatial sources, as well as to everything started later.
class SetChannelVolumeRequest {
  final AudioChannel channel;

  /// Target volume (0.0 to 1.0).
  final double volume;

  /// Fade to it over this long. Null = at once.
  final Duration? fadeDuration;

  const SetChannelVolumeRequest(this.channel, this.volume, {this.fadeDuration});
}

// ============ Responses (sent by the audio systems) ============

/// A sound effect started.
class SfxStarted {
  final String soundKey;
  final AudioVoice voice;

  const SfxStarted(this.soundKey, this.voice);
}

/// A sound effect (or a spatial source's sound) finished.
class SfxFinished {
  final String soundKey;

  const SfxFinished(this.soundKey);
}

/// A music track started.
class MusicStarted {
  final String musicKey;

  const MusicStarted(this.musicKey);
}

/// A music track that doesn't loop reached its end.
class MusicFinished {
  final String musicKey;

  const MusicFinished(this.musicKey);
}

/// The music changed from one track to another.
class MusicChanged {
  /// The track before, or null if there was silence.
  final String? previousKey;

  final String newKey;

  const MusicChanged({this.previousKey, required this.newKey});
}

/// Something couldn't be played or loaded.
class AudioFailed {
  final String key;
  final String error;

  const AudioFailed(this.key, this.error);

  @override
  String toString() => 'AudioFailed($key: $error)';
}

/// Audio was paused.
class AudioPaused {
  final bool byFocusLoss;

  const AudioPaused({this.byFocusLoss = false});
}

/// Audio was resumed.
class AudioResumed {
  const AudioResumed();
}

/// A clip finished loading and is ready to play.
class AudioAssetLoaded {
  final String key;
  final bool isMusic;

  const AudioAssetLoaded(this.key, {required this.isMusic});
}
