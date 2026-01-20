import '../component.dart';
import 'archetype_id.dart';
import 'table.dart';

/// Manages all archetypes and their storage tables.
///
/// The [Archetypes] container is responsible for:
/// - Creating and caching archetype tables
/// - Providing efficient lookup of archetypes by their component set
/// - Tracking edges between archetypes for fast component add/remove
///
/// ## Archetype Graph
///
/// Archetypes form a graph where edges represent adding or removing
/// a single component. This allows O(1) archetype transitions.
///
/// ```
/// [Position] <--add Velocity--> [Position, Velocity]
///     ^                              ^
///     |                              |
///  add Sprite                    add Sprite
///     |                              |
///     v                              v
/// [Position, Sprite] <--add Velocity--> [Position, Velocity, Sprite]
/// ```
class Archetypes {
  /// All archetype tables, indexed for O(1) lookup.
  final List<Table> _tables = [];

  /// Maps archetype IDs to their table index.
  final Map<ArchetypeId, int> _archetypeIndex = {};

  /// Cached archetype transitions: (archetype, componentId) -> target archetype
  /// Used for fast add/remove component operations.
  final Map<_EdgeKey, int> _addEdges = {};
  final Map<_EdgeKey, int> _removeEdges = {};

  /// Creates an empty archetype container with the empty archetype.
  Archetypes() {
    // Always create the empty archetype at index 0
    _getOrCreate(ArchetypeId.empty());
  }

  /// The number of archetypes.
  int get length => _tables.length;

  /// Returns the table at the given [index].
  Table tableAt(int index) {
    if (index < 0 || index >= _tables.length) {
      throw RangeError(
        'Archetype index $index is out of range [0, ${_tables.length}). '
        'This may indicate a stale query cache.',
      );
    }
    return _tables[index];
  }

  /// Returns all tables.
  Iterable<Table> get tables => _tables;

  /// Gets or creates a table for the given [archetypeId].
  ///
  /// Returns the index of the table.
  int getOrCreate(ArchetypeId archetypeId) {
    return _archetypeIndex[archetypeId] ?? _getOrCreate(archetypeId);
  }

  /// Gets the table index for [archetypeId], or -1 if not found.
  int indexOf(ArchetypeId archetypeId) {
    return _archetypeIndex[archetypeId] ?? -1;
  }

  /// Gets the archetype index after adding [componentId] to [fromIndex].
  ///
  /// Uses cached edges for O(1) lookup after the first transition.
  int getAddTarget(int fromIndex, ComponentId componentId) {
    final key = _EdgeKey(fromIndex, componentId);
    final cached = _addEdges[key];
    if (cached != null) return cached;

    final fromArchetype = _tables[fromIndex].archetypeId;
    final toArchetype = fromArchetype.withComponent(componentId);
    final toIndex = getOrCreate(toArchetype);

    _addEdges[key] = toIndex;
    return toIndex;
  }

  /// Gets the archetype index after removing [componentId] from [fromIndex].
  ///
  /// Uses cached edges for O(1) lookup after the first transition.
  int getRemoveTarget(int fromIndex, ComponentId componentId) {
    final key = _EdgeKey(fromIndex, componentId);
    final cached = _removeEdges[key];
    if (cached != null) return cached;

    final fromArchetype = _tables[fromIndex].archetypeId;
    final toArchetype = fromArchetype.withoutComponent(componentId);
    final toIndex = getOrCreate(toArchetype);

    _removeEdges[key] = toIndex;
    return toIndex;
  }

  /// Returns all archetype indices that contain the given component.
  Iterable<int> withComponent(ComponentId componentId) sync* {
    for (int i = 0; i < _tables.length; i++) {
      if (_tables[i].archetypeId.contains(componentId)) {
        yield i;
      }
    }
  }

  /// Returns all archetype indices that contain all given components.
  Iterable<int> withAllComponents(Iterable<ComponentId> componentIds) sync* {
    final required = ArchetypeId.of(componentIds);
    for (int i = 0; i < _tables.length; i++) {
      if (_tables[i].archetypeId.containsAll(required)) {
        yield i;
      }
    }
  }

  /// Returns all archetype indices that contain all required components
  /// and none of the excluded components.
  Iterable<int> matching({
    required Iterable<ComponentId> required,
    Iterable<ComponentId>? excluded,
  }) sync* {
    final requiredArchetype = ArchetypeId.of(required);
    final excludedArchetype =
        excluded != null ? ArchetypeId.of(excluded) : null;

    for (int i = 0; i < _tables.length; i++) {
      final archetype = _tables[i].archetypeId;
      if (!archetype.containsAll(requiredArchetype)) continue;
      if (excludedArchetype != null &&
          archetype.containsAny(excludedArchetype)) {
        continue;
      }
      yield i;
    }
  }

  int _getOrCreate(ArchetypeId archetypeId) {
    final index = _tables.length;
    _tables.add(Table(archetypeId));
    _archetypeIndex[archetypeId] = index;
    return index;
  }

  /// Clears all archetypes except the empty archetype.
  void clear() {
    for (final table in _tables) {
      table.clear();
    }
  }
}

/// Key for archetype edge cache.
class _EdgeKey {
  final int archetypeIndex;
  final ComponentId componentId;

  _EdgeKey(this.archetypeIndex, this.componentId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _EdgeKey &&
          archetypeIndex == other.archetypeIndex &&
          componentId == other.componentId;

  @override
  int get hashCode => Object.hash(archetypeIndex, componentId);
}
