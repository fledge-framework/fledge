import 'package:fledge_ecs/fledge_ecs.dart';

import '../config/audio_config.dart';
import '../events/audio_events.dart';
import '../resources/audio_state.dart';

/// System that pauses audio when the window loses focus.
///
/// This system listens for focus change events and automatically
/// pauses/resumes audio. Requires handling of focus events in your app.
///
/// You can send focus events manually or integrate with fledge_window:
/// ```dart
/// // Manual focus handling
/// world.eventWriter<WindowFocusChanged>().send(WindowFocusChanged(false));
/// ```
class AudioFocusSystem implements System {
  @override
  SystemMeta get meta => const SystemMeta(
        name: 'AudioFocusSystem',
        eventWrites: {AudioPaused, AudioResumed},
        resourceReads: {AudioConfig},
        resourceWrites: {AudioState},
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) async {
    // This system is a placeholder for focus integration.
    // When integrated with fledge_window, it would read WindowFocusChanged events.
    //
    // For now, users can manually pause/resume via:
    //   world.pauseAudio();
    //   world.resumeAudio();
    //
    // Or by sending events:
    //   world.eventWriter<PauseAudioRequest>().send(PauseAudioRequest());
  }
}
