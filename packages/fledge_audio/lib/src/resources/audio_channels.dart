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

/// In-progress linear fade on a single channel.
class _ChannelFade {
  final double start;
  final double target;
  final double durationSecs;
  double elapsed = 0;

  _ChannelFade({
    required this.start,
    required this.target,
    required this.durationSecs,
  });
}

/// Resource for managing volume levels per channel.
///
/// ```dart
/// final channels = world.getResource<VolumeChannels>()!;
/// channels.setVolume(AudioChannel.music, 0.5);
/// final musicVol = channels.getVolume(AudioChannel.music);
/// ```
///
/// Volume fades are driven by [ChannelFadeSystem], which calls
/// [advanceFades] each frame.
class VolumeChannels {
  final Map<AudioChannel, double> _volumes = {};
  final Map<AudioChannel, _ChannelFade> _fades = {};

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
  ///
  /// Cancels any fade in progress on [channel].
  void setVolume(AudioChannel channel, double volume) {
    _volumes[channel] = volume.clamp(0.0, 1.0);
    _fades.remove(channel);
  }

  /// Start a linear fade from the current volume on [channel] to [target]
  /// over [duration].
  ///
  /// Replaces any fade already in progress on the same channel. A zero or
  /// negative duration jumps to [target] immediately.
  void fadeTo(AudioChannel channel, double target, Duration duration) {
    final clampedTarget = target.clamp(0.0, 1.0);
    final secs = duration.inMicroseconds / 1e6;
    if (secs <= 0) {
      setVolume(channel, clampedTarget);
      return;
    }
    _fades[channel] = _ChannelFade(
      start: getVolume(channel),
      target: clampedTarget,
      durationSecs: secs,
    );
  }

  /// Advance every active fade by [deltaSecs] seconds.
  ///
  /// Called once per frame by `ChannelFadeSystem`. Safe to call when no
  /// fades are active.
  void advanceFades(double deltaSecs) {
    if (_fades.isEmpty || deltaSecs <= 0) return;
    final completed = <AudioChannel>[];
    _fades.forEach((channel, fade) {
      fade.elapsed += deltaSecs;
      final t = (fade.elapsed / fade.durationSecs).clamp(0.0, 1.0);
      _volumes[channel] =
          (fade.start + (fade.target - fade.start) * t).clamp(0.0, 1.0);
      if (t >= 1.0) {
        _volumes[channel] = fade.target;
        completed.add(channel);
      }
    });
    for (final channel in completed) {
      _fades.remove(channel);
    }
  }

  /// Whether a fade is currently in progress on [channel].
  bool isFading(AudioChannel channel) => _fades.containsKey(channel);

  /// Get the effective volume for a channel (includes master).
  double getEffectiveVolume(AudioChannel channel) {
    if (channel == AudioChannel.master) return getVolume(AudioChannel.master);
    return getVolume(AudioChannel.master) * getVolume(channel);
  }

  /// Mute a channel (sets to 0). Cancels any active fade.
  void mute(AudioChannel channel) => setVolume(channel, 0.0);

  /// Whether a channel is effectively muted.
  bool isMuted(AudioChannel channel) => getEffectiveVolume(channel) == 0.0;
}
