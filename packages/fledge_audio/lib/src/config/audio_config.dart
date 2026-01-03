/// Configuration for the audio plugin.
///
/// ```dart
/// AudioPlugin(config: AudioConfig(
///   masterVolume: 0.8,
///   channels: AudioChannelConfig(music: 0.7, sfx: 1.0),
///   spatialConfig: SpatialAudioConfig.default2D(),
///   pauseOnFocusLoss: true,
/// ))
/// ```
class AudioConfig {
  /// Initial master volume (0.0 to 1.0).
  final double masterVolume;

  /// Channel volume configuration.
  final AudioChannelConfig channels;

  /// Spatial audio configuration.
  final SpatialAudioConfig spatialConfig;

  /// Whether to pause audio when window loses focus.
  final bool pauseOnFocusLoss;

  /// Maximum concurrent sound effects.
  final int maxConcurrentSounds;

  const AudioConfig({
    this.masterVolume = 1.0,
    this.channels = const AudioChannelConfig(),
    this.spatialConfig = const SpatialAudioConfig(),
    this.pauseOnFocusLoss = true,
    this.maxConcurrentSounds = 32,
  });

  /// Default configuration with sensible game defaults.
  const AudioConfig.defaults() : this();

  /// Configuration with spatial audio disabled.
  const AudioConfig.nonSpatial()
      : masterVolume = 1.0,
        channels = const AudioChannelConfig(),
        spatialConfig = const SpatialAudioConfig(enabled: false),
        pauseOnFocusLoss = true,
        maxConcurrentSounds = 32;
}

/// Volume levels for audio channels.
class AudioChannelConfig {
  /// Music channel volume (0.0 to 1.0).
  final double music;

  /// Sound effects channel volume (0.0 to 1.0).
  final double sfx;

  /// Voice/dialogue channel volume (0.0 to 1.0).
  final double voice;

  /// Ambient/environment channel volume (0.0 to 1.0).
  final double ambient;

  const AudioChannelConfig({
    this.music = 1.0,
    this.sfx = 1.0,
    this.voice = 1.0,
    this.ambient = 1.0,
  });
}

/// Configuration for 2D spatial audio.
class SpatialAudioConfig {
  /// Whether spatial audio is enabled.
  final bool enabled;

  /// Maximum distance at which sounds are audible.
  final double maxDistance;

  /// Distance at which volume starts to fall off.
  final double referenceDistance;

  /// How quickly volume falls off with distance.
  /// 1.0 = linear, 2.0 = inverse square, etc.
  final double rolloffFactor;

  /// Maximum pan value (-1.0 to 1.0).
  final double maxPan;

  const SpatialAudioConfig({
    this.enabled = true,
    this.maxDistance = 1000.0,
    this.referenceDistance = 100.0,
    this.rolloffFactor = 1.0,
    this.maxPan = 0.8,
  });

  /// Default configuration for 2D games.
  const SpatialAudioConfig.default2D()
      : enabled = true,
        maxDistance = 1000.0,
        referenceDistance = 100.0,
        rolloffFactor = 1.0,
        maxPan = 0.8;
}
