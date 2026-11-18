import '../backend/audio_backend.dart';

import '../resources/audio_channels.dart';

/// Component marking an entity as an audio source.
///
/// With a `Transform2D` (and an active `AudioListener` somewhere), the
/// sound is attenuated and panned by where the entity is. Without one, or
/// with no listener or spatial audio off, it plays centred at [volume]
/// times its channel's volume.
///
/// [play] starts it (or restarts it from the beginning), [stop] stops it,
/// optionally fading out; both are carried out by `SpatialAudioSystem` at
/// the end of the frame, and a stopped source can be played again.
/// Despawning the entity or removing the component stops its sound too.
///
/// ```dart
/// final engine = world.spawn()
///   ..insert(Transform2D.from(100, 200))
///   ..insert(AudioSource.looping(soundKey: 'engine_loop'));
///
/// // Later:
/// world.get<AudioSource>(engine.entity)!
///     .stop(fadeOut: const Duration(milliseconds: 500));
/// // And again:
/// world.get<AudioSource>(engine.entity)!.play();
/// ```
class AudioSource {
  /// Key of the sound to play (from the `AudioLibrary`).
  String? soundKey;

  /// Which channel this source belongs to.
  AudioChannel channel;

  /// Base volume before spatial calculations (0.0 to 1.0).
  double volume;

  /// Whether the sound should loop.
  bool looping;

  /// Whether to start playing automatically, as soon as the engine is up
  /// and the clip has loaded. A [stop] before then cancels it.
  bool autoPlay;

  /// Playback speed/pitch (1.0 = normal). Changing it while the source
  /// plays changes the voice's speed too (an engine's hum rising with its
  /// revs), on the next `SpatialAudioSystem` run.
  double playbackSpeed;

  /// Override for max distance (null = use global config).
  double? maxDistance;

  /// Override for reference distance (null = use global config).
  double? referenceDistance;

  /// The voice playing it (managed by `SpatialAudioSystem`).
  AudioVoice? voice;

  /// The speed [voice] was last given (managed by `SpatialAudioSystem`).
  double? voiceSpeed;

  /// Whether this source has been started (or stopped, which cancels a
  /// pending [autoPlay]).
  bool hasStarted = false;

  /// A [play] or [stop] not yet carried out by `SpatialAudioSystem`. Only
  /// the latest call counts.
  AudioSourceRequest? request;

  /// Whether this source is currently playing (or paused with all audio).
  bool get isPlaying => voice != null;

  /// Plays the sound from the beginning: starts it, or restarts it if it's
  /// playing. It starts once the engine is up and the clip has loaded; while
  /// audio is paused it starts paused, and is heard on resume.
  void play() => request = const AudioSourceRequest.play();

  /// Stops the sound, fading out over [fadeOut] (at once without one, or
  /// while audio is paused). A pending start ([play] or [autoPlay]) is
  /// cancelled. [isPlaying] turns false as soon as it's carried out, and
  /// [play] may start the source again straight away.
  void stop({Duration? fadeOut}) =>
      request = AudioSourceRequest.stop(fadeOut: fadeOut);

  AudioSource({
    this.soundKey,
    this.channel = AudioChannel.sfx,
    this.volume = 1.0,
    this.looping = false,
    this.autoPlay = false,
    this.playbackSpeed = 1.0,
    this.maxDistance,
    this.referenceDistance,
  });

  /// Create an ambient/environmental sound source.
  factory AudioSource.ambient({
    required String soundKey,
    double volume = 1.0,
    bool looping = true,
    double? maxDistance,
  }) {
    return AudioSource(
      soundKey: soundKey,
      channel: AudioChannel.ambient,
      volume: volume,
      looping: looping,
      autoPlay: true,
      maxDistance: maxDistance,
    );
  }

  /// Create a looping sound source (e.g., engine, fan).
  factory AudioSource.looping({
    required String soundKey,
    AudioChannel channel = AudioChannel.sfx,
    double volume = 1.0,
    bool autoPlay = true,
  }) {
    return AudioSource(
      soundKey: soundKey,
      channel: channel,
      volume: volume,
      looping: true,
      autoPlay: autoPlay,
    );
  }
}

/// What [AudioSource.play] or [AudioSource.stop] asked for.
final class AudioSourceRequest {
  /// Start (or restart) the source.
  const AudioSourceRequest.play() : isStop = false, fadeOut = null;

  /// Stop the source, fading out over [fadeOut].
  const AudioSourceRequest.stop({this.fadeOut}) : isStop = true;

  /// Whether this is a stop (otherwise a play).
  final bool isStop;

  /// How long a stop fades out for (null: at once).
  final Duration? fadeOut;
}
