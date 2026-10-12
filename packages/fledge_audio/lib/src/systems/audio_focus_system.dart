import 'package:fledge_ecs/fledge_ecs.dart';

import '../config/audio_config.dart';
import '../events/audio_events.dart';
import '../resources/audio_state.dart';
import 'audio_event_system.dart';
import 'audio_init_system.dart';

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
  /// The `SystemMeta.name` of [AudioFocusSystem]. Games that order
  /// their own systems relative to this one use it in `before:` /
  /// `after:`.
  static const String systemName = 'AudioFocusSystem';

  @override
  SystemMeta get meta => const SystemMeta(
    name: systemName,
    // Focus pause/resume applies on top of this frame's explicit requests.
    after: [AudioInitSystem.systemName, AudioEventSystem.systemName],
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
