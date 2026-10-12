import 'dart:async';
import 'dart:typed_data';

import 'package:fledge_ecs_annotations/fledge_ecs_annotations.dart';

import '../fixed_timestep.dart';
import '../world.dart';
import 'schedule_label.dart';
import 'standard_sets.dart';
import 'system.dart';
import 'system_set.dart';

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
///
/// ## Ordering
///
/// The dependency graph is rebuilt from scratch whenever a system is
/// added or a system set is (re)configured via [Scheduler.configureSet],
/// from two edge sources:
///
/// 1. **Explicit edges.** A `before:` / `after:` reference — on a
///    system's [SystemMeta] or on a [SystemSet] in the set registry —
///    resolves to every system whose [SystemMeta.name] matches *and*
///    every system whose [SystemMeta.sets] contains the name. Duplicate
///    system names therefore fan out to every match. Set-level
///    constraints are closed transitively over the set configuration, so
///    an empty set still bridges a chain (`A before B`, `B before C`
///    orders A's members before C's). A cycle among explicit edges
///    throws a [StateError] immediately.
/// 2. **Conflict fallback edges.** For every pair of conflicting systems
///    (see [SystemMeta.conflictsWith]) that is *not* already ordered —
///    directly or transitively — the earlier-registered system runs
///    first. These edges never contradict the explicit ones.
class SystemStage {
  final String name;
  final List<SystemNode> _systems = [];

  /// The set registry consulted for set-level `before` / `after`
  /// constraints. Shared with the owning [Scheduler].
  final SystemSetRegistry _sets;

  /// Transitive closure of the *explicit* edges only: bit `j` of
  /// `_explicitReach[i]` is set when system `i` is required to run before
  /// system `j` by declared ordering (system- or set-level). Used by
  /// [_findOrderingAmbiguities].
  List<Uint32List> _explicitReach = const [];

  SystemStage(this.name, {SystemSetRegistry? sets})
    : _sets = sets ?? SystemSetRegistry();

  /// Adds a system to this stage.
  ///
  /// Throws a [StateError] — and leaves the stage unchanged — if the
  /// system's declared ordering forms a cycle with the systems and sets
  /// already present.
  void addSystem(System system) {
    _systems.add(SystemNode(system));
    final _StageGraph graph;
    try {
      graph = _computeGraph(_sets);
    } catch (_) {
      // The committed graph never referenced the new index, so dropping
      // the node restores a consistent state.
      _systems.removeLast();
      rethrow;
    }
    _commit(graph);
  }

  void _commit(_StageGraph graph) {
    for (var i = 0; i < _systems.length; i++) {
      _systems[i].dependencies
        ..clear()
        ..addAll(graph.dependencies[i]);
    }
    _explicitReach = graph.explicitReach;
  }

  /// Builds the full dependency graph for the current systems, using
  /// [registry] for set-level constraints. Throws [StateError] on an
  /// explicit cycle. Does not mutate the stage.
  _StageGraph _computeGraph(SystemSetRegistry registry) {
    final n = _systems.length;
    final metas = [for (final node in _systems) node.system.meta];

    // name / set -> indices, in registration order.
    final byName = <String, List<int>>{};
    final bySet = <String, List<int>>{};
    for (var i = 0; i < n; i++) {
      byName.putIfAbsent(metas[i].name, () => <int>[]).add(i);
      for (final set in metas[i].sets.toSet()) {
        bySet.putIfAbsent(set, () => <int>[]).add(i);
      }
    }
    Set<int> resolve(String ref) => {...?byName[ref], ...?bySet[ref]};

    // deps[j] contains i  <=>  i must complete before j starts.
    final deps = List<Set<int>>.generate(n, (_) => <int>{});
    void edge(int from, int to) {
      if (from != to) deps[to].add(from);
    }

    // 1a. Explicit edges declared on systems.
    for (var j = 0; j < n; j++) {
      for (final ref in metas[j].before) {
        for (final k in resolve(ref)) {
          edge(j, k);
        }
      }
      for (final ref in metas[j].after) {
        for (final k in resolve(ref)) {
          edge(k, j);
        }
      }
    }

    // 1b. Explicit edges declared on sets, closed transitively over the
    // set configuration so intermediate sets without members in this
    // stage still bridge the chain.
    final nameSucc = <String, Set<String>>{};
    for (final set in registry.all) {
      for (final ref in set.beforeList) {
        nameSucc.putIfAbsent(set.name, () => <String>{}).add(ref);
      }
      for (final ref in set.afterList) {
        nameSucc.putIfAbsent(ref, () => <String>{}).add(set.name);
      }
    }
    for (final start in nameSucc.keys) {
      final from = resolve(start);
      if (from.isEmpty) continue;
      final seen = <String>{};
      final stack = [...nameSucc[start]!];
      while (stack.isNotEmpty) {
        final next = stack.removeLast();
        if (!seen.add(next)) continue;
        stack.addAll(nameSucc[next] ?? const <String>{});
      }
      for (final target in seen) {
        if (target == start) continue;
        for (final j in resolve(target)) {
          for (final i in from) {
            edge(i, j);
          }
        }
      }
    }

    // Fail fast on explicit cycles; otherwise get a topological order.
    final topo = _topologicalOrder(deps) ?? _throwCycle(deps, metas);

    // Transitive closure of the explicit edges.
    final words = (n + 31) >> 5;
    final succ = _successors(deps);
    final explicitReach = List<Uint32List>.generate(
      n,
      (_) => Uint32List(words),
    );
    for (final i in topo.reversed) {
      final row = explicitReach[i];
      for (final s in succ[i]) {
        _setBit(row, s);
        final other = explicitReach[s];
        for (var w = 0; w < words; w++) {
          row[w] |= other[w];
        }
      }
    }

    // 2. Conflict fallback edges in registration order, skipped when the
    // pair is already ordered (either way) by explicit edges or by the
    // fallback edges added so far — so they can never close a cycle.
    //
    // `reach[a]` = nodes a must precede; `back[b]` = nodes that must
    // precede b. Visiting each later system's earlier partners nearest-
    // first means a run of mutually conflicting systems becomes a chain
    // (n - 1 edges) rather than a complete DAG — same ordering, far less
    // closure maintenance.
    final reach = [for (final row in explicitReach) Uint32List.fromList(row)];
    final back = List<Uint32List>.generate(n, (_) => Uint32List(words));
    for (var a = 0; a < n; a++) {
      for (final b in _bits(reach[a], n)) {
        _setBit(back[b], a);
      }
    }
    for (var j = 1; j < n; j++) {
      for (var i = j - 1; i >= 0; i--) {
        if (_hasBit(reach[i], j) || _hasBit(reach[j], i)) continue;
        if (!metas[i].conflictsWith(metas[j])) continue;
        deps[j].add(i);
        // Everything that reaches i (and i itself) now reaches j and
        // everything j reaches.
        final sources = Uint32List.fromList(back[i]);
        _setBit(sources, i);
        final targets = Uint32List.fromList(reach[j]);
        _setBit(targets, j);
        for (final a in _bits(sources, n)) {
          final row = reach[a];
          for (var w = 0; w < words; w++) {
            row[w] |= targets[w];
          }
        }
        for (final b in _bits(targets, n)) {
          final row = back[b];
          for (var w = 0; w < words; w++) {
            row[w] |= sources[w];
          }
        }
      }
    }

    return _StageGraph(deps, explicitReach);
  }

  static List<List<int>> _successors(List<Set<int>> deps) {
    final succ = List<List<int>>.generate(deps.length, (_) => <int>[]);
    for (var j = 0; j < deps.length; j++) {
      for (final i in deps[j]) {
        succ[i].add(j);
      }
    }
    return succ;
  }

  /// Kahn's algorithm. Returns null when [deps] contains a cycle.
  static List<int>? _topologicalOrder(List<Set<int>> deps) {
    final n = deps.length;
    final remaining = [for (final d in deps) d.length];
    final succ = _successors(deps);
    final order = <int>[
      for (var i = 0; i < n; i++)
        if (remaining[i] == 0) i,
    ];
    for (var head = 0; head < order.length; head++) {
      for (final j in succ[order[head]]) {
        if (--remaining[j] == 0) order.add(j);
      }
    }
    return order.length == n ? order : null;
  }

  /// Finds a cycle in [deps] and throws a [StateError] naming every
  /// system on it, along with the sets each belongs to.
  Never _throwCycle(List<Set<int>> deps, List<SystemMeta> metas) {
    const unvisited = 0;
    const onStack = 1;
    const done = 2;
    final state = List<int>.filled(deps.length, unvisited);
    final path = <int>[];

    List<int>? visit(int index) {
      state[index] = onStack;
      path.add(index);
      for (final dep in deps[index]) {
        if (state[dep] == onStack) {
          return path.sublist(path.indexOf(dep));
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

    List<int>? cycle;
    for (var i = 0; i < deps.length && cycle == null; i++) {
      if (state[i] == unvisited) cycle = visit(i);
    }
    // The walk follows "depends on" links; reverse so the message reads
    // in would-be execution order.
    final labels = cycle!.reversed.map((idx) {
      final meta = metas[idx];
      return meta.sets.isEmpty
          ? meta.name
          : '${meta.name} [${meta.sets.toSet().join(', ')}]';
    }).toList();
    throw StateError(
      'Cycle detected in stage "$name" among systems: '
      '${labels.join(" -> ")} -> ${labels.first}. '
      'Check the before:/after: declarations on these systems and the '
      'configureSet ordering of the [sets] they belong to.',
    );
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
    _explicitReach = const [];
  }

  /// Scan pairs in this stage for ordering determined only by registration
  /// order: conflicting pairs that no explicit edge path (system- or
  /// set-level, direct or transitive) orders either way. Called by
  /// [Scheduler.checkOrderingAmbiguities].
  List<OrderingAmbiguity> _findOrderingAmbiguities() {
    final out = <OrderingAmbiguity>[];
    for (var i = 0; i < _systems.length; i++) {
      final a = _systems[i].system.meta;
      for (var j = i + 1; j < _systems.length; j++) {
        final b = _systems[j].system.meta;
        if (!a.conflictsWith(b)) continue;
        if (_hasBit(_explicitReach[i], j) || _hasBit(_explicitReach[j], i)) {
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

/// Result of [SystemStage._computeGraph], committed atomically.
class _StageGraph {
  /// Per-system dependency sets (explicit + conflict fallback).
  final List<Set<int>> dependencies;

  /// Transitive closure of the explicit edges only.
  final List<Uint32List> explicitReach;

  _StageGraph(this.dependencies, this.explicitReach);
}

bool _hasBit(Uint32List row, int bit) =>
    (row[bit >> 5] & (1 << (bit & 31))) != 0;

void _setBit(Uint32List row, int bit) {
  row[bit >> 5] |= 1 << (bit & 31);
}

/// Indices of the set bits in [row] below [limit], ascending.
Iterable<int> _bits(Uint32List row, int limit) sync* {
  for (var w = 0; w < row.length; w++) {
    final word = row[w];
    if (word == 0) continue;
    for (var b = 0; b < 32; b++) {
      if (word & (1 << b) != 0) {
        final index = (w << 5) + b;
        if (index < limit) yield index;
      }
    }
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

  /// System set configuration shared by every schedule.
  ///
  /// Set-level `before` / `after` constraints apply within each schedule
  /// to whichever members that schedule contains. Change configuration
  /// through [configureSet] so every schedule's graph is rebuilt; mutating
  /// the registry directly only takes effect on the next [addSystem].
  ///
  /// Survives [clear].
  final SystemSetRegistry sets = SystemSetRegistry();

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

  /// Creates a scheduler with every schedule in [Schedules.all] registered
  /// and the standard [FirstSets] phases of [Schedules.first] chained in
  /// order (`frameStart` → `platform` → `input` → `content`).
  Scheduler() {
    for (final schedule in Schedules.all) {
      addStage(schedule.name);
    }
    const chain = FirstSets.chain;
    for (var i = 0; i + 1 < chain.length; i++) {
      sets.configure(chain[i], (s) => s.before(chain[i + 1]));
    }
    sets.getOrCreate(chain.last);
  }

  /// Creates an empty scheduler with no schedules registered and no
  /// system sets configured (not even the standard [FirstSets] phases).
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
    _stages.add(SystemStage(name, sets: sets));
  }

  /// Configures the system set [name] (creating it if needed) and
  /// rebuilds every schedule's dependency graph so the change applies to
  /// systems that are already registered.
  ///
  /// If the new configuration would create an ordering cycle in any
  /// schedule, throws a [StateError] and leaves both the set and the
  /// schedules unchanged.
  ///
  /// ```dart
  /// scheduler.configureSet('physics', (s) => s.after('input'));
  /// ```
  void configureSet(String name, void Function(SystemSet set) configure) {
    // Apply the change to a scratch copy first so a cycle can be
    // rejected without corrupting the live configuration.
    final probe = SystemSet(name);
    final existing = sets.get(name);
    if (existing != null) _copySetInto(existing, probe);
    configure(probe);

    final candidate = SystemSetRegistry();
    for (final set in sets.all) {
      if (set.name == name) continue;
      candidate.configure(set.name, (c) => _copySetInto(set, c));
    }
    candidate.configure(name, (c) => _copySetInto(probe, c));

    final graphs = [
      for (final stage in _stages) stage._computeGraph(candidate),
    ];

    // SystemSet only grows (lists de-duplicate, runIf replaces), so
    // copying the probe onto the live set reproduces it exactly while
    // keeping object identity for SetConfiguredSystem wrappers.
    sets.configure(name, (live) => _copySetInto(probe, live));
    for (var i = 0; i < _stages.length; i++) {
      _stages[i]._commit(graphs[i]);
    }
  }

  static void _copySetInto(SystemSet from, SystemSet to) {
    for (final ref in from.beforeList) {
      to.before(ref);
    }
    for (final ref in from.afterList) {
      to.after(ref);
    }
    final condition = from.runCondition;
    if (condition != null) to.runIf(condition);
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
  ///
  /// System set configuration in [sets] is kept, so sets configured
  /// outside of a plugin's `build` (or by session-level plugins) still
  /// apply to systems re-registered afterwards.
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
  /// 3. No chain of explicit ordering — [SystemMeta.before] /
  ///    [SystemMeta.after] on systems, or set constraints from
  ///    [configureSet], directly or transitively — orders them.
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
