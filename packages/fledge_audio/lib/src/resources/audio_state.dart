import '../backend/audio_backend.dart';
import '../events/audio_events.dart';

/// Playback state: the engine, what music is playing, live sound voices.
///
/// Inserted by `AudioPlugin` when the app is built (so requests can be
/// made from the first frame); [isInitialized] turns true once the engine
/// has started.
///
/// ```dart
/// final state = world.audioState!;
/// print('Track: ${state.currentMusicKey}, playing: ${state.isMusicPlaying}');
/// ```
class AudioState {
  AudioState(this.backend);

  /// The engine everything plays through.
  final AudioBackend backend;

  /// Whether the engine has started. Requests made before then wait.
  bool isInitialized = false;

  /// Why the engine couldn't start, if it couldn't (audio stays off).
  Object? initError;

  /// The music track playing now (fading in included), by key.
  String? currentMusicKey;

  /// Its voice.
  AudioVoice? currentMusicVoice;

  /// The volume it was asked to play at, before the music channel.
  double musicVolume = 1.0;

  /// Whether it loops.
  bool musicLooping = true;

  /// Seconds left of its fade-in (a channel change meanwhile re-targets
  /// the fade rather than cutting it short).
  double musicFadeRemaining = 0.0;

  /// The music channel's effective volume last applied to the track.
  double appliedMusicChannel = 1.0;

  /// Tracks fading out after a crossfade or a fading stop; each stops
  /// itself at the end of its fade.
  final List<AudioVoice> fadingOut = [];

  /// The latest music request still waiting (for the engine or its clip).
  /// Only the latest counts: asking for track B while A is loading means B.
  MusicRequest? pendingMusic;

  /// Whether audio is paused (everything: music, effects, sources).
  bool isPaused = false;

  /// Whether the pause came from the window losing focus (and so ends when
  /// it comes back).
  bool pausedByFocusLoss = false;

  /// Live sound voices (effects and spatial sources), with their keys.
  final Map<AudioVoice, String> sounds = {};

  /// Whether a music track is playing (or paused) now.
  bool get isMusicPlaying =>
      currentMusicVoice != null && backend.isPlaying(currentMusicVoice!);

  /// Whether a track is fading out under the current one.
  bool get isCrossfading => fadingOut.isNotEmpty;

  /// Number of live sound voices.
  int get activeSoundCount => sounds.length;

  /// Pauses every voice. Returns false if already paused.
  bool pauseAll() {
    if (isPaused) return false;
    _setPaused(true);
    isPaused = true;
    return true;
  }

  /// Resumes every voice. Returns false if not paused.
  bool resumeAll() {
    if (!isPaused) return false;
    _setPaused(false);
    isPaused = false;
    pausedByFocusLoss = false;
    return true;
  }

  void _setPaused(bool paused) {
    if (currentMusicVoice != null) {
      backend.setPaused(currentMusicVoice!, paused);
    }
    for (final voice in fadingOut) {
      backend.setPaused(voice, paused);
    }
    for (final voice in sounds.keys) {
      backend.setPaused(voice, paused);
    }
  }
}
