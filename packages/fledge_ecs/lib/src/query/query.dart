import '../archetype/archetypes.dart';
import '../entity.dart';
import 'filter.dart';
import 'query_state.dart';

export 'filter.dart';
export 'optional.dart';
export 'query_state.dart';

/// A query for iterating over entities with specific components.
///
/// Queries provide efficient iteration over all entities that have
/// a specific set of components. They cache which archetypes match
/// for fast repeated iteration.
///
/// ## Example
///
/// ```dart
/// // Query for entities with Position and Velocity
/// final query = world.query2<Position, Velocity>();
/// for (final (entity, pos, vel) in query.iter()) {
///   pos.x += vel.dx;
///   pos.y += vel.dy;
/// }
///
/// // Query with filter
/// final playerQuery = world.query1<Position>(filter: With<Player>());
/// ```
///
/// ## Optional Components
///
/// For optional component access, use `world.get<T>(entity)` inside the loop:
///
/// ```dart
/// for (final (entity, pos) in world.query1<Position>().iter()) {
///   final vel = world.get<Velocity>(entity); // May be null
///   if (vel != null) {
///     pos.x += vel.dx;
///   }
/// }
/// ```
///
/// ## Component Access
///
/// Components returned by queries are mutable references to the actual
/// stored data. Modifications are immediately visible.
abstract class Query {
  /// The cached query state.
  QueryState get state;
}

/// Query for a single component type.
class Query1<T1> implements Query {
  final Archetypes _archetypes;

  @override
  final QueryState state;

  Query1(this._archetypes, {QueryFilter? filter})
      : state = QueryState.of1<T1>(filter: filter);

  Query1.withState(this._archetypes, this.state);

  /// Returns an iterable over all matching entities and their components.
  Iterable<(Entity, T1)> iter() => QueryIter1<T1>(_archetypes, state);

  /// Returns the first matching entity, or null if none match.
  (Entity, T1)? single() {
    final iterator = iter().iterator;
    if (iterator.moveNext()) {
      return iterator.current;
    }
    return null;
  }

  /// Returns the number of matching entities.
  ///
  /// If the query has change detection filters, this iterates through
  /// all entities to check the filters.
  int count() {
    // If there are change filters, we need to iterate to check each row
    if (state.hasChangeFilters) {
      return iter().length;
    }

    state.updateCache(_archetypes);
    int total = 0;
    for (final archetypeIndex in state.matchingArchetypes) {
      total += _archetypes.tableAt(archetypeIndex).length;
    }
    return total;
  }

  /// Returns true if any entities match.
  bool get isNotEmpty => count() > 0;

  /// Returns true if no entities match.
  bool get isEmpty => count() == 0;
}

/// Query for two component types.
class Query2<T1, T2> implements Query {
  final Archetypes _archetypes;

  @override
  final QueryState state;

  Query2(this._archetypes, {QueryFilter? filter})
      : state = QueryState.of2<T1, T2>(filter: filter);

  Query2.withState(this._archetypes, this.state);

  /// Returns an iterable over all matching entities and their components.
  Iterable<(Entity, T1, T2)> iter() => QueryIter2<T1, T2>(_archetypes, state);

  /// Returns the first matching entity, or null if none match.
  (Entity, T1, T2)? single() {
    final iterator = iter().iterator;
    if (iterator.moveNext()) {
      return iterator.current;
    }
    return null;
  }

  /// Returns the number of matching entities.
  int count() {
    if (state.hasChangeFilters) {
      return iter().length;
    }

    state.updateCache(_archetypes);
    int total = 0;
    for (final archetypeIndex in state.matchingArchetypes) {
      total += _archetypes.tableAt(archetypeIndex).length;
    }
    return total;
  }

  /// Returns true if any entities match.
  bool get isNotEmpty => count() > 0;

  /// Returns true if no entities match.
  bool get isEmpty => count() == 0;
}

/// Query for three component types.
class Query3<T1, T2, T3> implements Query {
  final Archetypes _archetypes;

  @override
  final QueryState state;

  Query3(this._archetypes, {QueryFilter? filter})
      : state = QueryState.of3<T1, T2, T3>(filter: filter);

  Query3.withState(this._archetypes, this.state);

  /// Returns an iterable over all matching entities and their components.
  Iterable<(Entity, T1, T2, T3)> iter() =>
      QueryIter3<T1, T2, T3>(_archetypes, state);

  /// Returns the first matching entity, or null if none match.
  (Entity, T1, T2, T3)? single() {
    final iterator = iter().iterator;
    if (iterator.moveNext()) {
      return iterator.current;
    }
    return null;
  }

  /// Returns the number of matching entities.
  int count() {
    if (state.hasChangeFilters) {
      return iter().length;
    }

    state.updateCache(_archetypes);
    int total = 0;
    for (final archetypeIndex in state.matchingArchetypes) {
      total += _archetypes.tableAt(archetypeIndex).length;
    }
    return total;
  }

  /// Returns true if any entities match.
  bool get isNotEmpty => count() > 0;

  /// Returns true if no entities match.
  bool get isEmpty => count() == 0;
}

/// Query for four component types.
class Query4<T1, T2, T3, T4> implements Query {
  final Archetypes _archetypes;

  @override
  final QueryState state;

  Query4(this._archetypes, {QueryFilter? filter})
      : state = QueryState.of4<T1, T2, T3, T4>(filter: filter);

  Query4.withState(this._archetypes, this.state);

  /// Returns an iterable over all matching entities and their components.
  Iterable<(Entity, T1, T2, T3, T4)> iter() =>
      QueryIter4<T1, T2, T3, T4>(_archetypes, state);

  /// Returns the first matching entity, or null if none match.
  (Entity, T1, T2, T3, T4)? single() {
    final iterator = iter().iterator;
    if (iterator.moveNext()) {
      return iterator.current;
    }
    return null;
  }

  /// Returns the number of matching entities.
  int count() {
    if (state.hasChangeFilters) {
      return iter().length;
    }

    state.updateCache(_archetypes);
    int total = 0;
    for (final archetypeIndex in state.matchingArchetypes) {
      total += _archetypes.tableAt(archetypeIndex).length;
    }
    return total;
  }

  /// Returns true if any entities match.
  bool get isNotEmpty => count() > 0;

  /// Returns true if no entities match.
  bool get isEmpty => count() == 0;
}
