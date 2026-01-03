import 'package:flutter_soloud/flutter_soloud.dart';

/// Resource containing current audio playback state.
///
/// Access via `world.getResource<AudioState>()` or `world.audioState`.
///
/// ```dart
/// final state = world.audioState;
/// print('Music playing: ${state?.isMusicPlaying}');
/// print('Current track: ${state?.currentMusicKey}');
/// ```
class AudioState {
  /// The underlying SoLoud instance.
  final SoLoud soloud;

  /// Currently playing music handle (if any).
  SoundHandle? currentMusicHandle;

  /// Key of currently playing music track.
  String? currentMusicKey;

  /// Music that is fading out (during crossfade).
  SoundHandle? fadingOutMusicHandle;

  /// Duration of active crossfade.
  Duration? crossfadeDuration;

  /// Elapsed time in current crossfade.
  double crossfadeElapsed = 0.0;

  /// Target volume for new music during crossfade.
  double crossfadeTargetVolume = 1.0;

  /// Whether audio is globally paused.
  bool isPaused = false;

  /// Whether audio was paused due to focus loss.
  bool pausedByFocusLoss = false;

  /// Active sound effect handles for tracking.
  final Set<SoundHandle> _activeSounds = {};

  /// Whether the audio engine has been initialized.
  bool isInitialized = false;

  AudioState(this.soloud);

  /// Whether music is currently playing.
  bool get isMusicPlaying {
    if (currentMusicHandle == null) return false;
    return soloud.getIsValidVoiceHandle(currentMusicHandle!);
  }

  /// Whether a crossfade is in progress.
  bool get isCrossfading =>
      crossfadeDuration != null && fadingOutMusicHandle != null;

  /// Current music playback position in seconds.
  double get musicPosition {
    if (currentMusicHandle == null) return 0.0;
    final position = soloud.getPosition(currentMusicHandle!);
    return position.inMilliseconds / 1000.0;
  }

  /// Number of currently active sound effects.
  int get activeSoundCount => _activeSounds.length;

  /// Register an active sound handle (internal use).
  void registerSound(SoundHandle handle) {
    _activeSounds.add(handle);
  }

  /// Unregister a sound handle (internal use).
  void unregisterSound(SoundHandle handle) {
    _activeSounds.remove(handle);
  }

  /// Clean up finished sounds (called by AudioCleanupSystem).
  void cleanupFinishedSounds() {
    _activeSounds.removeWhere(
      (handle) => !soloud.getIsValidVoiceHandle(handle),
    );
  }

  /// All active sound handles (read-only).
  Iterable<SoundHandle> get activeSounds => _activeSounds;
}
