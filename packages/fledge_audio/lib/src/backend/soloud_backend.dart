import 'package:flutter/services.dart' show AssetBundle;
import 'package:flutter_soloud/flutter_soloud.dart';

import 'audio_backend.dart';

/// [AudioBackend] on flutter_soloud: the default engine.
class SoLoudBackend implements AudioBackend {
  /// [soloud] defaults to `SoLoud.instance`, which is only reached when the
  /// engine starts: building an app (headless tests, schedule checks) never
  /// loads the native library.
  ///
  /// With [bundle], clips are read through it and handed to the engine from
  /// memory (`loadMem`), so a game can serve its audio from its own bundle
  /// (a packed or encrypted one) and no copy of it is written to disk.
  /// Without, flutter_soloud's `loadAsset` reads the app's assets.
  SoLoudBackend([SoLoud? soloud, this.bundle]) : _injected = soloud;

  final SoLoud? _injected;

  /// Where clips are read from, if not the app's own assets.
  final AssetBundle? bundle;
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
  Future<Object> load(String assetPath, {required bool stream}) async {
    final mode = stream ? LoadMode.disk : LoadMode.memory;
    final from = bundle;
    if (from == null) return _soloud.loadAsset(assetPath, mode: mode);
    final data = await from.load(assetPath);
    return _soloud.loadMem(
      assetPath,
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      mode: mode,
    );
  }

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
  void setSpeed(AudioVoice voice, double speed) {
    if (_valid(voice)) {
      _soloud.setRelativePlaySpeed(
        _handle(voice),
        speed < AudioBackend.minSpeed ? AudioBackend.minSpeed : speed,
      );
    }
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
