import 'dart:async';

import 'package:fledge_ecs_annotations/fledge_ecs_annotations.dart';

import '../world.dart';
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

  /// Maps system names to their indices for ordering constraints.
  final Map<String, int> _nameToIndex = {};

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

    // Build dependencies based on conflicts
    for (int i = 0; i < _systems.length; i++) {
      if (system.meta.conflictsWith(_systems[i].system.meta)) {
        node.dependencies.add(i);
      }
    }

    // Handle explicit `after` constraints
    for (final afterName in system.meta.after) {
      final afterIndex = _nameToIndex[afterName];
      if (afterIndex != null) {
        // System already exists, add it as a dependency
        node.dependencies.add(afterIndex);
      } else {
        // System doesn't exist yet, record for later
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

    // Handle explicit `before` constraints
    for (final beforeName in system.meta.before) {
      final beforeIndex = _nameToIndex[beforeName];
      if (beforeIndex != null) {
        // System already exists, update its dependencies
        _systems[beforeIndex].dependencies.add(newIndex);
      } else {
        // System doesn't exist yet, record for later
        _pendingBefore.putIfAbsent(beforeName, () => {}).add(newIndex);
      }
    }

    // Register this system's name
    _nameToIndex[systemName] = newIndex;

    _systems.add(node);
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
  /// order. Called by [Schedule.checkOrderingAmbiguities].
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
        out.add(OrderingAmbiguity(
          stage: name,
          systemA: a.name,
          systemB: b.name,
          reasons: _describeMetaConflict(a, b),
        ));
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

/// The schedule containing all systems organized by stage.
///
/// Systems are grouped into stages that run in a defined order.
/// Within each stage, systems may run in parallel if they don't conflict.
///
/// ## Default Stages
///
/// - **first**: Runs before all other stages
/// - **preUpdate**: Input processing, preparation
/// - **update**: Main game logic
/// - **postUpdate**: Reactions to update changes
/// - **last**: Cleanup, finalization
///
/// ## Example
///
/// ```dart
/// final schedule = Schedule()
///   ..addSystem(inputSystem, stage: CoreStage.preUpdate)
///   ..addSystem(movementSystem)  // defaults to update
///   ..addSystem(renderSystem, stage: CoreStage.postUpdate);
///
/// // Run all stages
/// await schedule.run(world);
/// ```
class Schedule {
  /// The stages in execution order.
  final List<SystemStage> _stages = [];

  /// Maps stage labels to their index.
  final Map<String, int> _stageIndex = {};

  /// Creates a schedule with the default core stages.
  Schedule() {
    for (final stage in CoreStage.values) {
      addStage(stage.name);
    }
  }

  /// Creates an empty schedule with no stages.
  Schedule.empty();

  /// Adds a new stage to the schedule.
  ///
  /// Stages are run in the order they are added.
  void addStage(String name) {
    if (_stageIndex.containsKey(name)) {
      throw ArgumentError('Stage $name already exists');
    }
    _stageIndex[name] = _stages.length;
    _stages.add(SystemStage(name));
  }

  /// Adds a system to a stage.
  ///
  /// If no stage is specified, the system is added to the 'update' stage.
  void addSystem(System system, {CoreStage stage = CoreStage.update}) {
    addSystemToStage(system, stage.name);
  }

  /// Adds a system to a named stage.
  void addSystemToStage(System system, String stageName) {
    final index = _stageIndex[stageName];
    if (index == null) {
      throw ArgumentError('Stage $stageName does not exist');
    }
    _stages[index].addSystem(system);
  }

  /// Runs all stages in order.
  Future<void> run(World world) async {
    for (final stage in _stages) {
      await stage.run(world);
    }
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
  /// 1. They live in the same stage.
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
/// defined by registration order. See [Schedule.checkOrderingAmbiguities].
class OrderingAmbiguity {
  /// Stage the pair lives in.
  final String stage;

  /// First system — runs before [systemB] under the current registration.
  final String systemA;

  /// Second system — runs after [systemA] under the current registration.
  final String systemB;

  /// Human-readable reasons the scheduler had to serialise them (e.g.
  /// "both write Velocity", "conflict on resource Time").
  final List<String> reasons;

  const OrderingAmbiguity({
    required this.stage,
    required this.systemA,
    required this.systemB,
    required this.reasons,
  });

  @override
  String toString() => 'OrderingAmbiguity(stage=$stage): '
      '$systemA runs before $systemB by registration order only. '
      'Reasons: ${reasons.join('; ')}. '
      'Add `before: [\'$systemB\']` to $systemA (or the reverse) to make '
      'the intent explicit, or move one to a different stage.';
}
