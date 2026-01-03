import '../config/audio_config.dart';

/// Audio channel identifiers.
enum AudioChannel {
  /// Master volume affecting all channels.
  master,

  /// Background music channel.
  music,

  /// Sound effects channel.
  sfx,

  /// Voice/dialogue channel.
  voice,

  /// Ambient/environment sounds channel.
  ambient,
}

/// Resource for managing volume levels per channel.
///
/// ```dart
/// final channels = world.getResource<VolumeChannels>()!;
/// channels.setVolume(AudioChannel.music, 0.5);
/// final musicVol = channels.getVolume(AudioChannel.music);
/// ```
class VolumeChannels {
  final Map<AudioChannel, double> _volumes = {};

  VolumeChannels(AudioChannelConfig config) {
    _volumes[AudioChannel.master] = 1.0;
    _volumes[AudioChannel.music] = config.music;
    _volumes[AudioChannel.sfx] = config.sfx;
    _volumes[AudioChannel.voice] = config.voice;
    _volumes[AudioChannel.ambient] = config.ambient;
  }

  /// Get the volume for a channel (0.0 to 1.0).
  double getVolume(AudioChannel channel) => _volumes[channel] ?? 1.0;

  /// Set the volume for a channel (0.0 to 1.0).
  void setVolume(AudioChannel channel, double volume) {
    _volumes[channel] = volume.clamp(0.0, 1.0);
  }

  /// Get the effective volume for a channel (includes master).
  double getEffectiveVolume(AudioChannel channel) {
    if (channel == AudioChannel.master) return getVolume(AudioChannel.master);
    return getVolume(AudioChannel.master) * getVolume(channel);
  }

  /// Mute a channel (sets to 0).
  void mute(AudioChannel channel) => setVolume(channel, 0.0);

  /// Whether a channel is effectively muted.
  bool isMuted(AudioChannel channel) => getEffectiveVolume(channel) == 0.0;
}
