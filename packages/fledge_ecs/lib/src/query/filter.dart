import '../component.dart';

/// Base class for query filters.
///
/// Filters modify which entities are matched by a query.
sealed class QueryFilter {
  const QueryFilter();

  /// Gets the component IDs that must be present.
  Set<ComponentId> get required => const {};

  /// Gets the component IDs that must be absent.
  Set<ComponentId> get excluded => const {};
}

/// Filter that requires an entity to have component [T].
///
/// Use this when you need to filter by a component but don't
/// need to access its data.
///
/// ```dart
/// // Match entities with Position, Velocity, AND Player tag
/// Query<(Position, Velocity), With<Player>>
/// ```
class With<T> extends QueryFilter {
  const With();

  @override
  Set<ComponentId> get required => {ComponentId.of<T>()};
}

/// Filter that requires an entity to NOT have component [T].
///
/// ```dart
/// // Match entities with Position but NOT Static
/// Query<(Position,), Without<Static>>
/// ```
class Without<T> extends QueryFilter {
  const Without();

  @override
  Set<ComponentId> get excluded => {ComponentId.of<T>()};
}

/// Combines multiple filters with AND logic.
///
/// ```dart
/// // Position AND Velocity, WITH Player, WITHOUT Dead
/// Query<(Position, Velocity), And<(With<Player>, Without<Dead>)>>
/// ```
class And<T extends Record> extends QueryFilter {
  final List<QueryFilter> filters;

  const And(this.filters);

  @override
  Set<ComponentId> get required => filters.expand((f) => f.required).toSet();

  @override
  Set<ComponentId> get excluded => filters.expand((f) => f.excluded).toSet();
}

/// Marker for no filter.
class NoFilter extends QueryFilter {
  const NoFilter();
}

/// Filter for entities where component [T] was added recently.
///
/// Use this filter to query only entities that had the component
/// added since the last time this query ran.
///
/// ```dart
/// // Query for entities with newly added Health component
/// final query = world.query1<Health>(filter: Added<Health>());
/// for (final (entity, health) in query.iter()) {
///   // Initialize health bar UI
/// }
/// ```
class Added<T> extends QueryFilter {
  /// Creates a filter for recently added components of type [T].
  const Added();

  @override
  Set<ComponentId> get required => {ComponentId.of<T>()};

  /// The component ID being filtered.
  ComponentId get componentId => ComponentId.of<T>();

  @override
  String toString() => 'Added<$T>';
}

/// Filter for entities where component [T] was modified recently.
///
/// Use this filter to query only entities where the component
/// was changed since the last time this query ran.
///
/// ```dart
/// // Query for entities with modified Position
/// final query = world.query1<Position>(filter: Changed<Position>());
/// for (final (entity, pos) in query.iter()) {
///   // Update spatial index
/// }
/// ```
///
/// Note: A component is considered "changed" when:
/// - It was just added (added implies changed)
/// - It was modified via [World.insert] with a new value
/// - The component's ticks were manually marked as changed
class Changed<T> extends QueryFilter {
  /// Creates a filter for recently changed components of type [T].
  const Changed();

  @override
  Set<ComponentId> get required => {ComponentId.of<T>()};

  /// The component ID being filtered.
  ComponentId get componentId => ComponentId.of<T>();

  @override
  String toString() => 'Changed<$T>';
}
