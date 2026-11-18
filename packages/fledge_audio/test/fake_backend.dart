import 'dart:async';

import 'package:fledge_audio/fledge_audio.dart';

/// A voice in [FakeBackend]: what the engine was told about it.
class FakeVoice {
  FakeVoice(
    this.source,
    this.volume,
    this.pan,
    this.looping,
    this.paused, {
    this.speed = 1.0,
  });

  final Object source;
  double volume;
  double pan;
  final bool looping;
  bool paused;
  double speed;
  bool playing = true;

  /// The last fade asked for: (to, over).
  (double, Duration)? fade;

  /// When it was told to stop itself.
  Duration? stopAfter;

  Duration? seekTo;
}

/// An [AudioBackend] with no sound device: it records every call, and
/// tests complete engine start and loads when they choose.
class FakeBackend implements AudioBackend {
  final Completer<void> _init = Completer<void>();
  final Map<String, Completer<Object>> loads = {};
  final Map<String, bool> streamed = {};
  final Map<int, FakeVoice> voices = {};
  final List<Object> unloaded = [];
  double masterVolume = 1.0;
  int maxVoices = 0;
  int _next = 1;

  /// Finishes starting the engine.
  void start() => _init.complete();

  /// Fails starting the engine.
  void failStart(Object error) => _init.completeError(error);

  /// Finishes loading [path]; its source is the path itself.
  void finishLoad(String path) => loads[path]!.complete('source:$path');

  void failLoad(String path, Object error) => loads[path]!.completeError(error);

  FakeVoice voice(AudioVoice v) => voices[v.id]!;

  /// The voices still playing, with their sources.
  Iterable<FakeVoice> get playing => voices.values.where((v) => v.playing);

  /// Ends a voice, as its fade-out or its last sample would.
  void end(AudioVoice v) => voices[v.id]!.playing = false;

  @override
  Future<void> init() => _init.future;

  @override
  void deinit() {}

  @override
  Future<Object> load(String assetPath, {required bool stream}) {
    streamed[assetPath] = stream;
    return (loads[assetPath] = Completer<Object>()).future;
  }

  @override
  void unload(Object source) => unloaded.add(source);

  @override
  AudioVoice play(
    Object source, {
    double volume = 1.0,
    double pan = 0.0,
    double speed = 1.0,
    bool looping = false,
    bool paused = false,
  }) {
    final id = _next++;
    voices[id] = FakeVoice(source, volume, pan, looping, paused, speed: speed);
    return AudioVoice(id);
  }

  FakeVoice? _live(AudioVoice v) {
    final voice = voices[v.id];
    return voice != null && voice.playing ? voice : null;
  }

  @override
  bool isPlaying(AudioVoice voice) => _live(voice) != null;

  @override
  double volumeOf(AudioVoice voice) => _live(voice)?.volume ?? 0.0;

  @override
  void setVolume(AudioVoice voice, double volume) =>
      _live(voice)?.volume = volume;

  @override
  void fadeVolume(AudioVoice voice, double volume, Duration time) =>
      _live(voice)?.fade = (volume, time);

  @override
  void setPan(AudioVoice voice, double pan) => _live(voice)?.pan = pan;

  @override
  void setSpeed(AudioVoice voice, double speed) => _live(voice)?.speed = speed;

  @override
  void setPaused(AudioVoice voice, bool paused) =>
      _live(voice)?.paused = paused;

  @override
  void seek(AudioVoice voice, Duration position) =>
      _live(voice)?.seekTo = position;

  @override
  void stop(AudioVoice voice) => _live(voice)?.playing = false;

  @override
  void stopAfter(AudioVoice voice, Duration time) =>
      _live(voice)?.stopAfter = time;

  @override
  void setMasterVolume(double volume) => masterVolume = volume;

  @override
  void setMaxVoices(int count) => maxVoices = count;
}
