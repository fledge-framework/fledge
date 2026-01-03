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

  SystemNode(this.system, [Set<int>? deps])
      : dependencies = deps ?? <int>{};
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
}
