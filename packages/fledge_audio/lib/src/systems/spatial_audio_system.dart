import 'dart:math';

import 'package:fledge_ecs/fledge_ecs.dart';

import '../components/audio_listener.dart';
import '../components/audio_source.dart';
import '../config/audio_config.dart';
import '../resources/audio_channels.dart';
import '../resources/audio_state.dart';
import '../assets/audio_assets.dart';

/// System that updates spatial audio based on entity positions.
///
/// Reads AudioListener and AudioSource components along with
/// position data to calculate panning and volume falloff.
///
/// Note: This system expects entities to have a position accessible
/// via a 'position' field or similar. Adjust based on your transform system.
class SpatialAudioSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'SpatialAudioSystem',
        reads: {
          ComponentId.of<AudioListener>(),
          ComponentId.of<AudioSource>(),
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

    // Find the active listener position
    // Note: In a full integration, this would read from Transform2D or similar
    (double x, double y)? listenerPos;

    for (final (_, listener) in world.query1<AudioListener>().iter()) {
      if (listener.isActive) {
        // TODO: Get position from entity's transform component
        // For now, default to origin - users should extend this
        listenerPos = (0.0, 0.0);
        break;
      }
    }

    if (listenerPos == null) return;

    // Update all audio sources
    for (final (_, source) in world.query1<AudioSource>().iter()) {
      // Handle autoPlay for sources that haven't started
      if (source.autoPlay && !source.hasStarted && source.soundKey != null) {
        final sound = assets.getSound(source.soundKey!);
        if (sound != null) {
          final handle = await soloud.play(
            sound.source,
            volume: 0.0, // Will be updated below
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

      // TODO: Get position from entity's transform component
      // For now, use (0, 0) - users should extend this
      const sourcePos = (0.0, 0.0);

      final dx = sourcePos.$1 - listenerPos.$1;
      final dy = sourcePos.$2 - listenerPos.$2;
      final distance = sqrt(dx * dx + dy * dy);

      // Calculate volume falloff
      final maxDist = source.maxDistance ?? config.maxDistance;
      final refDist = source.referenceDistance ?? config.referenceDistance;
      final attenuation = _calculateAttenuation(
        distance,
        refDist,
        maxDist,
        config.rolloffFactor,
      );

      final channelVolume = channels.getEffectiveVolume(source.channel);
      final finalVolume = source.volume * attenuation * channelVolume;

      // Calculate panning (2D: left/right based on x)
      final pan = (dx / maxDist).clamp(-config.maxPan, config.maxPan);

      soloud.setVolume(source.handle!, finalVolume);
      soloud.setPan(source.handle!, pan);
    }
  }

  double _calculateAttenuation(
    double distance,
    double refDistance,
    double maxDistance,
    double rolloff,
  ) {
    if (distance <= refDistance) return 1.0;
    if (distance >= maxDistance) return 0.0;

    // Linear falloff
    final range = maxDistance - refDistance;
    final distFromRef = distance - refDistance;
    return 1.0 - (distFromRef / range) * rolloff;
  }
}
