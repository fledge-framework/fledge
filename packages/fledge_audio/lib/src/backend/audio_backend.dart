/// One playing sound: a voice the backend can fade, pan, pause or stop.
///
/// An opaque id. A voice stays valid until it stops (it finishes, is
/// stopped, or its scheduled stop arrives); after that [AudioBackend.isPlaying]
/// is false and every other call on it does nothing.
extension type const AudioVoice(int id) {}

/// What fledge_audio needs from an audio engine.
///
/// [SoLoudBackend] (flutter_soloud) is the default. Everything above this
/// interface (loading, music, crossfades, channels, spatial audio) is
/// engine-agnostic, so tests drive it with a fake backend instead of a
/// sound device.
///
/// Calls on a voice that has stopped are no-ops, never errors: voices end
/// on the audio thread at any moment, so callers can't check first.
abstract interface class AudioBackend {
  /// Starts the engine. Called once, by `AudioInitSystem`, which does not
  /// wait for it: the frame goes on and audio starts when it completes.
  Future<void> init();

  /// Stops the engine and frees everything it holds.
  void deinit();

  /// Loads the audio file at [assetPath] (a Flutter asset key). [stream]
  /// decodes it while it plays instead of all at once into memory: right
  /// for music, wrong for short, frequent sounds.
  Future<Object> load(String assetPath, {required bool stream});

  /// Frees a source returned by [load].
  void unload(Object source);

  /// Plays [source] and returns its voice.
  AudioVoice play(
    Object source, {
    double volume = 1.0,
    double pan = 0.0,
    double speed = 1.0,
    bool looping = false,
    bool paused = false,
  });

  /// Whether [voice] is still playing (or paused).
  bool isPlaying(AudioVoice voice);

  /// [voice]'s current volume, mid-fade included.
  double volumeOf(AudioVoice voice);

  void setVolume(AudioVoice voice, double volume);

  /// Fades [voice] to [volume] over [time], on the audio thread (smooth
  /// whatever the frame rate). Replaces any fade in progress on it.
  void fadeVolume(AudioVoice voice, double volume, Duration time);

  void setPan(AudioVoice voice, double pan);

  void setPaused(AudioVoice voice, bool paused);

  /// Jumps [voice] to [position] from its start.
  void seek(AudioVoice voice, Duration position);

  void stop(AudioVoice voice);

  /// Stops [voice] after [time] (on the audio thread).
  void stopAfter(AudioVoice voice, Duration time);

  /// The volume of everything together.
  void setMasterVolume(double volume);

  /// How many voices may sound at once.
  void setMaxVoices(int count);
}
