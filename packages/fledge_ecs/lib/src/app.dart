import 'package:fledge_ecs_annotations/fledge_ecs_annotations.dart';

import 'entity.dart';
import 'fixed_timestep.dart';
import 'plugin.dart';
import 'plugins/time_plugin.dart';
import 'state/state_conditions.dart';
import 'state/state_machine.dart';
import 'system/run_condition.dart';
import 'system/schedule.dart';
import 'system/schedule_label.dart';
import 'system/system.dart';
import 'system/system_set.dart';
import 'world.dart';

/// The main application builder for ECS games.
///
/// [App] provides a fluent API for configuring the ECS world, adding plugins,
/// resources, events, and systems. It manages the game loop and lifecycle.
///
/// ## Example
///
/// ```dart
/// void main() async {
///   await App()
///     .addPlugin(WallTimePlugin())
///     .insertResource(GameConfig())
///     .addEvent<CollisionEvent>()
///     .addSystem(MovementSystemWrapper())
///     .addSystem(RenderSystemWrapper(), schedule: Schedules.last)
///     .run();
/// }
/// ```
class App {
  /// The ECS world containing all entities, components, resources, and events.
  final World world = World();

  /// The scheduler managing system execution.
  final Scheduler scheduler = Scheduler();

  /// Deprecated alias for [scheduler].
  ///
  /// The runtime container was renamed from `Schedule` to `Scheduler` in
  /// v0.2 to free up the name for the [Schedule] label value type. This
  /// getter keeps existing call sites (e.g. `app.schedule.systemCount`)
  /// working for one release.
  @Deprecated('Renamed to scheduler in v0.2. Use App.scheduler instead.')
  Scheduler get schedule => scheduler;

  /// Installed plugins.
  final List<Plugin> _plugins = [];

  /// Registry for tracking all state machines.
  final StateRegistry _states = StateRegistry();

  /// Registry for system sets.
  final SystemSetRegistry _systemSets = SystemSetRegistry();

  /// Whether the app is currently running.
  bool _running = false;

  /// True once [Schedules.startup] has been dispatched. Startup runs
  /// exactly once, on the first call to [tick] or [runStartup] —
  /// whichever comes first.
  bool _startupHasRun = false;

  /// Fallback stopwatch used to compute frame delta when no [WallTime]
  /// resource is available (i.e. the user did not add [WallTimePlugin]).
  /// Lazily started on the first tick.
  final Stopwatch _fallbackClock = Stopwatch();
  double _fallbackLastSeconds = 0.0;

  /// The number of plugins that are considered session-level.
  /// Set by [markSessionCheckpoint].
  int _sessionPluginCount = 0;

  /// Entity snapshot for game-level checkpoint.
  /// Set by [markGameCheckpoint].
  Set<Entity>? _gameCheckpointEntities;

  /// Callback for each frame tick.
  void Function(App app)? _onTick;

  /// Callback when the app starts.
  void Function(App app)? _onStart;

  /// Callback when the app stops.
  void Function(App app)? _onStop;

  /// Creates an [App] with a default [FixedTimestep] resource (60Hz,
  /// 5-step catchup cap). Games that need a different cadence can
  /// override the resource with `insertResource(FixedTimestep(...))`
  /// before calling [run] / [tick].
  App() {
    world.insertResource(FixedTimestep());
  }

  /// Adds a plugin to the app.
  ///
  /// Plugins are built in order and can configure resources, events,
  /// and systems.
  ///
  /// ```dart
  /// app.addPlugin(PhysicsPlugin());
  /// ```
  App addPlugin(Plugin plugin) {
    plugin.build(this);
    _plugins.add(plugin);
    return this;
  }

  /// Adds multiple plugins to the app.
  ///
  /// ```dart
  /// app.addPlugins([PhysicsPlugin(), RenderPlugin()]);
  /// ```
  App addPlugins(List<Plugin> plugins) {
    for (final plugin in plugins) {
      addPlugin(plugin);
    }
    return this;
  }

  /// Inserts a resource into the world.
  ///
  /// ```dart
  /// app.insertResource(GameConfig(difficulty: 'hard'));
  /// ```
  App insertResource<T>(T resource) {
    world.insertResource(resource);
    return this;
  }

  /// Registers an event type.
  ///
  /// ```dart
  /// app.addEvent<CollisionEvent>();
  /// ```
  App addEvent<T>() {
    world.registerEvent<T>();
    return this;
  }

  /// Adds a state machine for the given enum type.
  ///
  /// The state is stored as a resource in the world and can be accessed
  /// via `world.getResource<State<S>>()` or the convenience methods.
  ///
  /// ```dart
  /// app.addState<GameState>(GameState.menu);
  /// ```
  App addState<S extends Enum>(S initialState) {
    final state = State<S>(initialState);
    world.insertResource(state);
    _states.add(state);
    return this;
  }

  /// Adds a system that only runs when in the specified state.
  ///
  /// This is a convenience method that wraps the system with an
  /// [InState] run condition.
  ///
  /// The system's target schedule can be specified either with the
  /// legacy [stage] parameter or the new [schedule] parameter. Passing
  /// both throws an [ArgumentError]; passing neither defaults to
  /// [Schedules.update].
  ///
  /// ```dart
  /// app.addSystemInState(movementSystem, GameState.playing);
  /// app.addSystemInState(
  ///   movementSystem,
  ///   GameState.playing,
  ///   schedule: Schedules.update,
  /// );
  /// ```
  App addSystemInState<S extends Enum>(
    System system,
    S state, {
    @Deprecated('Use schedule: Schedules.foo instead of stage: CoreStage.foo.')
    CoreStage? stage,
    Schedule? schedule,
  }) {
    // Wrap the system with a state condition
    final wrappedSystem = _StateConditionSystem(
      system,
      InState<S>(state).condition,
    );
    _addSystemToTarget(wrappedSystem, stage: stage, schedule: schedule);
    return this;
  }

  /// Adds a system to the scheduler.
  ///
  /// The system's target schedule can be specified either with the
  /// legacy [stage] parameter or the new [schedule] parameter. Passing
  /// both throws an [ArgumentError]; passing neither defaults to
  /// [Schedules.update].
  ///
  /// ```dart
  /// app.addSystem(MovementSystemWrapper());
  /// app.addSystem(RenderSystemWrapper(), schedule: Schedules.last);
  /// ```
  App addSystem(
    System system, {
    @Deprecated('Use schedule: Schedules.foo instead of stage: CoreStage.foo.')
    CoreStage? stage,
    Schedule? schedule,
  }) {
    _addSystemToTarget(system, stage: stage, schedule: schedule);
    return this;
  }

  /// Adds multiple systems to the scheduler.
  ///
  /// All systems are added to the same target schedule. Passing both
  /// [stage] and [schedule] throws an [ArgumentError]; passing neither
  /// defaults to [Schedules.update].
  ///
  /// ```dart
  /// app.addSystems([
  ///   MovementSystemWrapper(),
  ///   PhysicsSystemWrapper(),
  /// ], schedule: Schedules.update);
  /// ```
  App addSystems(
    List<System> systems, {
    @Deprecated('Use schedule: Schedules.foo instead of stage: CoreStage.foo.')
    CoreStage? stage,
    Schedule? schedule,
  }) {
    for (final system in systems) {
      _addSystemToTarget(system, stage: stage, schedule: schedule);
    }
    return this;
  }

  /// Resolves the target [Schedule] for a system given the legacy [stage]
  /// parameter and the new [schedule] parameter, then adds it to the
  /// [scheduler].
  ///
  /// - Passing both is a caller error and throws [ArgumentError].
  /// - Passing only [stage] maps the [CoreStage] to a [Schedule] via
  ///   [_stageToSchedule].
  /// - Passing only [schedule] uses it directly.
  /// - Passing neither defaults to [Schedules.update].
  void _addSystemToTarget(
    System system, {
    CoreStage? stage,
    Schedule? schedule,
  }) {
    if (stage != null && schedule != null) {
      throw ArgumentError(
        'Pass either `stage:` or `schedule:` to addSystem — not both. '
        '`stage:` is deprecated; prefer `schedule: Schedules.foo`.',
      );
    }
    final target = schedule ??
        (stage != null ? _stageToSchedule(stage) : Schedules.update);
    scheduler.addSystemToSchedule(system, target);
  }

  /// Maps a legacy [CoreStage] to the equivalent [Schedule] label.
  Schedule _stageToSchedule(CoreStage stage) {
    switch (stage) {
      case CoreStage.first:
        return Schedules.first;
      case CoreStage.preUpdate:
        return Schedules.preUpdate;
      case CoreStage.update:
        return Schedules.update;
      case CoreStage.postUpdate:
        return Schedules.postUpdate;
      case CoreStage.last:
        return Schedules.last;
    }
  }

  /// Configures a system set with ordering constraints and run conditions.
  ///
  /// System sets allow grouping related systems and applying shared
  /// configuration. The [configure] callback receives the set for
  /// fluent configuration.
  ///
  /// ```dart
  /// app.configureSet('physics', (s) => s
  ///   .after('input')
  ///   .before('render')
  ///   .runIf((world) => !world.isPaused));
  /// ```
  App configureSet(String name, void Function(SystemSet) configure) {
    _systemSets.configure(name, configure);
    return this;
  }

  /// Adds a system to a named set.
  ///
  /// The system will inherit the set's ordering constraints and
  /// run conditions.
  ///
  /// The system's target schedule can be specified either with the
  /// legacy [stage] parameter or the new [schedule] parameter. Passing
  /// both throws an [ArgumentError]; passing neither defaults to
  /// [Schedules.update].
  ///
  /// ```dart
  /// app
  ///   .configureSet('physics', (s) => s.after('input'))
  ///   .addSystemToSet(gravitySystem, 'physics')
  ///   .addSystemToSet(collisionSystem, 'physics');
  /// ```
  App addSystemToSet(
    System system,
    String setName, {
    @Deprecated('Use schedule: Schedules.foo instead of stage: CoreStage.foo.')
    CoreStage? stage,
    Schedule? schedule,
  }) {
    final set = _systemSets.getOrCreate(setName);
    final wrappedSystem = SetConfiguredSystem(system, set);
    _addSystemToTarget(wrappedSystem, stage: stage, schedule: schedule);
    return this;
  }

  /// Sets a callback to be called each frame.
  ///
  /// ```dart
  /// app.onTick((app) {
  ///   if (shouldQuit) app.stop();
  /// });
  /// ```
  App onTick(void Function(App app) callback) {
    _onTick = callback;
    return this;
  }

  /// Sets a callback to be called when the app starts.
  App onStart(void Function(App app) callback) {
    _onStart = callback;
    return this;
  }

  /// Sets a callback to be called when the app stops.
  App onStop(void Function(App app) callback) {
    _onStop = callback;
    return this;
  }

  /// Runs the app's game loop.
  ///
  /// The loop runs until [stop] is called. Each iteration:
  /// 1. Updates event queues
  /// 2. Runs all scheduled systems
  /// 3. Calls the tick callback if set
  ///
  /// ```dart
  /// await app.run();
  /// ```
  Future<void> run() async {
    _running = true;
    _onStart?.call(this);

    while (_running) {
      await tick();
    }

    _onStop?.call(this);

    // Cleanup plugins
    for (final plugin in _plugins.reversed) {
      plugin.cleanup();
    }
  }

  /// Executes a single frame/tick.
  ///
  /// Runs, in order (Phase 1c):
  ///
  /// 1. Event queue update.
  /// 2. [Schedules.startup] — only on the first call, exactly once.
  /// 3. [Schedules.first], [Schedules.preUpdate].
  /// 4. Fixed-timestep chain via [Scheduler.runFixedIfDue] (0..
  ///    [FixedTimestep.maxCatchupSteps] iterations).
  /// 5. [Schedules.update], [Schedules.postUpdate], [Schedules.last].
  /// 6. [Schedules.extract], [Schedules.render].
  /// 7. `onTick` callback, per-frame change-detection tick, pending
  ///    state transitions.
  ///
  /// Useful for testing or manual control of the game loop.
  ///
  /// ```dart
  /// await app.tick();
  /// ```
  Future<void> tick() async {
    // Update event queues (swap buffers)
    world.updateEvents();

    // Startup runs once, before the first real frame.
    if (!_startupHasRun) {
      _startupHasRun = true;
      await scheduler.runSchedule(Schedules.startup, world);
    }

    // Frame delta comes from WallTime if available, else the fallback
    // stopwatch. This is consumed by the fixed-timestep accumulator.
    final delta = _frameDeltaSeconds();

    final timestep = world.getResource<FixedTimestep>()!;

    await scheduler.runSchedule(Schedules.first, world);
    await scheduler.runSchedule(Schedules.preUpdate, world);
    await scheduler.runFixedIfDue(timestep, delta, world);
    await scheduler.runSchedule(Schedules.update, world);
    await scheduler.runSchedule(Schedules.postUpdate, world);
    await scheduler.runSchedule(Schedules.last, world);
    await scheduler.runSchedule(Schedules.extract, world);
    await scheduler.runSchedule(Schedules.render, world);

    // Call tick callback
    _onTick?.call(this);

    // Advance tick counter for change detection
    world.advanceTick();

    // Apply state transitions for next frame
    _applyStateTransitions();
  }

  /// Frame delta in seconds for the current tick.
  ///
  /// Prefers the [WallTime] resource (populated by `WallTimePlugin`).
  /// If no [WallTime] resource is present, falls back to an internal
  /// stopwatch so fixed-timestep dispatch still works without the
  /// plugin.
  double _frameDeltaSeconds() {
    final time = world.getResource<WallTime>();
    if (time != null) return time.delta;

    if (!_fallbackClock.isRunning) {
      _fallbackClock.start();
      _fallbackLastSeconds = 0.0;
      return 0.0;
    }
    final now = _fallbackClock.elapsedMicroseconds / 1e6;
    final delta = now - _fallbackLastSeconds;
    _fallbackLastSeconds = now;
    return delta;
  }

  /// Applies all pending state transitions.
  void _applyStateTransitions() {
    _states.applyTransitions();
  }

  /// Runs the [Schedules.startup] schedule.
  ///
  /// Startup auto-runs on the first call to [tick]; calling this
  /// method explicitly beforehand is optional and idempotent — the
  /// first invocation dispatches [Schedules.startup] and marks it done,
  /// subsequent calls (including the implicit one inside [tick]) are
  /// no-ops.
  ///
  /// Users don't need to call this in normal setup; it exists for
  /// tests and games that want startup to complete before the first
  /// frame's `first`/`preUpdate` schedules run in a separate step.
  Future<void> runStartup() async {
    if (_startupHasRun) return;
    _startupHasRun = true;
    await scheduler.runSchedule(Schedules.startup, world);
  }

  /// Walk the schedule for pairs of systems whose relative order is
  /// determined only by registration order (i.e. they conflict but
  /// neither has an explicit `before:` / `after:` constraint on the
  /// other). This is the bug class behind subtle physics / input /
  /// render issues like "my movement system runs after collision
  /// resolution and the player walks through walls."
  ///
  /// Intended for use in tests or a debug-build boot path:
  ///
  /// ```dart
  /// void main() {
  ///   final app = buildApp();
  ///   assert(() {
  ///     final issues = app.checkScheduleOrdering();
  ///     if (issues.isNotEmpty) {
  ///       // ignore: avoid_print
  ///       issues.forEach(print);
  ///     }
  ///     return true;
  ///   }());
  ///   runApp(GameWidget(app: app));
  /// }
  /// ```
  ///
  /// Returns an empty list when every same-stage conflict has an
  /// explicit ordering.
  List<OrderingAmbiguity> checkScheduleOrdering() =>
      scheduler.checkOrderingAmbiguities();

  /// Stops the running game loop.
  ///
  /// The loop will exit after the current frame completes.
  void stop() {
    _running = false;
  }

  /// Returns true if the app is currently running.
  bool get isRunning => _running;

  /// Marks the current state as the session checkpoint.
  ///
  /// All plugins added before this call are considered session-level plugins.
  /// When [resetToSessionCheckpoint] is called, plugins added after this
  /// checkpoint will be cleaned up and removed.
  ///
  /// Call this in your app initialization after adding core/session plugins
  /// but before entering the game screen.
  ///
  /// ```dart
  /// final app = App()
  ///   ..addPlugin(WindowPlugin())
  ///   ..addPlugin(WallTimePlugin())
  ///   ..addPlugin(AudioPlugin());
  ///
  /// app.markSessionCheckpoint(); // These plugins will persist
  ///
  /// // Later, game plugins are added...
  /// app.addPlugin(GamePlugin());
  ///
  /// // On game exit, reset to session state
  /// app.resetToSessionCheckpoint();
  /// ```
  void markSessionCheckpoint() {
    _sessionPluginCount = _plugins.length;
  }

  /// Resets the app to the session checkpoint state.
  ///
  /// This:
  /// 1. Calls [cleanup] on all game-level plugins (in reverse order)
  /// 2. Removes game-level plugins from the app
  /// 3. Clears all systems from the schedule
  /// 4. Rebuilds systems from session-level plugins
  /// 5. Resets game-level world state (entities, events)
  ///
  /// Session-level resources are preserved. Game-level plugins should
  /// remove their resources in their [cleanup] method.
  ///
  /// Call this when returning to the main menu or starting a new game.
  void resetToSessionCheckpoint() {
    // 1. Cleanup game plugins in reverse order
    while (_plugins.length > _sessionPluginCount) {
      final plugin = _plugins.removeLast();
      plugin.cleanup();
    }

    // 2. Clear all systems from the scheduler
    scheduler.clear();

    // 3. Rebuild systems from session plugins
    // Copy the list to avoid concurrent modification if build() adds plugins
    final sessionPlugins = _plugins.toList();
    for (final plugin in sessionPlugins) {
      plugin.build(this);
    }

    // 4. Reset world game state
    world.resetGameState();

    // 5. Clear game checkpoint since entities are gone
    _gameCheckpointEntities = null;
  }

  /// Marks the current entity state as the game checkpoint.
  ///
  /// All entities that exist at this point will be preserved when
  /// [resetToGameCheckpoint] is called. Entities spawned after this
  /// checkpoint will be despawned.
  ///
  /// This is useful for map transitions where you want to preserve
  /// persistent entities (camera, player) but clean up map-specific
  /// entities (tiles, NPCs, objects).
  ///
  /// ```dart
  /// // Spawn persistent entities
  /// spawnCamera(app.world);
  /// spawnPlayer(app.world);
  /// app.markGameCheckpoint(); // These entities will persist
  ///
  /// // Later, spawn map entities...
  /// spawnTilemap(app.world);
  ///
  /// // On map transition:
  /// app.resetToGameCheckpoint(); // Removes tilemap, keeps camera/player
  /// spawnNewTilemap(app.world);
  /// ```
  void markGameCheckpoint() {
    _gameCheckpointEntities = world.getAllEntities();
  }

  /// Resets to the game checkpoint state.
  ///
  /// Despawns all entities that were spawned after [markGameCheckpoint]
  /// was called. Clears event queues but preserves resources, plugins,
  /// and systems.
  ///
  /// Throws [StateError] if [markGameCheckpoint] was not called first.
  ///
  /// Call this before loading a new map to clean up the old one.
  void resetToGameCheckpoint() {
    if (_gameCheckpointEntities == null) {
      throw StateError(
          'No game checkpoint set. Call markGameCheckpoint() first.');
    }
    world.despawnExcept(_gameCheckpointEntities!);
    world.events.clear();
  }

  /// Clears the game checkpoint without resetting.
  ///
  /// Call this when returning to the main menu (before [resetToSessionCheckpoint])
  /// if you want to explicitly clear the checkpoint.
  ///
  /// Note: [resetToSessionCheckpoint] automatically clears the game checkpoint.
  void clearGameCheckpoint() {
    _gameCheckpointEntities = null;
  }

  /// Returns true if a game checkpoint has been set.
  bool get hasGameCheckpoint => _gameCheckpointEntities != null;

  /// Updates a single frame without entering the game loop.
  ///
  /// Useful for running a fixed number of updates.
  ///
  /// ```dart
  /// for (var i = 0; i < 100; i++) {
  ///   await app.update();
  /// }
  /// ```
  Future<void> update() => tick();
}

/// Runner for apps with frame timing.
///
/// Provides utilities for running the game loop with specific timing.
class AppRunner {
  final App app;
  final Duration targetFrameTime;

  AppRunner(this.app,
      {this.targetFrameTime = const Duration(milliseconds: 16)});

  /// Runs the app with frame timing.
  ///
  /// Attempts to maintain the target frame rate by delaying between frames.
  Future<void> run() async {
    final stopwatch = Stopwatch();

    app._running = true;
    app._onStart?.call(app);

    while (app._running) {
      stopwatch.reset();
      stopwatch.start();

      await app.tick();

      stopwatch.stop();
      final elapsed = stopwatch.elapsed;

      if (elapsed < targetFrameTime) {
        await Future.delayed(targetFrameTime - elapsed);
      }
    }

    app._onStop?.call(app);

    for (final plugin in app._plugins.reversed) {
      plugin.cleanup();
    }
  }

  /// Runs the app for a fixed number of frames.
  ///
  /// Useful for testing.
  Future<void> runFrames(int count) async {
    for (var i = 0; i < count; i++) {
      await app.tick();
    }
  }
}

/// Internal wrapper that adds a state condition to an existing system.
class _StateConditionSystem implements System {
  final System _inner;
  final RunCondition _stateCondition;

  _StateConditionSystem(this._inner, this._stateCondition);

  @override
  SystemMeta get meta => _inner.meta;

  @override
  RunCondition? get runCondition {
    final innerCondition = _inner.runCondition;
    if (innerCondition == null) {
      return _stateCondition;
    }
    // Combine both conditions with AND
    return (world) => _stateCondition(world) && innerCondition(world);
  }

  @override
  bool shouldRun(World world) => runCondition?.call(world) ?? true;

  @override
  Future<void> run(World world) => _inner.run(world);
}
