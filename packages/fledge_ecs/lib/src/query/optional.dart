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
abstract class Option<T> {
  const Option._();

  /// Gets the ComponentId for the wrapped type T.
  static ComponentId componentIdOf<T>() => ComponentId.of<T>();
}

/// Type alias for clarity in query results.
/// When a component is optional, it may be null.
typedef OptionalComponent<T> = T?;
