import '../archetype/archetypes.dart';
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
class QueryIter1<T1> extends Iterable<(Entity, T1)> {
  final Archetypes _archetypes;
  final QueryState _state;

  QueryIter1(this._archetypes, this._state) {
    _state.updateCache(_archetypes);
  }

  @override
  Iterator<(Entity, T1)> get iterator => _QueryIterator1(
        _archetypes,
        _state,
      );
}

class _QueryIterator1<T1> implements Iterator<(Entity, T1)> {
  final Archetypes _archetypes;
  final QueryState _state;

  int _archetypeIndex = 0;
  int _row = -1;
  Table? _currentTable;
  List<dynamic>? _column;

  (Entity, T1)? _current;

  _QueryIterator1(this._archetypes, this._state);

  @override
  (Entity, T1) get current => _current!;

  @override
  bool moveNext() {
    final archetypeIndices = _state.matchingArchetypes;
    final componentId = _state.fetchComponents[0];

    while (true) {
      // Try to advance within current table
      if (_currentTable != null) {
        _row++;
        if (_row < _currentTable!.length) {
          // Check change filters
          if (!_state.passesChangeFilters(_currentTable!, _row)) {
            continue;
          }
          _current = (
            _currentTable!.entityAt(_row),
            _column![_row] as T1,
          );
          return true;
        }
      }

      // Move to next archetype
      if (_archetypeIndex >= archetypeIndices.length) {
        _current = null;
        return false;
      }

      _currentTable = _archetypes.tableAt(archetypeIndices[_archetypeIndex]);
      _column = _currentTable!.getColumn(componentId);
      _archetypeIndex++;
      _row = -1;
    }
  }
}

/// Iterator over query results for two components.
class QueryIter2<T1, T2> extends Iterable<(Entity, T1, T2)> {
  final Archetypes _archetypes;
  final QueryState _state;

  QueryIter2(this._archetypes, this._state) {
    _state.updateCache(_archetypes);
  }

  @override
  Iterator<(Entity, T1, T2)> get iterator => _QueryIterator2(
        _archetypes,
        _state,
      );
}

class _QueryIterator2<T1, T2> implements Iterator<(Entity, T1, T2)> {
  final Archetypes _archetypes;
  final QueryState _state;

  int _archetypeIndex = 0;
  int _row = -1;
  Table? _currentTable;
  List<dynamic>? _column1;
  List<dynamic>? _column2;

  (Entity, T1, T2)? _current;

  _QueryIterator2(this._archetypes, this._state);

  @override
  (Entity, T1, T2) get current => _current!;

  @override
  bool moveNext() {
    final archetypeIndices = _state.matchingArchetypes;
    final componentId1 = _state.fetchComponents[0];
    final componentId2 = _state.fetchComponents[1];

    while (true) {
      if (_currentTable != null) {
        _row++;
        if (_row < _currentTable!.length) {
          // Check change filters
          if (!_state.passesChangeFilters(_currentTable!, _row)) {
            continue;
          }
          _current = (
            _currentTable!.entityAt(_row),
            _column1![_row] as T1,
            _column2![_row] as T2,
          );
          return true;
        }
      }

      if (_archetypeIndex >= archetypeIndices.length) {
        _current = null;
        return false;
      }

      _currentTable = _archetypes.tableAt(archetypeIndices[_archetypeIndex]);
      _column1 = _currentTable!.getColumn(componentId1);
      _column2 = _currentTable!.getColumn(componentId2);
      _archetypeIndex++;
      _row = -1;
    }
  }
}

/// Iterator over query results for three components.
class QueryIter3<T1, T2, T3> extends Iterable<(Entity, T1, T2, T3)> {
  final Archetypes _archetypes;
  final QueryState _state;

  QueryIter3(this._archetypes, this._state) {
    _state.updateCache(_archetypes);
  }

  @override
  Iterator<(Entity, T1, T2, T3)> get iterator => _QueryIterator3(
        _archetypes,
        _state,
      );
}

class _QueryIterator3<T1, T2, T3> implements Iterator<(Entity, T1, T2, T3)> {
  final Archetypes _archetypes;
  final QueryState _state;

  int _archetypeIndex = 0;
  int _row = -1;
  Table? _currentTable;
  List<dynamic>? _column1;
  List<dynamic>? _column2;
  List<dynamic>? _column3;

  (Entity, T1, T2, T3)? _current;

  _QueryIterator3(this._archetypes, this._state);

  @override
  (Entity, T1, T2, T3) get current => _current!;

  @override
  bool moveNext() {
    final archetypeIndices = _state.matchingArchetypes;
    final componentId1 = _state.fetchComponents[0];
    final componentId2 = _state.fetchComponents[1];
    final componentId3 = _state.fetchComponents[2];

    while (true) {
      if (_currentTable != null) {
        _row++;
        if (_row < _currentTable!.length) {
          // Check change filters
          if (!_state.passesChangeFilters(_currentTable!, _row)) {
            continue;
          }
          _current = (
            _currentTable!.entityAt(_row),
            _column1![_row] as T1,
            _column2![_row] as T2,
            _column3![_row] as T3,
          );
          return true;
        }
      }

      if (_archetypeIndex >= archetypeIndices.length) {
        _current = null;
        return false;
      }

      _currentTable = _archetypes.tableAt(archetypeIndices[_archetypeIndex]);
      _column1 = _currentTable!.getColumn(componentId1);
      _column2 = _currentTable!.getColumn(componentId2);
      _column3 = _currentTable!.getColumn(componentId3);
      _archetypeIndex++;
      _row = -1;
    }
  }
}

/// Iterator over query results for four components.
class QueryIter4<T1, T2, T3, T4> extends Iterable<(Entity, T1, T2, T3, T4)> {
  final Archetypes _archetypes;
  final QueryState _state;

  QueryIter4(this._archetypes, this._state) {
    _state.updateCache(_archetypes);
  }

  @override
  Iterator<(Entity, T1, T2, T3, T4)> get iterator => _QueryIterator4(
        _archetypes,
        _state,
      );
}

class _QueryIterator4<T1, T2, T3, T4>
    implements Iterator<(Entity, T1, T2, T3, T4)> {
  final Archetypes _archetypes;
  final QueryState _state;

  int _archetypeIndex = 0;
  int _row = -1;
  Table? _currentTable;
  List<dynamic>? _column1;
  List<dynamic>? _column2;
  List<dynamic>? _column3;
  List<dynamic>? _column4;

  (Entity, T1, T2, T3, T4)? _current;

  _QueryIterator4(this._archetypes, this._state);

  @override
  (Entity, T1, T2, T3, T4) get current => _current!;

  @override
  bool moveNext() {
    final archetypeIndices = _state.matchingArchetypes;
    final componentId1 = _state.fetchComponents[0];
    final componentId2 = _state.fetchComponents[1];
    final componentId3 = _state.fetchComponents[2];
    final componentId4 = _state.fetchComponents[3];

    while (true) {
      if (_currentTable != null) {
        _row++;
        if (_row < _currentTable!.length) {
          // Check change filters
          if (!_state.passesChangeFilters(_currentTable!, _row)) {
            continue;
          }
          _current = (
            _currentTable!.entityAt(_row),
            _column1![_row] as T1,
            _column2![_row] as T2,
            _column3![_row] as T3,
            _column4![_row] as T4,
          );
          return true;
        }
      }

      if (_archetypeIndex >= archetypeIndices.length) {
        _current = null;
        return false;
      }

      _currentTable = _archetypes.tableAt(archetypeIndices[_archetypeIndex]);
      _column1 = _currentTable!.getColumn(componentId1);
      _column2 = _currentTable!.getColumn(componentId2);
      _column3 = _currentTable!.getColumn(componentId3);
      _column4 = _currentTable!.getColumn(componentId4);
      _archetypeIndex++;
      _row = -1;
    }
  }
}
