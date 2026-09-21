import 'dart:async';

import 'package:fledge_ecs_annotations/fledge_ecs_annotations.dart';

import '../fixed_timestep.dart';
import '../world.dart';
import 'schedule_label.dart';
import 'system.dart';

/// A node in the system dependency graph.
class SystemNode {
  /// The system to run.
  final System system;

  /// Systems that must complete before this one can start.
  final Set<int> dependencies;

  /// Whether this system has completed in the current run.
  bool completed = false;

  SystemNode(this.system, [Set<int>? deps]) : dependencies = deps ?? <int>{};
}

/// A stage containing systems that run together.
///
/// Within a stage, systems may run in parallel if they don't conflict.
class SystemStage {
  final String name;
  final List<SystemNode> _systems = [];

  /// Maps system names to every registered system's index under that
  /// name. `before:` / `after:` lookups fan out to every match so a
  /// schedule can carry two (or more) systems that share a name — for
  /// example a second `transform_propagate` inserted after a movement
  /// pass — without any of them dropping their explicit ordering.
  final Map<String, List<int>> _nameToIndex = {};

  /// Maps system names to indices of systems that must run before them.
  /// This handles `before` constraints for systems not yet added.
  final Map<String, Set<int>> _pendingBefore = {};

  /// Maps system names to indices of systems that must run after them.
  /// This handles `after` constraints for systems not yet added.
  final Map<String, Set<int>> _pendingAfter = {};

  SystemStage(this.name);

  /// Adds a system to this stage.
  void addSystem(System system) {
    final node = SystemNode(system);
    final newIndex = _systems.length;
    final systemName = system.meta.name;

    // Build dependencies based on conflicts.
    //
    // Skip the conflict-driven edge when either system names the other in
    // `before:`/`after:` — the explicit declaration wins over
    // registration order. Without this, declaring `before: A` on a system
    // that gets registered after A produces a cycle: the conflict rule
    // adds `new depends on A` while the explicit `before` adds
    // `A depends on new`.
    for (int i = 0; i < _systems.length; i++) {
      final otherMeta = _systems[i].system.meta;
      if (!system.meta.conflictsWith(otherMeta)) continue;
      if (system.meta.before.contains(otherMeta.name) ||
          system.meta.after.contains(otherMeta.name) ||
          otherMeta.before.contains(systemName) ||
          otherMeta.after.contains(systemName)) {
        continue;
      }
      node.dependencies.add(i);
    }

    // Handle explicit `after` constraints. Every already-registered
    // system with a matching name is added as a dependency so a
    // schedule holding duplicates keeps all of them upstream.
    for (final afterName in system.meta.after) {
      final indices = _nameToIndex[afterName];
      if (indices != null && indices.isNotEmpty) {
        node.dependencies.addAll(indices);
      }
      // Also record the pending edge — a future system registered
      // under the same name will pick this up (see the pendingAfter
      // handler below).
      if (indices == null || indices.isEmpty) {
        _pendingAfter.putIfAbsent(afterName, () => {}).add(newIndex);
      }
    }

    // Handle pending `before` constraints (from systems added earlier)
    final pendingBefore = _pendingBefore[systemName];
    if (pendingBefore != null) {
      node.dependencies.addAll(pendingBefore);
      _pendingBefore.remove(systemName);
    }

    // Handle pending `after` constraints (from systems added earlier that want to run after this)
    final pendingAfter = _pendingAfter[systemName];
    if (pendingAfter != null) {
      for (final waitingIndex in pendingAfter) {
        _systems[waitingIndex].dependencies.add(newIndex);
      }
      _pendingAfter.remove(systemName);
    }

    // Handle explicit `before` constraints. Fan out to every already-
    // registered system sharing the name.
    for (final beforeName in system.meta.before) {
      final indices = _nameToIndex[beforeName];
      if (indices != null && indices.isNotEmpty) {
        for (final idx in indices) {
          _systems[idx].dependencies.add(newIndex);
        }
      }
      if (indices == null || indices.isEmpty) {
        // System doesn't exist yet, record for later
        _pendingBefore.putIfAbsent(beforeName, () => {}).add(newIndex);
      }
    }

    // Register this system's name — append to the list of indices
    // under the name so duplicates coexist.
    _nameToIndex.putIfAbsent(systemName, () => <int>[]).add(newIndex);

    _systems.add(node);

    // Fail fast if the declared ordering forms a cycle. Without this the
    // scheduler would only report a generic "Deadlock detected" at runtime.
    _assertAcyclic();
  }

  /// Walk the dependency graph looking for a cycle. Throws with a path
  /// that names every system involved.
  void _assertAcyclic() {
    const unvisited = 0;
    const onStack = 1;
    const done = 2;
    final state = List<int>.filled(_systems.length, unvisited);
    final path = <int>[];

    List<int>? visit(int index) {
      state[index] = onStack;
      path.add(index);
      for (final dep in _systems[index].dependencies) {
        if (state[dep] == onStack) {
          final start = path.indexOf(dep);
          return path.sublist(start);
        }
        if (state[dep] == unvisited) {
          final found = visit(dep);
          if (found != null) return found;
        }
      }
      state[index] = done;
      path.removeLast();
      return null;
    }

    for (var i = 0; i < _systems.length; i++) {
      if (state[i] != unvisited) continue;
      final cycle = visit(i);
      if (cycle != null) {
        final names = cycle
            .map((idx) => _systems[idx].system.meta.name)
            .toList();
        throw StateError(
          'Cycle detected in stage "$name" among systems: '
          '${names.join(" -> ")} -> ${names.first}. '
          'Check the before:/after: declarations on these systems.',
        );
      }
    }
  }

  /// Runs all systems in this stage, parallelizing where possible.
  Future<void> run(World world) async {
    if (_systems.isEmpty) return;

    // Reset completion state
    for (final node in _systems) {
      node.completed = false;
    }

    // Track running futures
    final running = <int, Future<void>>{};
    final completed = <int>{};

    while (completed.length < _systems.length) {
      // Find systems ready to run (all dependencies completed)
      final ready = <int>[];
      for (int i = 0; i < _systems.length; i++) {
        if (completed.contains(i)) continue;
        if (running.containsKey(i)) continue;

        final node = _systems[i];
        if (node.dependencies.every((dep) => completed.contains(dep))) {
          ready.add(i);
        }
      }

      if (ready.isEmpty && running.isEmpty) {
        // Shouldn't happen unless there's a cycle
        throw StateError('Deadlock detected in stage $name');
      }

      // Start ready systems
      for (final index in ready) {
        final system = _systems[index].system;

        // Check run condition before running
        if (!system.shouldRun(world)) {
          // Skip this system, mark as completed
          completed.add(index);
          continue;
        }

        running[index] = system.run(world).then((_) {
          completed.add(index);
          running.remove(index);
        });
      }

      // Wait for at least one to complete
      if (running.isNotEmpty) {
        await Future.any(running.values);
      }
    }
  }

  /// The number of systems in this stage.
  int get length => _systems.length;

  /// Returns true if this stage has no systems.
  bool get isEmpty => _systems.isEmpty;

  /// Clears all systems from this stage.
  void clear() {
    _systems.clear();
    _nameToIndex.clear();
    _pendingBefore.clear();
    _pendingAfter.clear();
  }

  /// Scan pairs in this stage for ordering determined only by registration
  /// order. Called by [Scheduler.checkOrderingAmbiguities].
  List<OrderingAmbiguity> _findOrderingAmbiguities() {
    final out = <OrderingAmbiguity>[];
    for (var i = 0; i < _systems.length; i++) {
      final a = _systems[i].system.meta;
      for (var j = i + 1; j < _systems.length; j++) {
        final b = _systems[j].system.meta;
        if (!a.conflictsWith(b)) continue;
        if (a.before.contains(b.name) ||
            a.after.contains(b.name) ||
            b.before.contains(a.name) ||
            b.after.contains(a.name)) {
          continue;
        }
        out.add(
          OrderingAmbiguity(
            stage: name,
            systemA: a.name,
            systemB: b.name,
            reasons: _describeMetaConflict(a, b),
          ),
        );
      }
    }
    return out;
  }
}

/// Describe what makes two metas conflict, in user-facing language.
List<String> _describeMetaConflict(SystemMeta a, SystemMeta b) {
  final reasons = <String>[];

  if (a.exclusive || b.exclusive) {
    reasons.add('one side is exclusive');
    return reasons;
  }

  for (final w in a.writes) {
    if (b.writes.contains(w)) {
      reasons.add('both write component $w');
    } else if (b.reads.contains(w)) {
      reasons.add('$w: ${a.name} writes, ${b.name} reads');
    }
  }
  for (final w in b.writes) {
    if (a.reads.contains(w)) {
      reasons.add('$w: ${b.name} writes, ${a.name} reads');
    }
  }

  for (final w in a.resourceWrites) {
    if (b.resourceWrites.contains(w)) {
      reasons.add('both write resource $w');
    } else if (b.resourceReads.contains(w)) {
      reasons.add('resource $w: ${a.name} writes, ${b.name} reads');
    }
  }
  for (final w in b.resourceWrites) {
    if (a.resourceReads.contains(w)) {
      reasons.add('resource $w: ${b.name} writes, ${a.name} reads');
    }
  }

  for (final e in a.eventWrites) {
    if (b.eventWrites.contains(e)) {
      reasons.add('both write event $e');
    } else if (b.eventReads.contains(e)) {
      reasons.add('event $e: ${a.name} writes, ${b.name} reads');
    }
  }
  for (final e in b.eventWrites) {
    if (a.eventReads.contains(e)) {
      reasons.add('event $e: ${b.name} writes, ${a.name} reads');
    }
  }

  return reasons;
}

/// The scheduler containing all systems organized by [Schedule].
///
/// The [Scheduler] owns one [SystemStage] per registered [Schedule] label.
/// Within each schedule, systems may run in parallel when they don't
/// conflict; between schedules the scheduler runs them serially in the
/// order they were registered.
///
/// ## Default Schedules
///
/// The scheduler registers every constant on [Schedules] by default,
/// but per-frame orchestration (including startup + fixed-timestep +
/// extract/render dispatch) is owned by [App]. Callers that hold a bare
/// [Scheduler] can still drive a single per-frame pass through the
/// non-startup schedules via [run] — see that method for exact order.
///
/// ## Example
///
/// ```dart
/// final scheduler = Scheduler()
///   ..addSystemToSchedule(inputSystem, Schedules.preUpdate)
///   ..addSystemToSchedule(movementSystem, Schedules.update)
///   ..addSystemToSchedule(renderSystem, Schedules.postUpdate);
///
/// // Run all per-frame schedules (equivalent to one App.tick minus
/// // startup + tick-counter bookkeeping).
/// await scheduler.run(world);
/// ```
class Scheduler {
  /// The stages in execution order.
  final List<SystemStage> _stages = [];

  /// Maps stage labels to their index.
  final Map<String, int> _stageIndex = {};

  /// Non-fixed per-frame schedules in the order [run] iterates them.
  ///
  /// The full per-frame sequence [App.tick] uses interleaves
  /// [runFixedIfDue] between [Schedules.preUpdate] and [Schedules.update],
  /// but that path is App-owned; [run] itself is now a compatibility
  /// shim that walks the non-fixed schedules in order and does not
  /// drive the fixed chain.
  static const List<Schedule> _perFrameSchedules = <Schedule>[
    Schedules.first,
    Schedules.preUpdate,
    Schedules.update,
    Schedules.postUpdate,
    Schedules.last,
    Schedules.extract,
    Schedules.render,
  ];

  /// The fixed-timestep chain, in the order each fixed iteration runs.
  static const List<Schedule> _fixedSchedules = <Schedule>[
    Schedules.fixedFirst,
    Schedules.fixedPreUpdate,
    Schedules.fixedUpdate,
    Schedules.fixedPostUpdate,
    Schedules.fixedLast,
  ];

  /// Creates a scheduler with every schedule in [Schedules.all] registered.
  Scheduler() {
    for (final schedule in Schedules.all) {
      addStage(schedule.name);
    }
  }

  /// Creates an empty scheduler with no schedules registered.
  Scheduler.empty();

  /// Adds a new stage to the scheduler.
  ///
  /// Stages are run in the order they are added. Prefer
  /// [addSchedule] for user-defined [Schedule] labels; this is the
  /// low-level primitive both the schedule and legacy stage APIs use.
  void addStage(String name) {
    if (_stageIndex.containsKey(name)) {
      throw ArgumentError('Stage $name already exists');
    }
    _stageIndex[name] = _stages.length;
    _stages.add(SystemStage(name));
  }

  /// Registers a user-defined [Schedule] with this scheduler.
  ///
  /// No-op if a schedule with the same [Schedule.name] is already
  /// registered.
  void addSchedule(Schedule schedule) {
    if (_stageIndex.containsKey(schedule.name)) return;
    addStage(schedule.name);
  }

  /// Adds a system to a schedule (or, via the deprecated [stage] parameter,
  /// to the corresponding legacy `CoreStage` bucket).
  ///
  /// If neither [stage] nor [schedule] is specified, the system is added
  /// to [Schedules.update]. Passing both throws [ArgumentError].
  void addSystem(
    System system, {
    @Deprecated('Use schedule: Schedules.foo instead of stage: CoreStage.foo.')
    CoreStage? stage,
    Schedule? schedule,
  }) {
    if (stage != null && schedule != null) {
      throw ArgumentError(
        'Pass either stage: or schedule: to Scheduler.addSystem, not both.',
      );
    }
    if (schedule != null) {
      addSystemToSchedule(system, schedule);
      return;
    }
    // stage may be null (default) — treat as CoreStage.update.
    addSystemToStage(system, (stage ?? CoreStage.update).name);
  }

  /// Adds a system to a named stage.
  void addSystemToStage(System system, String stageName) {
    final index = _stageIndex[stageName];
    if (index == null) {
      throw ArgumentError('Stage $stageName does not exist');
    }
    _stages[index].addSystem(system);
  }

  /// Adds a system to the given [Schedule].
  ///
  /// Throws a [StateError] if [schedule] hasn't been registered — call
  /// [addSchedule] first for custom schedules.
  void addSystemToSchedule(System system, Schedule schedule) {
    if (!_stageIndex.containsKey(schedule.name)) {
      throw StateError(
        "Schedule ${schedule.name} isn't registered — "
        'call scheduler.addSchedule(schedule) first.',
      );
    }
    addSystemToStage(system, schedule.name);
  }

  /// Runs one per-frame pass through the non-fixed schedules in order:
  /// `first → preUpdate → update → postUpdate → last → extract → render`.
  ///
  /// Kept for callers that hold a bare [Scheduler] (tests, adapters).
  ///
  /// **Note:** per-frame orchestration is now [App]-owned. [App.tick]
  /// drives startup, fixed-timestep dispatch, and change-detection tick
  /// bookkeeping around this method. When holding an [App], prefer
  /// [App.tick].
  ///
  /// Fixed-timestep schedules are **not** dispatched here — see
  /// [runFixedIfDue]. Startup is also not dispatched here — call
  /// [runSchedule] with [Schedules.startup] or use [App.runStartup].
  Future<void> run(World world) async {
    for (final schedule in _perFrameSchedules) {
      final index = _stageIndex[schedule.name];
      if (index == null) continue;
      await _stages[index].run(world);
    }
  }

  /// Runs a single named schedule.
  ///
  /// No-op if the schedule isn't registered. Used by
  /// [runSchedule] callers such as `App.runStartup`, [runFixedIfDue],
  /// and the per-frame render/extract dispatch in [App.tick].
  Future<void> runSchedule(Schedule schedule, World world) async {
    final index = _stageIndex[schedule.name];
    if (index == null) return;
    await _stages[index].run(world);
  }

  /// Advances the fixed-timestep accumulator by [frameDeltaSeconds] and
  /// runs the fixed schedule chain (`fixedFirst` → `fixedPreUpdate` →
  /// `fixedUpdate` → `fixedPostUpdate` → `fixedLast`) 0..
  /// [FixedTimestep.maxCatchupSteps] times.
  ///
  /// Each iteration counts as its own tick for change detection —
  /// [World.advanceTick] is called at the end of every fixed step.
  ///
  /// Returns the number of fixed steps that actually ran. Also
  /// mirrored into [FixedTimestep.stepsThisFrame] as a diagnostic.
  Future<int> runFixedIfDue(
    FixedTimestep timestep,
    double frameDeltaSeconds,
    World world,
  ) async {
    timestep.addAccumulated(frameDeltaSeconds);

    var steps = 0;
    while (timestep.accumulatorSeconds >= timestep.stepSeconds &&
        steps < timestep.maxCatchupSteps) {
      for (final schedule in _fixedSchedules) {
        final index = _stageIndex[schedule.name];
        if (index == null) continue;
        await _stages[index].run(world);
      }
      timestep.consumeStep();
      world.advanceTick();
      steps++;
    }

    // If we hit the cap while still owing more steps, drop the residual
    // so we don't spiral. If we simply ran out of accumulated time (the
    // normal exit), the leftover fractional step stays for next frame.
    if (steps == timestep.maxCatchupSteps &&
        timestep.accumulatorSeconds >= timestep.stepSeconds) {
      timestep.dropRemainder();
    }

    timestep.stepsThisFrame = steps;
    return steps;
  }

  /// Returns the stage with the given name.
  SystemStage? getStage(String name) {
    final index = _stageIndex[name];
    return index != null ? _stages[index] : null;
  }

  /// The number of stages.
  int get stageCount => _stages.length;

  /// The total number of systems across all stages.
  int get systemCount => _stages.fold(0, (sum, stage) => sum + stage.length);

  /// Clears all systems from all stages.
  ///
  /// The stages themselves are preserved, only the systems within them
  /// are removed. Use this when resetting the app to rebuild systems
  /// from plugins.
  void clear() {
    for (final stage in _stages) {
      stage.clear();
    }
  }

  /// Find every pair of systems whose relative execution order is
  /// determined purely by registration order.
  ///
  /// A pair is flagged when:
  ///
  /// 1. They live in the same schedule.
  /// 2. Their metas [SystemMeta.conflictsWith] each other (shared
  ///    component write, write-vs-read, shared resource, etc.) — so one
  ///    must run before the other.
  /// 3. Neither declares an explicit [SystemMeta.before] or
  ///    [SystemMeta.after] constraint referencing the other.
  ///
  /// The scheduler still produces a valid ordering (insertion order
  /// breaks the tie), but games that rely on that order are brittle —
  /// adding a plugin earlier in `App` setup can silently flip the pair.
  /// This is the bug class behind "my movement system can walk through
  /// walls because `CollisionResolutionSystem` runs first."
  ///
  /// Call this in debug builds or tests and treat the result as a
  /// smell. To silence a legitimate case, add `before:` / `after:` to
  /// one of the two systems' metas so the intent is explicit in source.
  List<OrderingAmbiguity> checkOrderingAmbiguities() {
    final out = <OrderingAmbiguity>[];
    for (final stage in _stages) {
      out.addAll(stage._findOrderingAmbiguities());
    }
    return out;
  }
}

/// One pair of systems in the same stage whose relative order is only
/// defined by registration order. See [Scheduler.checkOrderingAmbiguities].
class OrderingAmbiguity {
  /// Stage the pair lives in.
  ///
  /// This is the [Schedule.name] of the schedule the pair was found in.
  /// Retained as `stage` for backwards compatibility with pre-Schedule
  /// diagnostics; prefer [schedule] in new code.
  final String stage;

  /// Alias for [stage] — the schedule name the pair lives in.
  String get schedule => stage;

  /// First system — runs before [systemB] under the current registration.
  final String systemA;

  /// Second system — runs after [systemA] under the current registration.
  final String systemB;

  /// Human-readable reasons the scheduler had to serialise them (e.g.
  /// "both write Velocity", "conflict on resource WallTime").
  final List<String> reasons;

  const OrderingAmbiguity({
    required this.stage,
    required this.systemA,
    required this.systemB,
    required this.reasons,
  });

  @override
  String toString() =>
      'OrderingAmbiguity(stage=$stage): '
      '$systemA runs before $systemB by registration order only. '
      'Reasons: ${reasons.join('; ')}. '
      'Add `before: [\'$systemB\']` to $systemA (or the reverse) to make '
      'the intent explicit, or move one to a different stage.';
}
