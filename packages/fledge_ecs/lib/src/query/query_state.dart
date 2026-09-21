import '../archetype/archetypes.dart';
import '../archetype/entities.dart';
import '../archetype/table.dart';
import '../component.dart';
import '../entity.dart';
import 'filter.dart';

/// Cached state for a query.
///
/// [QueryState] tracks which archetypes match the query's component
/// requirements and filters. It's created once and reused across
/// multiple query iterations.
///
/// ## Cache Lifecycle
///
/// The cache is automatically updated when:
/// - The query is first created
/// - The number of archetypes in the world changes
///
/// The cache is invalidated by calling [invalidate], which forces a
/// refresh on the next query iteration.
///
/// **Note**: The cache only checks archetype count, not structure changes.
/// If an archetype's component set changes (rare), call [invalidate] manually.
///
/// ## Change Detection
///
/// For queries with [Added] or [Changed] filters, [lastSeenTick] tracks
/// when the query last ran. Call [updateLastSeenTick] after iterating
/// to mark changes as "seen" for subsequent iterations.
class QueryState {
  /// Component IDs that must be fetched (the query's data components).
  final List<ComponentId> fetchComponents;

  /// Component IDs that must be present (from With filters).
  final Set<ComponentId> requiredComponents;

  /// Component IDs that must be absent (from Without filters).
  final Set<ComponentId> excludedComponents;

  /// Component IDs that must have been added recently (from Added filters).
  final Set<ComponentId> addedComponents;

  /// Component IDs that must have been changed recently (from Changed filters).
  final Set<ComponentId> changedComponents;

  /// The tick when this query last ran, used for change detection.
  int lastSeenTick = 0;

  /// Cached list of matching archetype indices.
  List<int>? _matchingArchetypes;

  /// The archetype count when cache was last updated.
  int _cachedArchetypeCount = 0;

  QueryState({
    required this.fetchComponents,
    this.requiredComponents = const {},
    this.excludedComponents = const {},
    this.addedComponents = const {},
    this.changedComponents = const {},
  });

  /// Returns true if this query has any change detection filters.
  bool get hasChangeFilters =>
      addedComponents.isNotEmpty || changedComponents.isNotEmpty;

  /// Creates a QueryState for fetching components of types [T1].
  static QueryState of1<T1>({QueryFilter? filter}) {
    return QueryState(
      fetchComponents: [ComponentId.of<T1>()],
      requiredComponents: filter?.required ?? const {},
      excludedComponents: filter?.excluded ?? const {},
      addedComponents: _extractAdded(filter),
      changedComponents: _extractChanged(filter),
    );
  }

  /// Creates a QueryState for fetching components of types [T1], [T2].
  static QueryState of2<T1, T2>({QueryFilter? filter}) {
    return QueryState(
      fetchComponents: [ComponentId.of<T1>(), ComponentId.of<T2>()],
      requiredComponents: filter?.required ?? const {},
      excludedComponents: filter?.excluded ?? const {},
      addedComponents: _extractAdded(filter),
      changedComponents: _extractChanged(filter),
    );
  }

  /// Creates a QueryState for fetching components of types [T1], [T2], [T3].
  static QueryState of3<T1, T2, T3>({QueryFilter? filter}) {
    return QueryState(
      fetchComponents: [
        ComponentId.of<T1>(),
        ComponentId.of<T2>(),
        ComponentId.of<T3>(),
      ],
      requiredComponents: filter?.required ?? const {},
      excludedComponents: filter?.excluded ?? const {},
      addedComponents: _extractAdded(filter),
      changedComponents: _extractChanged(filter),
    );
  }

  /// Creates a QueryState for fetching components of types [T1], [T2], [T3], [T4].
  static QueryState of4<T1, T2, T3, T4>({QueryFilter? filter}) {
    return QueryState(
      fetchComponents: [
        ComponentId.of<T1>(),
        ComponentId.of<T2>(),
        ComponentId.of<T3>(),
        ComponentId.of<T4>(),
      ],
      requiredComponents: filter?.required ?? const {},
      excludedComponents: filter?.excluded ?? const {},
      addedComponents: _extractAdded(filter),
      changedComponents: _extractChanged(filter),
    );
  }

  /// Extracts Added filter component IDs from a filter.
  static Set<ComponentId> _extractAdded(QueryFilter? filter) {
    if (filter == null) return const {};
    if (filter is Added) return {filter.componentId};
    if (filter is And) {
      return filter.filters
          .whereType<Added>()
          .map((f) => f.componentId)
          .toSet();
    }
    return const {};
  }

  /// Extracts Changed filter component IDs from a filter.
  static Set<ComponentId> _extractChanged(QueryFilter? filter) {
    if (filter == null) return const {};
    if (filter is Changed) return {filter.componentId};
    if (filter is And) {
      return filter.filters
          .whereType<Changed>()
          .map((f) => f.componentId)
          .toSet();
    }
    return const {};
  }

  /// All component IDs that must be present (fetch + required).
  Set<ComponentId> get allRequired {
    return {...fetchComponents, ...requiredComponents};
  }

  /// Updates the cached archetype list if needed.
  void updateCache(Archetypes archetypes) {
    if (_matchingArchetypes != null &&
        _cachedArchetypeCount == archetypes.length) {
      return;
    }

    _matchingArchetypes = archetypes
        .matching(required: allRequired, excluded: excludedComponents)
        .toList();
    _cachedArchetypeCount = archetypes.length;
  }

  /// Returns the matching archetype indices.
  ///
  /// Call [updateCache] first to ensure the cache is current.
  List<int> get matchingArchetypes => _matchingArchetypes ?? const [];

  /// Invalidates the cache, forcing a refresh on next access.
  void invalidate() {
    _matchingArchetypes = null;
    _cachedArchetypeCount = 0;
  }

  /// Updates the lastSeenTick to the given tick value.
  ///
  /// This should be called after iterating a query with change detection
  /// filters to mark that the query has "seen" all changes up to this tick.
  void updateLastSeenTick(int tick) {
    lastSeenTick = tick;
  }

  /// Snapshots the current set of entities matching this query.
  ///
  /// This is called at iterator construction time so that mid-iteration
  /// archetype migrations (adds/removes/despawns) do not silently drop
  /// entities from the iterator's view. See `iter()` on [QueryIter1] et al.
  /// for the correctness rationale.
  ///
  /// The snapshot is deliberately shallow: it captures which entities were
  /// eligible at the moment iteration began. Each yield still resolves the
  /// entity's *current* archetype/row and re-validates that it matches the
  /// query — an entity that was moved out of the query's match set (e.g.
  /// via component removal) is skipped rather than yielded with stale data.
  List<Entity> snapshotEntities(Archetypes archetypes) {
    updateCache(archetypes);
    final matching = matchingArchetypes;
    // Pre-size where possible to avoid repeated growth.
    int total = 0;
    for (final archetypeIndex in matching) {
      total += archetypes.tableAt(archetypeIndex).length;
    }
    final result = List<Entity>.filled(total, Entity.placeholder);
    int i = 0;
    for (final archetypeIndex in matching) {
      final table = archetypes.tableAt(archetypeIndex);
      final entities = table.entities;
      for (final entity in entities) {
        result[i++] = entity;
      }
    }
    return result;
  }

  /// Returns true if [table]'s archetype still satisfies this query's
  /// component requirements (fetch + required present, excluded absent).
  ///
  /// Used by iterators to skip entities that have migrated out of the
  /// query's match set since iteration began.
  bool tableMatches(Table table) {
    final archetypeId = table.archetypeId;
    for (final id in fetchComponents) {
      if (!archetypeId.contains(id)) return false;
    }
    for (final id in requiredComponents) {
      if (!archetypeId.contains(id)) return false;
    }
    for (final id in excludedComponents) {
      if (archetypeId.contains(id)) return false;
    }
    return true;
  }

  /// Checks if a row passes the change detection filters.
  ///
  /// Used by query iterators to filter results based on Added/Changed filters.
  bool passesChangeFilters(Table table, int row) {
    // Check Added filters
    for (final componentId in addedComponents) {
      final ticks = table.getTicks(row, componentId);
      if (ticks == null || !ticks.isAdded(lastSeenTick)) {
        return false;
      }
    }

    // Check Changed filters
    for (final componentId in changedComponents) {
      final ticks = table.getTicks(row, componentId);
      if (ticks == null || !ticks.isChanged(lastSeenTick)) {
        return false;
      }
    }

    return true;
  }
}

/// Iterator over query results for a single component.
///
/// ## Snapshot semantics
///
/// [QueryIter1] takes a snapshot of the entities that match the query at
/// iterator-construction time. This guarantees that mid-iteration mutations
/// — inserting a component (which migrates the entity to a new archetype),
/// removing a component, or despawning the entity — do not silently drop
/// still-matching entities from the yielded sequence. Each `moveNext`
/// re-resolves the entity's current archetype/row from [Entities] and
/// re-validates that it still matches the query; entities that no longer
/// match are skipped rather than yielded with stale data.
///
/// Cost: one `List<Entity>` allocation sized to the total row count of
/// matching archetypes, plus one entity-location lookup per yield.
class QueryIter1<T1> extends Iterable<(Entity, T1)> {
  final Archetypes _archetypes;
  final Entities _entities;
  final QueryState _state;
  final List<Entity> _snapshot;

  QueryIter1(this._archetypes, this._entities, this._state)
    : _snapshot = _state.snapshotEntities(_archetypes);

  @override
  Iterator<(Entity, T1)> get iterator =>
      _QueryIterator1(_archetypes, _entities, _state, _snapshot);
}

class _QueryIterator1<T1> implements Iterator<(Entity, T1)> {
  final Archetypes _archetypes;
  final Entities _entities;
  final QueryState _state;
  final List<Entity> _snapshot;

  int _index = 0;

  (Entity, T1)? _current;

  _QueryIterator1(
    this._archetypes,
    this._entities,
    this._state,
    this._snapshot,
  );

  @override
  (Entity, T1) get current => _current!;

  @override
  bool moveNext() {
    final componentId = _state.fetchComponents[0];

    while (_index < _snapshot.length) {
      final entity = _snapshot[_index++];
      final location = _entities.getLocation(entity);
      if (location == null) continue; // Despawned mid-iter.

      final table = _archetypes.tableAt(location.archetypeIndex);
      if (!_state.tableMatches(table)) continue; // Migrated out of match set.
      if (!_state.passesChangeFilters(table, location.row)) continue;

      final column = table.getColumn(componentId);
      _current = (entity, column![location.row] as T1);
      return true;
    }

    _current = null;
    return false;
  }
}

/// Iterator over query results for two components.
///
/// See [QueryIter1] for the snapshot semantics that guard against
/// mid-iteration archetype mutations.
class QueryIter2<T1, T2> extends Iterable<(Entity, T1, T2)> {
  final Archetypes _archetypes;
  final Entities _entities;
  final QueryState _state;
  final List<Entity> _snapshot;

  QueryIter2(this._archetypes, this._entities, this._state)
    : _snapshot = _state.snapshotEntities(_archetypes);

  @override
  Iterator<(Entity, T1, T2)> get iterator =>
      _QueryIterator2(_archetypes, _entities, _state, _snapshot);
}

class _QueryIterator2<T1, T2> implements Iterator<(Entity, T1, T2)> {
  final Archetypes _archetypes;
  final Entities _entities;
  final QueryState _state;
  final List<Entity> _snapshot;

  int _index = 0;

  (Entity, T1, T2)? _current;

  _QueryIterator2(
    this._archetypes,
    this._entities,
    this._state,
    this._snapshot,
  );

  @override
  (Entity, T1, T2) get current => _current!;

  @override
  bool moveNext() {
    final componentId1 = _state.fetchComponents[0];
    final componentId2 = _state.fetchComponents[1];

    while (_index < _snapshot.length) {
      final entity = _snapshot[_index++];
      final location = _entities.getLocation(entity);
      if (location == null) continue;

      final table = _archetypes.tableAt(location.archetypeIndex);
      if (!_state.tableMatches(table)) continue;
      if (!_state.passesChangeFilters(table, location.row)) continue;

      final column1 = table.getColumn(componentId1);
      final column2 = table.getColumn(componentId2);
      final row = location.row;
      _current = (entity, column1![row] as T1, column2![row] as T2);
      return true;
    }

    _current = null;
    return false;
  }
}

/// Iterator over query results for three components.
///
/// See [QueryIter1] for the snapshot semantics that guard against
/// mid-iteration archetype mutations.
class QueryIter3<T1, T2, T3> extends Iterable<(Entity, T1, T2, T3)> {
  final Archetypes _archetypes;
  final Entities _entities;
  final QueryState _state;
  final List<Entity> _snapshot;

  QueryIter3(this._archetypes, this._entities, this._state)
    : _snapshot = _state.snapshotEntities(_archetypes);

  @override
  Iterator<(Entity, T1, T2, T3)> get iterator =>
      _QueryIterator3(_archetypes, _entities, _state, _snapshot);
}

class _QueryIterator3<T1, T2, T3> implements Iterator<(Entity, T1, T2, T3)> {
  final Archetypes _archetypes;
  final Entities _entities;
  final QueryState _state;
  final List<Entity> _snapshot;

  int _index = 0;

  (Entity, T1, T2, T3)? _current;

  _QueryIterator3(
    this._archetypes,
    this._entities,
    this._state,
    this._snapshot,
  );

  @override
  (Entity, T1, T2, T3) get current => _current!;

  @override
  bool moveNext() {
    final componentId1 = _state.fetchComponents[0];
    final componentId2 = _state.fetchComponents[1];
    final componentId3 = _state.fetchComponents[2];

    while (_index < _snapshot.length) {
      final entity = _snapshot[_index++];
      final location = _entities.getLocation(entity);
      if (location == null) continue;

      final table = _archetypes.tableAt(location.archetypeIndex);
      if (!_state.tableMatches(table)) continue;
      if (!_state.passesChangeFilters(table, location.row)) continue;

      final column1 = table.getColumn(componentId1);
      final column2 = table.getColumn(componentId2);
      final column3 = table.getColumn(componentId3);
      final row = location.row;
      _current = (
        entity,
        column1![row] as T1,
        column2![row] as T2,
        column3![row] as T3,
      );
      return true;
    }

    _current = null;
    return false;
  }
}

/// Iterator over query results for four components.
///
/// See [QueryIter1] for the snapshot semantics that guard against
/// mid-iteration archetype mutations.
class QueryIter4<T1, T2, T3, T4> extends Iterable<(Entity, T1, T2, T3, T4)> {
  final Archetypes _archetypes;
  final Entities _entities;
  final QueryState _state;
  final List<Entity> _snapshot;

  QueryIter4(this._archetypes, this._entities, this._state)
    : _snapshot = _state.snapshotEntities(_archetypes);

  @override
  Iterator<(Entity, T1, T2, T3, T4)> get iterator =>
      _QueryIterator4(_archetypes, _entities, _state, _snapshot);
}

class _QueryIterator4<T1, T2, T3, T4>
    implements Iterator<(Entity, T1, T2, T3, T4)> {
  final Archetypes _archetypes;
  final Entities _entities;
  final QueryState _state;
  final List<Entity> _snapshot;

  int _index = 0;

  (Entity, T1, T2, T3, T4)? _current;

  _QueryIterator4(
    this._archetypes,
    this._entities,
    this._state,
    this._snapshot,
  );

  @override
  (Entity, T1, T2, T3, T4) get current => _current!;

  @override
  bool moveNext() {
    final componentId1 = _state.fetchComponents[0];
    final componentId2 = _state.fetchComponents[1];
    final componentId3 = _state.fetchComponents[2];
    final componentId4 = _state.fetchComponents[3];

    while (_index < _snapshot.length) {
      final entity = _snapshot[_index++];
      final location = _entities.getLocation(entity);
      if (location == null) continue;

      final table = _archetypes.tableAt(location.archetypeIndex);
      if (!_state.tableMatches(table)) continue;
      if (!_state.passesChangeFilters(table, location.row)) continue;

      final column1 = table.getColumn(componentId1);
      final column2 = table.getColumn(componentId2);
      final column3 = table.getColumn(componentId3);
      final column4 = table.getColumn(componentId4);
      final row = location.row;
      _current = (
        entity,
        column1![row] as T1,
        column2![row] as T2,
        column3![row] as T3,
        column4![row] as T4,
      );
      return true;
    }

    _current = null;
    return false;
  }
}
