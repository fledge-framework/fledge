import 'run_condition.dart';
import 'system.dart';

/// Configuration for a group of systems.
///
/// System sets allow grouping related systems together and applying
/// shared configuration like ordering constraints and run conditions.
///
/// A system belongs to a set when its [SystemMeta.sets] contains the set's
/// [name] — either declared directly (`FunctionSystem(..., sets: [...])`)
/// or via `App.addSystemToSet`, which wraps the system in a
/// [SetConfiguredSystem]. The scheduler treats a set name like a system
/// name in every `before:` / `after:` reference: it resolves to every
/// member system (plus any system literally named the same). Set-to-set
/// edges are transitive through sets, so an empty set still bridges a
/// chain such as `A before B`, `B before C`.
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

  /// Systems or sets that this set runs after.
  final List<String> _after = [];

  /// Systems or sets that this set runs before.
  final List<String> _before = [];

  /// Run condition applied to all systems in this set.
  RunCondition? _runCondition;

  /// Creates a system set with the given name.
  SystemSet(this.name);

  /// Configures this set to run after the given system or set.
  ///
  /// Every member of this set runs after every system named [name] and
  /// every member of the set named [name]. Repeated calls with the same
  /// name are ignored.
  ///
  /// Returns this set for method chaining.
  ///
  /// ```dart
  /// app.configureSet('physics', (s) => s.after('input'));
  /// ```
  SystemSet after(String name) {
    if (!_after.contains(name)) _after.add(name);
    return this;
  }

  /// Configures this set to run before the given system or set.
  ///
  /// Every member of this set runs before every system named [name] and
  /// every member of the set named [name]. Repeated calls with the same
  /// name are ignored.
  ///
  /// Returns this set for method chaining.
  ///
  /// ```dart
  /// app.configureSet('physics', (s) => s.before('render'));
  /// ```
  SystemSet before(String name) {
    if (!_before.contains(name)) _before.add(name);
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

  /// The systems / sets this set runs after.
  List<String> get afterList => List.unmodifiable(_after);

  /// The systems / sets this set runs before.
  List<String> get beforeList => List.unmodifiable(_before);

  /// Gets the run condition for this set.
  RunCondition? get runCondition => _runCondition;
}

/// Registry for managing system sets.
///
/// Owned by the `Scheduler` (see `Scheduler.sets`), which consults it
/// when building each schedule's dependency graph. `App.configureSet`
/// delegates to `Scheduler.configureSet`.
class SystemSetRegistry {
  final Map<String, SystemSet> _sets = {};

  /// Every configured set, in creation order.
  Iterable<SystemSet> get all => _sets.values;

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
/// This wraps a system to record membership of its set (appended to
/// [SystemMeta.sets]) and to apply the set's run condition. Ordering is
/// resolved by the scheduler from the set registry, so set constraints
/// configured *after* the system was added are honoured too.
///
/// For backwards compatibility the set's `before` / `after` lists at
/// construction time are also copied into the wrapped meta; the
/// resulting edges duplicate the registry-derived ones and are harmless.
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
        // Combine set ordering with system's own ordering. Kept for one
        // release; the scheduler now derives set edges from membership.
        before: [..._set.beforeList, ..._inner.meta.before],
        after: [..._set.afterList, ..._inner.meta.after],
        sets: [_set.name, ..._inner.meta.sets],
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
