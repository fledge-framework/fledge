import 'dart:math';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';

import '../components/audio_listener.dart';
import '../components/audio_source.dart';
import '../config/audio_config.dart';
import '../resources/audio_channels.dart';
import '../resources/audio_state.dart';
import '../assets/audio_assets.dart';

/// System that updates spatial audio based on entity positions.
///
/// Reads `AudioListener` + `Transform2D` to find the active listener, and
/// `AudioSource` + `Transform2D` for every audio emitter. Distance →
/// attenuated volume; lateral offset → stereo pan.
///
/// Entities without a `Transform2D` are treated as positioned at the
/// listener (no falloff, centred pan), which matches the non-spatial path.
class SpatialAudioSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'SpatialAudioSystem',
        reads: {
          ComponentId.of<AudioListener>(),
          ComponentId.of<AudioSource>(),
          ComponentId.of<Transform2D>(),
        },
        writes: {ComponentId.of<AudioSource>()},
        resourceReads: {SpatialAudioConfig, VolumeChannels, AudioAssets},
        resourceWrites: {AudioState},
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
    final assets = world.getResource<AudioAssets>()!;
    final soloud = state.soloud;

    // Find the first active listener that has a Transform2D. Listeners
    // without a transform are ignored — spatial audio needs a position.
    (double, double)? listenerPos;
    for (final (_, listener, transform)
        in world.query2<AudioListener, Transform2D>().iter()) {
      if (!listener.isActive) continue;
      listenerPos = (transform.translation.x, transform.translation.y);
      break;
    }
    if (listenerPos == null) return;

    for (final (_, source, transform)
        in world.query2<AudioSource, Transform2D>().iter()) {
      // Auto-play sources that haven't started yet.
      if (source.autoPlay && !source.hasStarted && source.soundKey != null) {
        final sound = assets.getSound(source.soundKey!);
        if (sound != null) {
          final handle = await soloud.play(
            sound.source,
            volume: 0.0, // updated below
            looping: source.looping,
          );
          source.handle = handle;
          source.hasStarted = true;
          state.registerSound(handle);
        }
      }

      if (source.handle == null) continue;
      if (!soloud.getIsValidVoiceHandle(source.handle!)) {
        source.handle = null;
        continue;
      }

      final sourcePos = (transform.translation.x, transform.translation.y);
      final dx = sourcePos.$1 - listenerPos.$1;
      final dy = sourcePos.$2 - listenerPos.$2;
      final distance = sqrt(dx * dx + dy * dy);

      final maxDist = source.maxDistance ?? config.maxDistance;
      final refDist = source.referenceDistance ?? config.referenceDistance;
      final attenuation = calculateAttenuation(
        distance,
        refDist,
        maxDist,
        config.rolloffFactor,
      );

      final channelVolume = channels.getEffectiveVolume(source.channel);
      final finalVolume = source.volume * attenuation * channelVolume;

      // Pan: lateral offset normalized to [-maxPan, maxPan].
      final pan = (dx / maxDist).clamp(-config.maxPan, config.maxPan);

      soloud.setVolume(source.handle!, finalVolume);
      soloud.setPan(source.handle!, pan);
    }
  }

  /// Linear falloff from [refDistance] (full volume) to [maxDistance] (silent).
  ///
  /// Exposed for tests.
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
