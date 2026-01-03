import 'package:flutter_soloud/flutter_soloud.dart';

import '../resources/audio_channels.dart';

/// Component marking an entity as an audio source.
///
/// Attach to entities that should emit spatial audio.
/// The position is taken from the entity's Transform2D component.
///
/// ```dart
/// world.spawn()
///   ..insert(Transform2D.from(100, 200))
///   ..insert(AudioSource(
///     soundKey: 'engine_loop',
///     channel: AudioChannel.sfx,
///     looping: true,
///     autoPlay: true,
///   ));
/// ```
class AudioSource {
  /// Key of the sound to play (from AudioAssets).
  String? soundKey;

  /// Which channel this source belongs to.
  AudioChannel channel;

  /// Base volume before spatial calculations (0.0 to 1.0).
  double volume;

  /// Whether the sound should loop.
  bool looping;

  /// Whether to start playing automatically when spawned.
  bool autoPlay;

  /// Playback speed/pitch (1.0 = normal).
  double playbackSpeed;

  /// Override for max distance (null = use global config).
  double? maxDistance;

  /// Override for reference distance (null = use global config).
  double? referenceDistance;

  /// Current playback handle (managed by system).
  SoundHandle? handle;

  /// Whether this source has been started.
  bool hasStarted = false;

  /// Whether this source is currently playing.
  bool get isPlaying => handle != null;

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
