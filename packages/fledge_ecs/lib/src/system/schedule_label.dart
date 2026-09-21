import 'package:meta/meta.dart';

/// A label identifying a named schedule (a DAG of systems).
///
/// Systems are added to a `Schedule` via
/// `App.addSystem(system, schedule: Schedules.update)`.
///
/// Schedules run in a defined order per `App.tick`:
///
/// - [Schedules.startup] runs once, on the first tick.
/// - Per-frame chain: [Schedules.first] → [Schedules.preUpdate] →
///   fixed-timestep dispatch ([Schedules.fixedFirst] →
///   [Schedules.fixedPreUpdate] → [Schedules.fixedUpdate] →
///   [Schedules.fixedPostUpdate] → [Schedules.fixedLast], run 0..N
///   times per frame) → [Schedules.update] → [Schedules.postUpdate] →
///   [Schedules.last] → [Schedules.extract] → [Schedules.render].
///
/// Constants for the standard schedules are in [Schedules]. Games can
/// create custom schedules with `const Schedule('my_schedule')`, but they
/// must be registered on the [Scheduler] to actually run.
@immutable
class Schedule {
  /// A stable identifier for the schedule.
  final String name;

  /// Creates a schedule label with the given [name].
  const Schedule(this.name);

  @override
  bool operator ==(Object other) => other is Schedule && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'Schedule($name)';
}

/// Standard schedule labels.
///
/// The names on the per-frame schedules match the names of the
/// corresponding `CoreStage` values (e.g. `Schedules.update.name == 'update'`)
/// for backwards compatibility with the pre-Schedule stage API.
class Schedules {
  Schedules._();

  /// Startup — runs once before the frame loop begins.
  static const startup = Schedule('startup');

  /// First per-frame schedule. Runs before all others in a frame.
  static const first = Schedule('first');

  /// Runs before [update]. Use for input processing and preparation.
  ///
  /// The name string (`'preUpdate'`) intentionally matches
  /// `CoreStage.preUpdate.name` so the legacy stage-based API and the
  /// new schedule-based API resolve to the same underlying stage.
  static const preUpdate = Schedule('preUpdate');

  /// The main per-frame schedule. Most game logic runs here.
  static const update = Schedule('update');

  /// Runs after [update]. Use for reactions to update changes.
  ///
  /// Name matches `CoreStage.postUpdate.name` for back-compat — see
  /// [preUpdate].
  static const postUpdate = Schedule('postUpdate');

  /// Runs after all other per-frame schedules. Use for cleanup.
  static const last = Schedule('last');

  /// Fixed-timestep: runs before all other fixed schedules.
  ///
  /// The fixed chain is dispatched 0..N times per frame by `App.tick`
  /// (via the [FixedTimestep] accumulator, default 60 Hz, 5-step
  /// catchup cap) between [preUpdate] and [update].
  static const fixedFirst = Schedule('fixedFirst');

  /// Fixed-timestep: runs before [fixedUpdate]. See [fixedFirst].
  static const fixedPreUpdate = Schedule('fixedPreUpdate');

  /// Fixed-timestep: main fixed update schedule. See [fixedFirst].
  static const fixedUpdate = Schedule('fixedUpdate');

  /// Fixed-timestep: runs after [fixedUpdate]. See [fixedFirst].
  static const fixedPostUpdate = Schedule('fixedPostUpdate');

  /// Fixed-timestep: runs last in the fixed schedule chain. See
  /// [fixedFirst].
  static const fixedLast = Schedule('fixedLast');

  /// Render pipeline: extract state from the main world into the render
  /// world.
  ///
  /// Dispatched by `App.tick` after [last] and before [render].
  static const extract = Schedule('extract');

  /// Render pipeline: run render systems against the render world.
  ///
  /// Dispatched by `App.tick` after [extract].
  static const render = Schedule('render');

  /// All standard schedule labels, in the order the [Scheduler]
  /// registers them by default.
  static const List<Schedule> all = <Schedule>[
    startup,
    first,
    preUpdate,
    update,
    postUpdate,
    last,
    fixedFirst,
    fixedPreUpdate,
    fixedUpdate,
    fixedPostUpdate,
    fixedLast,
    extract,
    render,
  ];
}
