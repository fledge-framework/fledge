import 'package:fledge_ecs/fledge_ecs.dart';

import '../extract/extract.dart';
import '../world/render_world.dart';
import 'render_stage.dart';

/// A system that can run in a render stage.
///
/// Render systems receive both the main world and render world,
/// allowing them to access game data and render-specific resources.
abstract class RenderSystem {
  /// The name of this system.
  String get name;

  /// Run the system.
  ///
  /// The [mainWorld] contains game entities and components.
  /// The [renderWorld] contains extracted render data and GPU resources.
  Future<void> run(World mainWorld, RenderWorld renderWorld);
}

/// A render system that wraps a function.
class FunctionRenderSystem implements RenderSystem {
  @override
  final String name;

  final Future<void> Function(World mainWorld, RenderWorld renderWorld) _run;

  /// Creates a function-based render system.
  FunctionRenderSystem(this.name, this._run);

  @override
  Future<void> run(World mainWorld, RenderWorld renderWorld) =>
      _run(mainWorld, renderWorld);
}

/// A render system that wraps a synchronous function.
class SyncRenderSystem implements RenderSystem {
  @override
  final String name;

  final void Function(World mainWorld, RenderWorld renderWorld) _run;

  /// Creates a synchronous render system.
  SyncRenderSystem(this.name, this._run);

  @override
  Future<void> run(World mainWorld, RenderWorld renderWorld) async {
    _run(mainWorld, renderWorld);
  }
}

/// Schedule that runs systems in render stages.
///
/// The render schedule organizes systems into stages that run in sequence.
/// Within each stage, systems run in the order they were added.
///
/// Example:
/// ```dart
/// final schedule = RenderSchedule();
///
/// // Add systems to stages
/// schedule.addSystem(RenderStage.prepare, prepareBuffersSystem);
/// schedule.addSystem(RenderStage.queue, batchSpritesSystem);
/// schedule.addSystem(RenderStage.render, executeGraphSystem);
///
/// // Run the schedule
/// await schedule.run(mainWorld, renderWorld);
/// ```
class RenderSchedule {
  final Map<RenderStage, List<RenderSystem>> _stages = {
    for (final stage in RenderStage.values) stage: [],
  };

  final ExtractSystem _extractSystem = ExtractSystem();

  /// Add a system to a stage.
  void addSystem(RenderStage stage, RenderSystem system) {
    _stages[stage]!.add(system);
  }

  /// Add a function-based system to a stage.
  void addFunctionSystem(
    RenderStage stage,
    String name,
    Future<void> Function(World mainWorld, RenderWorld renderWorld) run,
  ) {
    addSystem(stage, FunctionRenderSystem(name, run));
  }

  /// Add a synchronous function-based system to a stage.
  void addSyncSystem(
    RenderStage stage,
    String name,
    void Function(World mainWorld, RenderWorld renderWorld) run,
  ) {
    addSystem(stage, SyncRenderSystem(name, run));
  }

  /// Remove a system from a stage.
  bool removeSystem(RenderStage stage, RenderSystem system) {
    return _stages[stage]!.remove(system);
  }

  /// Remove a system by name from a stage.
  bool removeSystemByName(RenderStage stage, String name) {
    final systems = _stages[stage]!;
    final index = systems.indexWhere((s) => s.name == name);
    if (index >= 0) {
      systems.removeAt(index);
      return true;
    }
    return false;
  }

  /// Get all systems in a stage.
  List<RenderSystem> getSystems(RenderStage stage) =>
      List.unmodifiable(_stages[stage]!);

  /// Run the render schedule.
  ///
  /// Runs all stages in order, executing all systems within each stage.
  Future<void> run(World mainWorld, RenderWorld renderWorld) async {
    // Extract stage has special handling
    _extractSystem.run(mainWorld, renderWorld);
    for (final system in _stages[RenderStage.extract]!) {
      await system.run(mainWorld, renderWorld);
    }

    // Run remaining stages
    for (final stage in RenderStage.values) {
      if (stage == RenderStage.extract) continue;

      for (final system in _stages[stage]!) {
        await system.run(mainWorld, renderWorld);
      }
    }
  }

  /// Clear all systems from all stages.
  void clear() {
    for (final stage in RenderStage.values) {
      _stages[stage]!.clear();
    }
  }

  /// Get the total number of systems across all stages.
  int get systemCount =>
      _stages.values.fold(0, (sum, systems) => sum + systems.length);
}
