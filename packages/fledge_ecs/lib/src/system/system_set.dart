import 'run_condition.dart';
import 'system.dart';

/// Configuration for a group of systems.
///
/// System sets allow grouping related systems together and applying
/// shared configuration like ordering constraints and run conditions.
///
/// ```dart
/// App()
///   .configureSet('physics', (s) => s.after('input').before('render'))
///   .addSystemToSet(gravitySystem, 'physics')
///   .addSystemToSet(collisionSystem, 'physics');
/// ```
class SystemSet {
  /// The unique name of this set.
  final String name;

  /// Systems that this set runs after.
  final List<String> _after = [];

  /// Systems that this set runs before.
  final List<String> _before = [];

  /// Run condition applied to all systems in this set.
  RunCondition? _runCondition;

  /// Creates a system set with the given name.
  SystemSet(this.name);

  /// Configures this set to run after the given system or set.
  ///
  /// Returns this set for method chaining.
  ///
  /// ```dart
  /// app.configureSet('physics', (s) => s.after('input'));
  /// ```
  SystemSet after(String name) {
    _after.add(name);
    return this;
  }

  /// Configures this set to run before the given system or set.
  ///
  /// Returns this set for method chaining.
  ///
  /// ```dart
  /// app.configureSet('physics', (s) => s.before('render'));
  /// ```
  SystemSet before(String name) {
    _before.add(name);
    return this;
  }

  /// Adds a run condition that applies to all systems in this set.
  ///
  /// Returns this set for method chaining.
  ///
  /// ```dart
  /// app.configureSet('physics', (s) => s.runIf((world) => !world.isPaused));
  /// ```
  SystemSet runIf(RunCondition condition) {
    _runCondition = condition;
    return this;
  }

  /// Gets the combined list of systems to run after.
  List<String> get afterList => List.unmodifiable(_after);

  /// Gets the combined list of systems to run before.
  List<String> get beforeList => List.unmodifiable(_before);

  /// Gets the run condition for this set.
  RunCondition? get runCondition => _runCondition;
}

/// Registry for managing system sets.
///
/// This is used internally by the App to track set configurations.
class SystemSetRegistry {
  final Map<String, SystemSet> _sets = {};

  /// Configures a system set.
  ///
  /// If the set doesn't exist, it is created. The [configure] function
  /// is called with the set to allow fluent configuration.
  void configure(String name, void Function(SystemSet) configure) {
    final set = _sets.putIfAbsent(name, () => SystemSet(name));
    configure(set);
  }

  /// Gets a system set by name.
  ///
  /// Returns null if the set doesn't exist.
  SystemSet? get(String name) => _sets[name];

  /// Returns true if a set with the given name exists.
  bool contains(String name) => _sets.containsKey(name);

  /// Creates a set if it doesn't exist.
  SystemSet getOrCreate(String name) {
    return _sets.putIfAbsent(name, () => SystemSet(name));
  }
}

/// A system wrapper that applies set configuration.
///
/// This wraps a system to apply the ordering and run conditions
/// from its associated set.
class SetConfiguredSystem implements System {
  final System _inner;
  final SystemSet _set;
  final SystemMeta _meta;

  SetConfiguredSystem(this._inner, this._set)
      : _meta = SystemMeta(
          name: _inner.meta.name,
          reads: _inner.meta.reads,
          writes: _inner.meta.writes,
          resourceReads: _inner.meta.resourceReads,
          resourceWrites: _inner.meta.resourceWrites,
          eventReads: _inner.meta.eventReads,
          eventWrites: _inner.meta.eventWrites,
          exclusive: _inner.meta.exclusive,
          // Combine set ordering with system's own ordering
          before: [..._set.beforeList, ..._inner.meta.before],
          after: [..._set.afterList, ..._inner.meta.after],
        );

  @override
  SystemMeta get meta => _meta;

  @override
  RunCondition? get runCondition {
    final setCondition = _set.runCondition;
    final innerCondition = _inner.runCondition;

    if (setCondition == null) return innerCondition;
    if (innerCondition == null) return setCondition;

    // Combine both conditions with AND
    return (world) => setCondition(world) && innerCondition(world);
  }

  @override
  bool shouldRun(world) => runCondition?.call(world) ?? true;

  @override
  Future<void> run(world) => _inner.run(world);
}
