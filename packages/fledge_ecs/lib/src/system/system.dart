import 'dart:async';

import '../component.dart';
import '../world.dart';
import 'run_condition.dart';

/// Describes the data access patterns of a system.
///
/// [SystemMeta] is used by the scheduler to order systems. Systems run one
/// at a time (Dart has one isolate); two systems that conflict (read-write
/// or write-write overlap) without an explicit [before]/[after] fall back to
/// registration order, which `App.checkScheduleOrdering()` reports.
///
/// Explicit ordering constraints can be specified using [before] and [after]:
///
/// ```dart
/// // This system runs after 'input' and before 'collision'
/// FunctionSystem(
///   'movement',
///   after: ['input'],
///   before: ['collision'],
///   run: (world) { /* ... */ },
/// );
/// ```
class SystemMeta {
  /// The system's display name for debugging.
  final String name;

  /// Component types this system reads (immutable access).
  final Set<ComponentId> reads;

  /// Component types this system writes (mutable access).
  final Set<ComponentId> writes;

  /// Resource types this system reads.
  final Set<Type> resourceReads;

  /// Resource types this system writes.
  final Set<Type> resourceWrites;

  /// Event types this system reads.
  final Set<Type> eventReads;

  /// Event types this system writes.
  final Set<Type> eventWrites;

  /// Whether this system is exclusive (requires sole world access).
  ///
  /// An exclusive system conflicts with every other system, so it is
  /// ordered against all of them.
  final bool exclusive;

  /// Names of systems (or system sets) that this system must run before.
  ///
  /// This is an explicit ordering constraint. The listed systems will
  /// wait for this system to complete before starting.
  final List<String> before;

  /// Names of systems (or system sets) that this system must run after.
  ///
  /// This is an explicit ordering constraint. This system will wait
  /// for the listed systems to complete before starting.
  final List<String> after;

  /// Names of the system sets this system belongs to.
  ///
  /// The scheduler resolves a `before:` / `after:` reference (on a system
  /// or on a set configured via `Scheduler.configureSet`) to every system
  /// whose [name] matches *or* whose [sets] contains the referenced name.
  final List<String> sets;

  const SystemMeta({
    required this.name,
    this.reads = const {},
    this.writes = const {},
    this.resourceReads = const {},
    this.resourceWrites = const {},
    this.eventReads = const {},
    this.eventWrites = const {},
    this.exclusive = false,
    this.before = const [],
    this.after = const [],
    this.sets = const [],
  });

  /// Returns true if this system conflicts with [other].
  ///
  /// Two systems conflict if:
  /// - Either is exclusive
  /// - They both write to the same component
  /// - One writes a component the other reads
  /// - They both write to the same resource
  /// - One writes a resource the other reads
  /// - They both write to the same event type
  /// - One writes an event the other reads
  bool conflictsWith(SystemMeta other) {
    if (exclusive || other.exclusive) return true;

    // Check component conflicts
    for (final write in writes) {
      if (other.writes.contains(write) || other.reads.contains(write)) {
        return true;
      }
    }
    for (final write in other.writes) {
      if (reads.contains(write)) {
        return true;
      }
    }

    // Check resource conflicts
    for (final write in resourceWrites) {
      if (other.resourceWrites.contains(write) ||
          other.resourceReads.contains(write)) {
        return true;
      }
    }
    for (final write in other.resourceWrites) {
      if (resourceReads.contains(write)) {
        return true;
      }
    }

    // Check event conflicts
    for (final write in eventWrites) {
      if (other.eventWrites.contains(write) ||
          other.eventReads.contains(write)) {
        return true;
      }
    }
    for (final write in other.eventWrites) {
      if (eventReads.contains(write)) {
        return true;
      }
    }

    return false;
  }

  @override
  String toString() => 'SystemMeta($name)';
}

/// Base interface for all systems.
///
/// Systems contain the logic that operates on entities and their components.
/// Each system declares its data dependencies via [meta], which the
/// scheduler uses to order it against conflicting systems.
abstract class System {
  /// Metadata describing this system's data access patterns.
  SystemMeta get meta;

  /// Optional condition that determines whether this system should run.
  ///
  /// If null, the system always runs. If non-null, the condition is evaluated
  /// before each run and the system is skipped if it returns false.
  ///
  /// ```dart
  /// final system = FunctionSystem(
  ///   'playerInput',
  ///   runIf: (world) => world.getResource<GameState>()?.isPlaying ?? false,
  ///   run: (world) { /* ... */ },
  /// );
  /// ```
  RunCondition? get runCondition => null;

  /// Runs the system logic.
  ///
  /// A synchronous system declares `void run(World world)` and just
  /// returns: the scheduler runs the next system at once (and code that
  /// runs one directly, a test say, calls it without `await`). One that must wait returns
  /// a [Future], and the scheduler awaits it before the next system starts.
  /// Prefer synchronous systems: an `async` method always returns a Future
  /// that completes later, which costs a turn of the event loop even when
  /// nothing is awaited, and systems inside a tick must never await
  /// platform calls (start them in the background and apply the result on
  /// a later frame).
  FutureOr<void> run(World world);

  /// Returns true if this system should run, based on its [runCondition].
  bool shouldRun(World world) => runCondition?.call(world) ?? true;
}

/// A synchronous system that doesn't need async operations.
///
/// Extend this class for simple systems that don't perform I/O.
abstract class SyncSystem extends System {
  @override
  void run(World world) => runSync(world);

  /// Runs the system logic synchronously.
  void runSync(World world);
}

/// A system created from a function.
///
/// This is the most common way to create systems. The function receives
/// the world and can perform any operations.
///
/// ```dart
/// final movementSystem = FunctionSystem(
///   'movement',
///   writes: {ComponentId.of<Position>()},
///   reads: {ComponentId.of<Velocity>()},
///   run: (world) {
///     for (final (entity, pos, vel) in world.query2<Position, Velocity>().iter()) {
///       pos.x += vel.dx;
///       pos.y += vel.dy;
///     }
///   },
/// );
///
/// // With a run condition
/// final conditionalSystem = FunctionSystem(
///   'playerInput',
///   runIf: (world) => world.getResource<GameState>()?.isPlaying ?? false,
///   run: (world) { /* ... */ },
/// );
/// ```
class FunctionSystem implements System {
  @override
  final SystemMeta meta;

  @override
  final RunCondition? runCondition;

  final void Function(World world) _run;

  @override
  bool shouldRun(World world) => runCondition?.call(world) ?? true;

  FunctionSystem(
    String name, {
    Set<ComponentId> reads = const {},
    Set<ComponentId> writes = const {},
    Set<Type> resourceReads = const {},
    Set<Type> resourceWrites = const {},
    Set<Type> eventReads = const {},
    Set<Type> eventWrites = const {},
    bool exclusive = false,
    List<String> before = const [],
    List<String> after = const [],
    List<String> sets = const [],
    RunCondition? runIf,
    required void Function(World world) run,
  }) : meta = SystemMeta(
         name: name,
         reads: reads,
         writes: writes,
         resourceReads: resourceReads,
         resourceWrites: resourceWrites,
         eventReads: eventReads,
         eventWrites: eventWrites,
         exclusive: exclusive,
         before: before,
         after: after,
         sets: sets,
       ),
       runCondition = runIf,
       _run = run;

  @override
  void run(World world) => _run(world);
}

/// An async system created from a function.
///
/// ```dart
/// final asyncSystem = AsyncFunctionSystem(
///   'networkSync',
///   runIf: (world) => world.hasResource<NetworkConnection>(),
///   run: (world) async {
///     await syncWithServer(world);
///   },
/// );
/// ```
class AsyncFunctionSystem implements System {
  @override
  final SystemMeta meta;

  @override
  final RunCondition? runCondition;

  final Future<void> Function(World world) _run;

  @override
  bool shouldRun(World world) => runCondition?.call(world) ?? true;

  AsyncFunctionSystem(
    String name, {
    Set<ComponentId> reads = const {},
    Set<ComponentId> writes = const {},
    Set<Type> resourceReads = const {},
    Set<Type> resourceWrites = const {},
    Set<Type> eventReads = const {},
    Set<Type> eventWrites = const {},
    bool exclusive = false,
    List<String> before = const [],
    List<String> after = const [],
    List<String> sets = const [],
    RunCondition? runIf,
    required Future<void> Function(World world) run,
  }) : meta = SystemMeta(
         name: name,
         reads: reads,
         writes: writes,
         resourceReads: resourceReads,
         resourceWrites: resourceWrites,
         eventReads: eventReads,
         eventWrites: eventWrites,
         exclusive: exclusive,
         before: before,
         after: after,
         sets: sets,
       ),
       runCondition = runIf,
       _run = run;

  @override
  Future<void> run(World world) => _run(world);
}
