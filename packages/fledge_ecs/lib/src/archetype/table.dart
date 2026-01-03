import '../change_detection/tick.dart';
import '../component.dart';
import '../entity.dart';
import 'archetype_id.dart';

/// Dense storage for entities with the same archetype.
///
/// A table stores component data in a column-oriented layout for cache-efficient
/// iteration. Each column stores all instances of a single component type.
///
/// ## Memory Layout
///
/// ```
/// Row | Entity   | Position | Velocity | Sprite
/// ----|----------|----------|----------|--------
///  0  | (0, 1)   | (0, 0)   | (1, 1)   | ...
///  1  | (3, 1)   | (5, 5)   | (0, -1)  | ...
///  2  | (7, 2)   | (10, 0)  | (2, 0)   | ...
/// ```
///
/// All columns have the same length. Entities at the same row index
/// share their component data across columns.
class Table {
  /// The archetype this table stores.
  final ArchetypeId archetypeId;

  /// The entities stored in this table, indexed by row.
  final List<Entity> _entities = [];

  /// Component columns, keyed by ComponentId.
  final Map<ComponentId, List<dynamic>> _columns = {};

  /// Component tick tracking for change detection, keyed by ComponentId.
  /// Each list is parallel to the corresponding column in [_columns].
  final Map<ComponentId, List<ComponentTicks>> _ticks = {};

  /// Creates a table for the given [archetypeId].
  Table(this.archetypeId) {
    // Initialize empty columns and tick tracking for each component type
    for (final componentId in archetypeId.components) {
      _columns[componentId] = [];
      _ticks[componentId] = [];
    }
  }

  /// The number of entities in this table.
  int get length => _entities.length;

  /// Returns true if the table has no entities.
  bool get isEmpty => _entities.isEmpty;

  /// Returns true if the table has at least one entity.
  bool get isNotEmpty => _entities.isNotEmpty;

  /// Returns the entity at the given [row].
  Entity entityAt(int row) => _entities[row];

  /// Returns an iterable of all entities in this table.
  Iterable<Entity> get entities => _entities;

  /// Adds an entity with its components to this table.
  ///
  /// Returns the row index where the entity was inserted.
  ///
  /// The [components] map must contain a value for every component type
  /// in this table's archetype.
  ///
  /// If [currentTick] is provided, it's used to initialize change detection
  /// ticks for the new components. If [existingTicks] is provided, those
  /// ticks are used instead (for archetype migrations).
  int add(
    Entity entity,
    Map<ComponentId, dynamic> components, {
    int currentTick = 0,
    Map<ComponentId, ComponentTicks>? existingTicks,
  }) {
    assert(
      archetypeId.components.every((id) => components.containsKey(id)),
      'Missing components for archetype',
    );

    final row = _entities.length;
    _entities.add(entity);

    for (final componentId in archetypeId.components) {
      _columns[componentId]!.add(components[componentId]);

      // Use existing ticks if migrating, otherwise create new
      final ticks =
          existingTicks?[componentId] ?? ComponentTicks.added(currentTick);
      _ticks[componentId]!.add(ticks);
    }

    return row;
  }

  /// Removes the entity at the given [row] using swap-remove.
  ///
  /// The last entity in the table is moved to fill the gap.
  /// Returns the entity that was moved (now at [row]), or null if [row]
  /// was the last row.
  ///
  /// The caller is responsible for updating entity locations.
  Entity? swapRemove(int row) {
    assert(row >= 0 && row < length, 'Row $row out of bounds');

    final lastRow = length - 1;

    if (row == lastRow) {
      // Removing the last row, no swap needed
      _entities.removeLast();
      for (final column in _columns.values) {
        column.removeLast();
      }
      for (final tickColumn in _ticks.values) {
        tickColumn.removeLast();
      }
      return null;
    }

    // Swap with last row
    final movedEntity = _entities[lastRow];
    _entities[row] = movedEntity;
    _entities.removeLast();

    for (final column in _columns.values) {
      column[row] = column[lastRow];
      column.removeLast();
    }

    for (final tickColumn in _ticks.values) {
      tickColumn[row] = tickColumn[lastRow];
      tickColumn.removeLast();
    }

    return movedEntity;
  }

  /// Gets the component of type [componentId] for the entity at [row].
  ///
  /// Returns null if the component type is not in this archetype.
  T? getComponent<T>(int row, ComponentId componentId) {
    final column = _columns[componentId];
    if (column == null) return null;
    return column[row] as T;
  }

  /// Gets the component column for the given [componentId].
  ///
  /// Returns null if the component type is not in this archetype.
  /// The returned list contains components of type T but is typed as
  /// List<dynamic> for performance. Callers should cast elements as needed.
  List<dynamic>? getColumn(ComponentId componentId) {
    return _columns[componentId];
  }

  /// Sets the component of type [componentId] for the entity at [row].
  ///
  /// If [currentTick] is provided, the component's change tick is updated
  /// to enable change detection via [Changed<T>] queries.
  void setComponent<T>(int row, ComponentId componentId, T value,
      {int? currentTick}) {
    final column = _columns[componentId];
    if (column == null) {
      throw ArgumentError('Component $componentId not in archetype');
    }
    column[row] = value;

    // Update change tick if provided
    if (currentTick != null) {
      _ticks[componentId]?[row].markChanged(currentTick);
    }
  }

  /// Gets the component ticks for [componentId] at [row].
  ///
  /// Returns null if the component type is not in this archetype.
  ComponentTicks? getTicks(int row, ComponentId componentId) {
    return _ticks[componentId]?[row];
  }

  /// Gets the ticks column for the given [componentId].
  ///
  /// Returns null if the component type is not in this archetype.
  List<ComponentTicks>? getTicksColumn(ComponentId componentId) {
    return _ticks[componentId];
  }

  /// Extracts all components for the entity at [row].
  ///
  /// This is used when moving an entity between tables.
  Map<ComponentId, dynamic> extractRow(int row) {
    return {
      for (final entry in _columns.entries) entry.key: entry.value[row],
    };
  }

  /// Extracts all component ticks for the entity at [row].
  ///
  /// This is used when moving an entity between tables to preserve
  /// change detection state.
  Map<ComponentId, ComponentTicks> extractTicks(int row) {
    return {
      for (final entry in _ticks.entries) entry.key: entry.value[row],
    };
  }

  /// Clears all entities from this table.
  void clear() {
    _entities.clear();
    for (final column in _columns.values) {
      column.clear();
    }
    for (final tickColumn in _ticks.values) {
      tickColumn.clear();
    }
  }

  @override
  String toString() => 'Table($archetypeId, length: $length)';
}
