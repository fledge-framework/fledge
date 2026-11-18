import 'package:fledge_ecs/fledge_ecs.dart';

import '../components/audio_source.dart';
import '../events/audio_events.dart';
import '../resources/audio_state.dart';

/// Forgets voices that have ended, and says so.
///
/// Runs in `Schedules.last`. Sends [SfxFinished] for every sound effect or
/// source sound that ended, and [MusicFinished] when a track that doesn't
/// loop reaches its end.
class AudioCleanupSystem implements System {
  /// The `SystemMeta.name` of [AudioCleanupSystem].
  static const String systemName = 'AudioCleanupSystem';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    resourceWrites: {AudioState},
    writes: {ComponentId.of<AudioSource>()},
    eventWrites: {SfxFinished, MusicFinished},
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  void run(World world) {
    final state = world.getResource<AudioState>();
    if (state == null || !state.isInitialized) return;
    final backend = state.backend;

    final ended = [
      for (final MapEntry(key: voice, value: key) in state.sounds.entries)
        if (!backend.isPlaying(voice)) (voice, key),
    ];
    for (final (voice, key) in ended) {
      state.sounds.remove(voice);
      world.eventWriter<SfxFinished>().send(SfxFinished(key));
    }

    state.fadingOut.removeWhere((voice) => !backend.isPlaying(voice));

    final music = state.currentMusicVoice;
    if (music != null && !backend.isPlaying(music)) {
      final key = state.currentMusicKey!;
      state
        ..currentMusicVoice = null
        ..currentMusicKey = null
        ..musicFadeRemaining = 0;
      world.eventWriter<MusicFinished>().send(MusicFinished(key));
    }

    for (final (_, source) in world.query1<AudioSource>().iter()) {
      final voice = source.voice;
      if (voice != null && !backend.isPlaying(voice)) source.voice = null;
    }
  }
}
