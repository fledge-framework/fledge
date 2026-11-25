import '../component.dart';

/// Marker type for optional component access in queries.
///
/// When used in a query, the component is not required for matching.
/// Entities without the component will return null for that field.
///
/// ## Example
///
/// ```dart
/// // Query all entities with Position, optionally with Velocity
/// for (final (entity, pos, vel) in world.query2<Position, Option<Velocity>>().iter()) {
///   if (vel != null) {
///     pos.x += vel.dx;
///   }
/// }
/// ```
///
/// Note: `Option<T>` is a compile-time marker. The actual query iteration
/// handles the optional logic internally.
@Deprecated(
  'Not implemented: a query with Option<T> matches no entities. Query the '
  'required components and read the optional one with world.get<T>(entity). '
  'Will be removed.',
)
abstract class Option<T> {
  const Option._();

  /// Gets the ComponentId for the wrapped type T.
  static ComponentId componentIdOf<T>() => ComponentId.of<T>();
}

/// Type alias for clarity in query results.
/// When a component is optional, it may be null.
@Deprecated('Belongs to the unimplemented Option<T>. Will be removed.')
typedef OptionalComponent<T> = T?;
