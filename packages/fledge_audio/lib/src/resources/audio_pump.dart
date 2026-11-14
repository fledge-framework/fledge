import 'package:fledge_ecs/fledge_ecs.dart';

import '../events/audio_events.dart';

/// The audio systems, for running audio while the world isn't ticking
/// (`world.pumpAudio`). Inserted by `AudioPlugin`; the same system
/// instances it registers in the schedules.
class AudioPump {
  AudioPump(this.systems);

  /// In the order a tick runs them.
  final List<System> systems;

  /// Swaps only the audio event queues, so gameplay events still waiting
  /// for the next tick are left alone.
  void swapAudioEvents(World world) {
    void swap<T>() => world.events.tryQueue<T>()?.update();
    swap<PlaySfxRequest>();
    swap<PlayMusicRequest>();
    swap<StopMusicRequest>();
    swap<PauseAudioRequest>();
    swap<ResumeAudioRequest>();
    swap<SetChannelVolumeRequest>();
    swap<SfxStarted>();
    swap<SfxFinished>();
    swap<MusicStarted>();
    swap<MusicFinished>();
    swap<MusicChanged>();
    swap<AudioFailed>();
    swap<AudioPaused>();
    swap<AudioResumed>();
    swap<AudioAssetLoaded>();
  }
}
