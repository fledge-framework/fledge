// Imported for the [Scheduler] doc references.
import 'schedule.dart';
import 'schedule_label.dart';

/// Standard phases of [Schedules.first], configured in this order by every
/// [Scheduler] created with the default constructor:
///
/// 1. [frameStart] — frame bookkeeping.
/// 2. [platform] — platform / backend integration.
/// 3. [input] — input polling and action resolution.
/// 4. [content] — content that reacts to the frame's inputs and assets.
///
/// Each phase is configured `before` the next one, so every system in an
/// earlier phase runs before every system in a later phase, regardless of
/// plugin registration order. Systems *within* a phase are still ordered
/// by their own `before:` / `after:` edges (and parallelised when they do
/// not conflict).
///
/// A game system joins a phase by declaring membership in its meta:
///
/// ```dart
/// FunctionSystem(
///   'gamepadRumble',
///   sets: [FirstSets.input],
///   resourceWrites: {Rumble},
///   run: (world) { /* ... */ },
/// );
/// // or, for a class-based system:
/// SystemMeta(name: 'myPoll', sets: [FirstSets.input]);
/// ```
///
/// or by ordering itself relative to a whole phase without joining it:
///
/// ```dart
/// SystemMeta(name: 'afterInput', after: [FirstSets.input]);
/// ```
///
/// Set names work anywhere a system name does in `before:` / `after:`.
/// Systems in [Schedules.first] that join no phase are unordered relative
/// to the phases, so `App.checkScheduleOrdering()` still reports them when
/// they conflict with a phased system.
///
/// [Scheduler.empty] does not configure these phases.
abstract final class FirstSets {
  /// Frame bookkeeping that everything else in the frame may read: wall
  /// time (`WallTimeUpdateSystem`), the frame limiter's frame-start
  /// timestamp, the in-game calendar, and debug frame/system statistics.
  static const String frameStart = 'first.frameStart';

  /// Platform and backend integration: window initialisation and window
  /// event/display sync, audio engine initialisation and focus handling.
  /// Runs after [frameStart] so it can read the frame's wall time.
  static const String platform = 'first.platform';

  /// Input polling and action resolution (`fledge_input`). Runs after
  /// [platform] so window focus/size changes from this frame are visible.
  static const String input = 'first.input';

  /// Content loading and spawning: asset hot-reload polling, tilemap and
  /// object-layer entity spawning. Runs last so spawned content sees the
  /// frame's resolved input and platform state.
  static const String content = 'first.content';

  /// Every phase, in execution order.
  static const List<String> chain = [frameStart, platform, input, content];
}
