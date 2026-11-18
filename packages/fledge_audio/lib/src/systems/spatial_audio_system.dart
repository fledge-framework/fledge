import 'dart:math';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart' show Transform2D;

import '../components/audio_listener.dart';
import '../components/audio_source.dart';
import '../config/audio_config.dart';
import '../backend/audio_backend.dart';
import '../resources/audio_channels.dart';
import '../resources/audio_library.dart';
import '../resources/audio_state.dart';
import 'audio_cleanup_system.dart';

/// Plays, stops and mixes [AudioSource]s: the system that owns their
/// voices.
///
/// - Carries out [AudioSource.play] and [AudioSource.stop], and starts
///   [AudioSource.autoPlay] sources, once the engine is up and the clip has
///   loaded (while audio is paused, a source starts paused).
/// - Keeps each voice's volume and pan following where the source is
///   relative to the active [AudioListener]: distance attenuates (linear
///   between the reference and max distances), lateral offset pans.
///   A source without a `Transform2D`, with no active listener, or with
///   spatial audio off plays centred at its volume times its channel's.
/// - Stops (with a short fade) the voices of sources that are gone: the
///   entity was despawned, or its [AudioSource] removed or replaced.
///
/// Registered in `Schedules.last` so it reads final per-frame positions
/// (every `Transform2D` writer in `update` has run). Within `last` it runs
/// before [AudioCleanupSystem]; both write [AudioState] and `AudioSource`.
class SpatialAudioSystem implements System {
  /// The `SystemMeta.name` of [SpatialAudioSystem].
  static const String systemName = 'SpatialAudioSystem';

  /// How long the voice of a source that's gone fades out for.
  static const Duration orphanFadeOut = Duration(milliseconds: 100);

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    reads: {ComponentId.of<AudioListener>(), ComponentId.of<Transform2D>()},
    writes: {ComponentId.of<AudioSource>()},
    resourceReads: {SpatialAudioConfig, VolumeChannels, AudioLibrary},
    resourceWrites: {AudioState},
    before: const [AudioCleanupSystem.systemName],
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  void run(World world) {
    // Before the engine is up, requests and auto-plays wait.
    final state = world.getResource<AudioState>();
    if (state == null || !state.isInitialized) return;
    final config = world.getResource<SpatialAudioConfig>();
    final channels = world.getResource<VolumeChannels>()!;
    final library = world.getResource<AudioLibrary>()!;
    final backend = state.backend;

    final listener = config != null && config.enabled
        ? listenerPosition(world)
        : null;

    // Voices that ended by themselves are no longer the sources' to track.
    state.sourceVoices.removeWhere((voice) => !backend.isPlaying(voice));
    final live = <AudioVoice>{};

    for (final (entity, source) in world.query1<AudioSource>().iter()) {
      final transform = listener == null
          ? null
          : world.get<Transform2D>(entity);
      var volume = source.volume * channels.getEffectiveVolume(source.channel);
      var pan = 0.0;
      if (listener != null && transform != null) {
        final (attenuation, p) = mix(
          listener,
          (transform.translation.x, transform.translation.y),
          config!,
          referenceDistance: source.referenceDistance,
          maxDistance: source.maxDistance,
        );
        volume *= attenuation;
        pan = p;
      }

      final request = source.request;
      if (request != null && request.isStop) {
        source
          ..request = null
          ..hasStarted = true; // a pending auto-play never starts
        final voice = source.voice;
        if (voice != null) {
          source.voice = null;
          state.sourceVoices.remove(voice);
          _stop(state, voice, request.fadeOut);
        }
      } else if (request != null || (source.autoPlay && !source.hasStarted)) {
        if (_start(state, library, source, volume, pan)) source.request = null;
      }

      final voice = source.voice;
      if (voice == null) continue;
      if (!backend.isPlaying(voice)) {
        source.voice = null;
        continue;
      }
      live.add(voice);
      backend
        ..setVolume(voice, volume)
        ..setPan(voice, pan);
      if (source.voiceSpeed != source.playbackSpeed) {
        backend.setSpeed(voice, source.playbackSpeed);
        source.voiceSpeed = source.playbackSpeed;
      }
    }

    // Voices whose source is gone (despawned, removed or replaced).
    for (final voice in state.sourceVoices.difference(live)) {
      state.sourceVoices.remove(voice);
      _stop(state, voice, orphanFadeOut);
    }
  }

  /// Starts [source]'s clip (restarting it if it's playing). False if the
  /// clip isn't ready yet, so the start waits.
  static bool _start(
    AudioState state,
    AudioLibrary library,
    AudioSource source,
    double volume,
    double pan,
  ) {
    final key = source.soundKey;
    if (key == null) return false;
    final clip = library.clipOf(key);
    if (clip == null) return false;
    final backend = state.backend;
    final previous = source.voice;
    if (previous != null) {
      state.sourceVoices.remove(previous);
      backend.stop(previous);
    }
    final voice = backend.play(
      clip.source,
      volume: volume,
      pan: pan,
      speed: source.playbackSpeed,
      looping: source.looping,
      paused: state.isPaused,
    );
    source
      ..voice = voice
      ..voiceSpeed = source.playbackSpeed
      ..hasStarted = true;
    state.sounds[voice] = key;
    state.sourceVoices.add(voice);
    return true;
  }

  /// Stops [voice], fading out over [fade] unless audio is paused (nobody
  /// would hear it, and a paused voice's fade waits). It stays in
  /// [AudioState.sounds] until it ends, so `AudioCleanupSystem` reports it.
  static void _stop(AudioState state, AudioVoice voice, Duration? fade) {
    final backend = state.backend;
    if (fade == null || fade <= Duration.zero || state.isPaused) {
      backend.stop(voice);
      return;
    }
    backend
      ..fadeVolume(voice, 0, fade)
      ..stopAfter(voice, fade);
  }

  /// Where the first active [AudioListener] with a `Transform2D` is, or
  /// null if there's none.
  static (double, double)? listenerPosition(World world) {
    for (final (_, listener, transform)
        in world.query2<AudioListener, Transform2D>().iter()) {
      if (listener.isActive) {
        return (transform.translation.x, transform.translation.y);
      }
    }
    return null;
  }

  /// How loud (0..1) and how far left or right (-maxPan..maxPan) a sound at
  /// [source] is, heard from [listener].
  static (double attenuation, double pan) mix(
    (double, double) listener,
    (double, double) source,
    SpatialAudioConfig config, {
    double? referenceDistance,
    double? maxDistance,
  }) {
    final dx = source.$1 - listener.$1;
    final dy = source.$2 - listener.$2;
    final maxDist = maxDistance ?? config.maxDistance;
    final refDist = referenceDistance ?? config.referenceDistance;
    final attenuation = calculateAttenuation(
      sqrt(dx * dx + dy * dy),
      refDist,
      maxDist,
      config.rolloffFactor,
    );
    final pan = (dx / maxDist).clamp(-config.maxPan, config.maxPan);
    return (attenuation, pan);
  }

  /// Linear falloff from [refDistance] (full volume) to [maxDistance]
  /// (silent).
  static double calculateAttenuation(
    double distance,
    double refDistance,
    double maxDistance,
    double rolloff,
  ) {
    if (distance <= refDistance) return 1.0;
    if (distance >= maxDistance) return 0.0;
    final range = maxDistance - refDistance;
    final distFromRef = distance - refDistance;
    return (1.0 - (distFromRef / range) * rolloff).clamp(0.0, 1.0);
  }
}
