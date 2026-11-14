import 'package:flutter_soloud/flutter_soloud.dart';

import 'audio_backend.dart';

/// [AudioBackend] on flutter_soloud: the default engine.
class SoLoudBackend implements AudioBackend {
  /// [soloud] defaults to `SoLoud.instance`, which is only reached when the
  /// engine starts: building an app (headless tests, schedule checks) never
  /// loads the native library.
  SoLoudBackend([SoLoud? soloud]) : _injected = soloud;

  final SoLoud? _injected;
  SoLoud? _instance;
  bool _started = false;

  SoLoud get _soloud => _instance ??= _injected ?? SoLoud.instance;

  SoundHandle _handle(AudioVoice voice) => SoundHandle(voice.id);

  bool _valid(AudioVoice voice) =>
      _started && _soloud.getIsValidVoiceHandle(_handle(voice));

  @override
  Future<void> init() async {
    // Hot restart keeps the engine running.
    if (!_soloud.isInitialized) await _soloud.init();
    _started = true;
  }

  @override
  void deinit() {
    if (_started && _soloud.isInitialized) _soloud.deinit();
    _started = false;
  }

  @override
  Future<Object> load(String assetPath, {required bool stream}) => _soloud
      .loadAsset(assetPath, mode: stream ? LoadMode.disk : LoadMode.memory);

  @override
  void unload(Object source) {
    if (_started) _soloud.disposeSource(source as AudioSource);
  }

  @override
  AudioVoice play(
    Object source, {
    double volume = 1.0,
    double pan = 0.0,
    double speed = 1.0,
    bool looping = false,
    bool paused = false,
  }) {
    final handle = _soloud.play(
      source as AudioSource,
      volume: volume,
      pan: pan,
      looping: looping,
      paused: paused,
    );
    if (speed != 1.0) _soloud.setRelativePlaySpeed(handle, speed);
    return AudioVoice(handle.id);
  }

  @override
  bool isPlaying(AudioVoice voice) => _valid(voice);

  @override
  double volumeOf(AudioVoice voice) =>
      _valid(voice) ? _soloud.getVolume(_handle(voice)) : 0.0;

  @override
  void setVolume(AudioVoice voice, double volume) {
    if (_valid(voice)) _soloud.setVolume(_handle(voice), volume);
  }

  @override
  void fadeVolume(AudioVoice voice, double volume, Duration time) {
    if (_valid(voice)) _soloud.fadeVolume(_handle(voice), volume, time);
  }

  @override
  void setPan(AudioVoice voice, double pan) {
    if (_valid(voice)) _soloud.setPan(_handle(voice), pan);
  }

  @override
  void setPaused(AudioVoice voice, bool paused) {
    if (_valid(voice)) _soloud.setPause(_handle(voice), paused);
  }

  @override
  void seek(AudioVoice voice, Duration position) {
    if (_valid(voice)) _soloud.seek(_handle(voice), position);
  }

  @override
  void stop(AudioVoice voice) {
    if (_valid(voice)) _soloud.stop(_handle(voice));
  }

  @override
  void stopAfter(AudioVoice voice, Duration time) {
    if (_valid(voice)) _soloud.scheduleStop(_handle(voice), time);
  }

  @override
  void setMasterVolume(double volume) {
    if (_started) _soloud.setGlobalVolume(volume);
  }

  @override
  void setMaxVoices(int count) {
    if (_started) _soloud.setMaxActiveVoiceCount(count);
  }
}
