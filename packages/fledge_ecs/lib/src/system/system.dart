import 'dart:async';

import '../component.dart';
import '../world.dart';
import 'run_condition.dart';

/// Describes the data access patterns of a system.
///
/// [SystemMeta] is used by the scheduler to determine which systems
/// can run in parallel. Systems that don't conflict (no read-write or
/// write-write overlaps) can execute concurrently.
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
  /// Exclusive systems cannot run in parallel with any other system.
  final bool exclusive;

  /// Names of systems that this system must run before.
  ///
  /// This is an explicit ordering constraint. The listed systems will
  /// wait for this system to complete before starting.
  final List<String> before;

  /// Names of systems that this system must run after.
  ///
  /// This is an explicit ordering constraint. This system will wait
  /// for the listed systems to complete before starting.
  final List<String> after;

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
/// Each system declares its data dependencies via [meta], allowing the
/// scheduler to run non-conflicting systems in parallel.
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
  /// Returns a [Future] to support async operations. For synchronous
  /// systems, return `Future.value()` or use [SyncSystem].
  Future<void> run(World world);

  /// Returns true if this system should run, based on its [runCondition].
  bool shouldRun(World world) => runCondition?.call(world) ?? true;
}

/// A synchronous system that doesn't need async operations.
///
/// Extend this class for simple systems that don't perform I/O.
abstract class SyncSystem implements System {
  @override
  Future<void> run(World world) {
    runSync(world);
    return Future.value();
  }

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
    RunCondition? runIf,
    required void Function(World world) run,
  })  : meta = SystemMeta(
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
        ),
        runCondition = runIf,
        _run = run;

  @override
  Future<void> run(World world) {
    _run(world);
    return Future.value();
  }
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
    RunCondition? runIf,
    required Future<void> Function(World world) run,
  })  : meta = SystemMeta(
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
        ),
        runCondition = runIf,
        _run = run;

  @override
  Future<void> run(World world) => _run(world);
}
