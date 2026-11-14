import 'dart:math';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart' show Transform2D;

import '../components/audio_listener.dart';
import '../components/audio_source.dart';
import '../config/audio_config.dart';
import '../resources/audio_channels.dart';
import '../resources/audio_library.dart';
import '../resources/audio_state.dart';
import 'audio_cleanup_system.dart';

/// Plays [AudioSource]s and keeps their volume and pan following where they
/// are relative to the active [AudioListener].
///
/// Distance attenuates (linear between the reference and max distances),
/// lateral offset pans. Listeners and sources without a `Transform2D` are
/// skipped; sources without one keep whatever volume and pan they started
/// with.
///
/// Registered in `Schedules.last` so it reads final per-frame positions
/// (every `Transform2D` writer in `update` has run). Within `last` it runs
/// before [AudioCleanupSystem]; both write [AudioState] and `AudioSource`.
class SpatialAudioSystem implements System {
  /// The `SystemMeta.name` of [SpatialAudioSystem].
  static const String systemName = 'SpatialAudioSystem';

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
  Future<void> run(World world) async {
    final config = world.getResource<SpatialAudioConfig>();
    if (config == null || !config.enabled) return;
    final state = world.getResource<AudioState>();
    if (state == null || !state.isInitialized) return;
    final channels = world.getResource<VolumeChannels>()!;
    final library = world.getResource<AudioLibrary>()!;
    final backend = state.backend;

    final listener = listenerPosition(world);
    if (listener == null) return;

    for (final (_, source, transform)
        in world.query2<AudioSource, Transform2D>().iter()) {
      // Start auto-play sources once their clip is ready (and not while
      // audio is paused).
      if (source.autoPlay &&
          !source.hasStarted &&
          !state.isPaused &&
          source.soundKey != null) {
        final clip = library.clipOf(source.soundKey!);
        if (clip != null) {
          final voice = backend.play(
            clip.source,
            volume: 0.0, // set below
            speed: source.playbackSpeed,
            looping: source.looping,
          );
          source
            ..voice = voice
            ..hasStarted = true;
          state.sounds[voice] = source.soundKey!;
        }
      }

      final voice = source.voice;
      if (voice == null) continue;
      if (!backend.isPlaying(voice)) {
        source.voice = null;
        continue;
      }
      final (attenuation, pan) = mix(
        listener,
        (transform.translation.x, transform.translation.y),
        config,
        referenceDistance: source.referenceDistance,
        maxDistance: source.maxDistance,
      );
      final volume =
          source.volume *
          attenuation *
          channels.getEffectiveVolume(source.channel);
      backend
        ..setVolume(voice, volume)
        ..setPan(voice, pan);
    }
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
