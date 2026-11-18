import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:flutter/widgets.dart';

import '../config/audio_config.dart';
import '../events/audio_events.dart';
import '../resources/audio_state.dart';
import 'audio_event_system.dart';
import 'audio_init_system.dart';

/// Whether the app's window has focus, as far as audio is concerned.
///
/// [AudioFocusSystem] keeps it up to date from Flutter's app lifecycle
/// (inactive or hidden = no focus). Set [hasFocus] yourself to drive it
/// from elsewhere (tests, a custom window layer).
class AudioFocus {
  bool hasFocus = true;
}

/// Pauses all audio while the window doesn't have focus, and resumes it
/// when focus comes back (when [AudioConfig.pauseOnFocusLoss] is set).
///
/// Runs in the [FirstSets.platform] phase of `Schedules.first`, after this
/// frame's requests. A pause the game asked for itself is left alone:
/// focus only undoes the pauses focus caused.
class AudioFocusSystem implements System {
  /// The `SystemMeta.name` of [AudioFocusSystem].
  static const String systemName = 'AudioFocusSystem';

  AppLifecycleListener? _listener;

  @override
  SystemMeta get meta => const SystemMeta(
    name: systemName,
    sets: [FirstSets.platform],
    after: [AudioInitSystem.systemName, AudioEventSystem.systemName],
    eventWrites: {AudioPaused, AudioResumed},
    resourceReads: {AudioConfig},
    resourceWrites: {AudioState, AudioFocus},
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  void run(World world) {
    final focus = world.getResource<AudioFocus>();
    final state = world.getResource<AudioState>();
    final config = world.getResource<AudioConfig>();
    if (focus == null || state == null || config == null) return;
    _listen(focus);
    if (!config.pauseOnFocusLoss) return;

    if (!focus.hasFocus && !state.isPaused) {
      state.pauseAll();
      state.pausedByFocusLoss = true;
      world.eventWriter<AudioPaused>().send(
        const AudioPaused(byFocusLoss: true),
      );
    } else if (focus.hasFocus && state.isPaused && state.pausedByFocusLoss) {
      state.resumeAll();
      world.eventWriter<AudioResumed>().send(const AudioResumed());
    }
  }

  /// Follows the app lifecycle, once a Flutter binding exists (there is
  /// none in plain Dart tests).
  void _listen(AudioFocus focus) {
    if (_listener != null) return;
    try {
      WidgetsBinding.instance;
    } catch (_) {
      return;
    }
    _listener = AppLifecycleListener(
      onStateChange: (lifecycle) =>
          focus.hasFocus = lifecycle == AppLifecycleState.resumed,
    );
  }

  /// Stops following the app lifecycle (`AudioPlugin.cleanup`).
  void dispose() {
    _listener?.dispose();
    _listener = null;
  }
}
