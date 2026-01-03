import 'package:fledge_ecs/fledge_ecs.dart';

/// Separate world for render-specific data.
///
/// Unlike the main world, the render world is rebuilt each frame from
/// extracted data. This separation allows the main world to run game
/// logic while the render world handles GPU resources.
///
/// The render world follows Bevy's two-world architecture:
/// 1. Main world contains game entities and components
/// 2. Render world contains extracted render data and GPU resources
/// 3. Each frame, relevant data is extracted from main to render world
///
/// Example:
/// ```dart
/// final renderWorld = RenderWorld();
///
/// // At start of frame, clear previous data
/// renderWorld.clear();
///
/// // Extract entities from main world
/// for (final (entity, sprite, transform) in mainWorld.query2().iter()) {
///   renderWorld.spawn()
///     ..insert(ExtractedSprite(sprite, transform));
/// }
///
/// // Run render systems on render world
/// renderSchedule.run(renderWorld);
/// ```
class RenderWorld {
  final World _world = World();

  /// Access the underlying ECS world.
  ///
  /// This is primarily for internal use. Prefer using the typed methods
  /// like [spawn], [getResource], etc.
  World get world => _world;

  /// Clear all entities from the render world.
  ///
  /// Called at the start of each frame to prepare for new extracted data.
  /// Resources are preserved across frames.
  void clear() {
    _world.clear();
  }

  /// Spawn an entity in the render world.
  EntityCommands spawn() => _world.spawn();

  /// Get a resource from the render world.
  T? getResource<T>() => _world.getResource<T>();

  /// Insert a resource into the render world.
  void insertResource<T>(T resource) => _world.insertResource(resource);

  /// Remove a resource from the render world.
  T? removeResource<T>() => _world.removeResource<T>();

  /// Check if a resource exists in the render world.
  bool hasResource<T>() => _world.hasResource<T>();

  /// Query for entities with one component.
  Query1<T1> query1<T1>({QueryFilter? filter}) =>
      _world.query1<T1>(filter: filter);

  /// Query for entities with two components.
  Query2<T1, T2> query2<T1, T2>({QueryFilter? filter}) =>
      _world.query2<T1, T2>(filter: filter);

  /// Query for entities with three components.
  Query3<T1, T2, T3> query3<T1, T2, T3>({QueryFilter? filter}) =>
      _world.query3<T1, T2, T3>(filter: filter);

  /// Query for entities with four components.
  Query4<T1, T2, T3, T4> query4<T1, T2, T3, T4>({QueryFilter? filter}) =>
      _world.query4<T1, T2, T3, T4>(filter: filter);

  /// Get a component from an entity.
  T? get<T>(Entity entity) => _world.get<T>(entity);

  /// Insert a component into an entity.
  void insert<T>(Entity entity, T component) =>
      _world.insert(entity, component);

  /// Remove a component from an entity.
  T? remove<T>(Entity entity) => _world.remove<T>(entity);

  /// Despawn an entity.
  void despawn(Entity entity) => _world.despawn(entity);

  /// Check if an entity exists.
  bool contains(Entity entity) => _world.isAlive(entity);

  /// The number of entities in the render world.
  int get entityCount => _world.entityCount;
}
