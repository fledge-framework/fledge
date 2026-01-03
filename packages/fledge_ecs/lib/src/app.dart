import 'package:fledge_ecs_annotations/fledge_ecs_annotations.dart';

import 'plugin.dart';
import 'state/state_conditions.dart';
import 'state/state_machine.dart';
import 'system/run_condition.dart';
import 'system/schedule.dart';
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
///     .addPlugin(TimePlugin())
///     .insertResource(GameConfig())
///     .addEvent<CollisionEvent>()
///     .addSystem(MovementSystemWrapper())
///     .addSystem(RenderSystemWrapper(), stage: CoreStage.last)
///     .run();
/// }
/// ```
class App {
  /// The ECS world containing all entities, components, resources, and events.
  final World world = World();

  /// The schedule managing system execution.
  final Schedule schedule = Schedule();

  /// Installed plugins.
  final List<Plugin> _plugins = [];

  /// Registry for tracking all state machines.
  final StateRegistry _states = StateRegistry();

  /// Registry for system sets.
  final SystemSetRegistry _systemSets = SystemSetRegistry();

  /// Whether the app is currently running.
  bool _running = false;

  /// The number of plugins that are considered session-level.
  /// Set by [markSessionCheckpoint].
  int _sessionPluginCount = 0;

  /// Callback for each frame tick.
  void Function(App app)? _onTick;

  /// Callback when the app starts.
  void Function(App app)? _onStart;

  /// Callback when the app stops.
  void Function(App app)? _onStop;

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
  /// ```dart
  /// app.addSystemInState(movementSystem, GameState.playing);
  /// ```
  App addSystemInState<S extends Enum>(
    System system,
    S state, {
    CoreStage stage = CoreStage.update,
  }) {
    // Wrap the system with a state condition
    final wrappedSystem = _StateConditionSystem(
      system,
      InState<S>(state).condition,
    );
    schedule.addSystem(wrappedSystem, stage: stage);
    return this;
  }

  /// Adds a system to the schedule.
  ///
  /// ```dart
  /// app.addSystem(MovementSystemWrapper());
  /// app.addSystem(RenderSystemWrapper(), stage: CoreStage.last);
  /// ```
  App addSystem(System system, {CoreStage stage = CoreStage.update}) {
    schedule.addSystem(system, stage: stage);
    return this;
  }

  /// Adds multiple systems to the schedule.
  ///
  /// All systems are added to the same stage.
  ///
  /// ```dart
  /// app.addSystems([
  ///   MovementSystemWrapper(),
  ///   PhysicsSystemWrapper(),
  /// ], stage: CoreStage.update);
  /// ```
  App addSystems(List<System> systems, {CoreStage stage = CoreStage.update}) {
    for (final system in systems) {
      schedule.addSystem(system, stage: stage);
    }
    return this;
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
  /// ```dart
  /// app
  ///   .configureSet('physics', (s) => s.after('input'))
  ///   .addSystemToSet(gravitySystem, 'physics')
  ///   .addSystemToSet(collisionSystem, 'physics');
  /// ```
  App addSystemToSet(
    System system,
    String setName, {
    CoreStage stage = CoreStage.update,
  }) {
    final set = _systemSets.getOrCreate(setName);
    final wrappedSystem = SetConfiguredSystem(system, set);
    schedule.addSystem(wrappedSystem, stage: stage);
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
  /// Useful for testing or manual control of the game loop.
  ///
  /// ```dart
  /// await app.tick();
  /// ```
  Future<void> tick() async {
    // Update event queues (swap buffers)
    world.updateEvents();

    // Run all systems
    await schedule.run(world);

    // Call tick callback
    _onTick?.call(this);

    // Advance tick counter for change detection
    world.advanceTick();

    // Apply state transitions for next frame
    _applyStateTransitions();
  }

  /// Applies all pending state transitions.
  void _applyStateTransitions() {
    _states.applyTransitions();
  }

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
  ///   ..addPlugin(TimePlugin())
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

    // 2. Clear all systems from the schedule
    schedule.clear();

    // 3. Rebuild systems from session plugins
    // Copy the list to avoid concurrent modification if build() adds plugins
    final sessionPlugins = _plugins.toList();
    for (final plugin in sessionPlugins) {
      plugin.build(this);
    }

    // 4. Reset world game state
    world.resetGameState();
  }

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
