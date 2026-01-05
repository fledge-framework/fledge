import 'archetype/archetype_id.dart';
import 'archetype/archetypes.dart';
import 'archetype/entities.dart';
import 'change_detection/tick.dart';
import 'component.dart';
import 'entity.dart';
import 'event.dart';
import 'observer/observer.dart';
import 'query/query.dart';
import 'resource.dart';

/// The central container for all ECS data.
///
/// The [World] manages entities, their components, and provides methods
/// for spawning, despawning, and querying entities.
///
/// ## Example
///
/// ```dart
/// final world = World();
///
/// // Spawn an entity with components
/// final entity = world.spawn()
///   ..insert(Position(0, 0))
///   ..insert(Velocity(1, 1));
///
/// // Get a component
/// final pos = world.get<Position>(entity);
///
/// // Modify a component
/// world.get<Position>(entity)?.x = 10;
///
/// // Remove a component
/// world.remove<Position>(entity);
///
/// // Despawn the entity
/// world.despawn(entity);
/// ```
class World {
  /// The archetype storage.
  final Archetypes archetypes = Archetypes();

  /// The entity manager.
  final Entities entities = Entities();

  /// Global singleton resources.
  final Resources resources = Resources();

  /// Event queues.
  final Events events = Events();

  /// The global tick counter for change detection.
  final Tick tick = Tick();

  /// The observer registry for component lifecycle events.
  final Observers observers = Observers();

  /// Returns the current tick value.
  int get currentTick => tick.value;

  /// Advances the tick counter.
  ///
  /// This should be called once per frame, typically at the end of the frame
  /// after all systems have run. It enables change detection for the next frame.
  void advanceTick() => tick.advance();

  /// Spawns a new entity with no components.
  ///
  /// Returns an [EntityCommands] builder for adding components.
  ///
  /// ```dart
  /// final entity = world.spawn()
  ///   ..insert(Position(0, 0))
  ///   ..insert(Velocity(1, 1));
  /// ```
  EntityCommands spawn() {
    final entity = entities.spawn();

    // Start in the empty archetype
    final table = archetypes.tableAt(0);
    final row = table.add(entity, {}, currentTick: currentTick);
    entities.setLocation(entity, EntityLocation(0, row));

    return EntityCommands._(this, entity);
  }

  /// Spawns a new entity with the given components.
  ///
  /// This is more efficient than calling [spawn] and then [insert] for each
  /// component, as it only performs one archetype transition.
  ///
  /// Returns the spawned [Entity] directly. Use [spawn] if you need to chain
  /// additional component insertions.
  ///
  /// ```dart
  /// final entity = world.spawnWith([
  ///   Position(0, 0),
  ///   Velocity(1, 1),
  /// ]);
  /// ```
  Entity spawnWith(List<dynamic> components) {
    final entity = entities.spawn();

    if (components.isEmpty) {
      // Empty archetype
      final table = archetypes.tableAt(0);
      final row = table.add(entity, {}, currentTick: currentTick);
      entities.setLocation(entity, EntityLocation(0, row));
      return entity;
    }

    // Build archetype and component map
    final componentMap = <ComponentId, dynamic>{};
    var archetypeId = ArchetypeId.empty();

    for (final component in components) {
      final componentId = ComponentId.ofType(component.runtimeType);
      archetypeId = archetypeId.withComponent(componentId);
      componentMap[componentId] = component;
    }

    // Get or create the archetype table
    final archetypeIndex = archetypes.getOrCreate(archetypeId);
    final table = archetypes.tableAt(archetypeIndex);
    final row = table.add(entity, componentMap, currentTick: currentTick);
    entities.setLocation(entity, EntityLocation(archetypeIndex, row));

    return entity;
  }

  /// Despawns an entity, removing it and all its components.
  ///
  /// Returns true if the entity was alive, false otherwise.
  bool despawn(Entity entity) {
    final location = entities.getLocation(entity);
    if (location == null) return false;

    final table = archetypes.tableAt(location.archetypeIndex);
    final movedEntity = table.swapRemove(location.row);

    // Update the moved entity's location if one was swapped in
    if (movedEntity != null) {
      entities.setLocation(movedEntity, location);
    }

    return entities.despawn(entity);
  }

  /// Returns true if the entity is alive.
  bool isAlive(Entity entity) => entities.isAlive(entity);

  /// Gets a component of type [T] from an entity.
  ///
  /// Returns null if the entity doesn't have the component or is not alive.
  T? get<T>(Entity entity) {
    final location = entities.getLocation(entity);
    if (location == null) return null;

    final componentId = ComponentId.of<T>();
    final table = archetypes.tableAt(location.archetypeIndex);
    return table.getComponent<T>(location.row, componentId);
  }

  /// Returns true if the entity has a component of type [T].
  bool has<T>(Entity entity) {
    final location = entities.getLocation(entity);
    if (location == null) return false;

    final componentId = ComponentId.of<T>();
    return archetypes
        .tableAt(location.archetypeIndex)
        .archetypeId
        .contains(componentId);
  }

  /// Inserts a component into an entity.
  ///
  /// If the entity already has a component of this type, it is replaced.
  /// This may move the entity to a different archetype.
  void insert<T>(Entity entity, T component) {
    final location = entities.getLocation(entity);
    if (location == null) {
      throw StateError('Cannot insert component into dead entity: $entity');
    }

    final componentId = ComponentId.of<T>();
    final currentTable = archetypes.tableAt(location.archetypeIndex);

    // Check if component already exists in this archetype
    if (currentTable.archetypeId.contains(componentId)) {
      _updateExistingComponent<T>(
          currentTable, location, componentId, entity, component);
      return;
    }

    _moveToNewArchetypeWithComponent<T>(
      entity,
      location,
      currentTable,
      componentId,
      component,
    );
  }

  /// Updates an existing component in place.
  void _updateExistingComponent<T>(
    dynamic currentTable,
    EntityLocation location,
    ComponentId componentId,
    Entity entity,
    T component,
  ) {
    currentTable.setComponent(location.row, componentId, component,
        currentTick: currentTick);
    observers.triggerOnChange<T>(this, entity, component);
  }

  /// Moves an entity to a new archetype when adding a component.
  void _moveToNewArchetypeWithComponent<T>(
    Entity entity,
    EntityLocation location,
    dynamic currentTable,
    ComponentId componentId,
    T component,
  ) {
    final targetIndex =
        archetypes.getAddTarget(location.archetypeIndex, componentId);
    final targetTable = archetypes.tableAt(targetIndex);

    // Extract all existing components and their ticks
    final components = currentTable.extractRow(location.row);
    final existingTicks = currentTable.extractTicks(location.row);
    components[componentId] = component;

    // Remove from current table and update swapped entity's location
    final movedEntity = currentTable.swapRemove(location.row);
    if (movedEntity != null) {
      entities.setLocation(movedEntity, location);
    }

    // Add to new table, preserving existing ticks
    final newRow = targetTable.add(
      entity,
      components,
      currentTick: currentTick,
      existingTicks: existingTicks,
    );
    entities.setLocation(entity, EntityLocation(targetIndex, newRow));

    observers.triggerOnAdd<T>(this, entity, component);
  }

  /// Removes a component of type [T] from an entity.
  ///
  /// Returns the removed component, or null if the entity didn't have it.
  /// This may move the entity to a different archetype.
  T? remove<T>(Entity entity) {
    final location = entities.getLocation(entity);
    if (location == null) return null;

    final componentId = ComponentId.of<T>();
    final currentTable = archetypes.tableAt(location.archetypeIndex);

    // Check if component exists
    if (!currentTable.archetypeId.contains(componentId)) {
      return null;
    }

    // Get the component before removing
    final component =
        currentTable.getComponent<T>(location.row, componentId) as T;

    // Need to move to a new archetype
    final targetIndex =
        archetypes.getRemoveTarget(location.archetypeIndex, componentId);
    final targetTable = archetypes.tableAt(targetIndex);

    // Extract all existing components and ticks except the one being removed
    final components = currentTable.extractRow(location.row);
    final existingTicks = currentTable.extractTicks(location.row);
    components.remove(componentId);
    existingTicks.remove(componentId);

    // Remove from current table
    final movedEntity = currentTable.swapRemove(location.row);
    if (movedEntity != null) {
      entities.setLocation(movedEntity, location);
    }

    // Add to new table, preserving ticks for remaining components
    final newRow = targetTable.add(
      entity,
      components,
      currentTick: currentTick,
      existingTicks: existingTicks,
    );
    entities.setLocation(entity, EntityLocation(targetIndex, newRow));

    // Trigger onRemove observers
    observers.triggerOnRemove<T>(this, entity, component);

    return component;
  }

  /// The total number of alive entities.
  int get entityCount => entities.length;

  /// The total number of archetypes (unique component combinations).
  int get archetypeCount => archetypes.length;

  /// The total number of resources.
  int get resourceCount => resources.length;

  /// Clears all entities from the world.
  ///
  /// This only clears entities and archetypes. Resources and events are
  /// preserved. Use [resetGameState] for a more complete reset that
  /// preserves session-level resources.
  void clear() {
    entities.clear();
    archetypes.clear();
  }

  /// Resets game-level state while preserving session-level resources.
  ///
  /// This clears:
  /// - All entities and their components
  /// - All archetype tables
  /// - All event queues (clears both buffers)
  ///
  /// This preserves:
  /// - Resources (should be cleaned up by plugin cleanup methods)
  /// - Observers (typically registered by session-level plugins)
  ///
  /// Use this when transitioning between game sessions (e.g., returning
  /// to main menu) while keeping the app alive.
  void resetGameState() {
    entities.clear();
    archetypes.clear();
    events.clear();
  }

  /// Returns a set of all currently alive entities.
  ///
  /// Useful for capturing a snapshot of entity state that can later be
  /// passed to [despawnExcept] to reset to that state.
  ///
  /// ```dart
  /// final snapshot = world.getAllEntities();
  /// // ... spawn more entities ...
  /// world.despawnExcept(snapshot); // Removes entities spawned after snapshot
  /// ```
  Set<Entity> getAllEntities() {
    return entities.allAlive.toSet();
  }

  /// Despawns all entities except those in [keep].
  ///
  /// Useful for resetting to a previous entity state. Entities in [keep]
  /// that are no longer alive are silently ignored.
  ///
  /// ```dart
  /// final snapshot = world.getAllEntities();
  /// // ... spawn temporary entities ...
  /// world.despawnExcept(snapshot); // Removes only the temporary entities
  /// ```
  void despawnExcept(Set<Entity> keep) {
    final toRemove = <Entity>[];
    for (final entity in entities.allAlive) {
      if (!keep.contains(entity)) {
        toRemove.add(entity);
      }
    }
    for (final entity in toRemove) {
      despawn(entity);
    }
  }

  // ===== Resource Methods =====

  /// Inserts a resource of type [T].
  ///
  /// If a resource of this type already exists, it is replaced.
  ///
  /// ```dart
  /// world.insertResource(Time());
  /// world.insertResource(GameConfig(difficulty: 'hard'));
  /// ```
  void insertResource<T>(T resource) {
    resources.insert(resource);
  }

  /// Gets a resource of type [T].
  ///
  /// Returns null if no resource of this type exists.
  ///
  /// ```dart
  /// final time = world.getResource<Time>();
  /// if (time != null) {
  ///   print('Delta: ${time.delta}');
  /// }
  /// ```
  T? getResource<T>() {
    return resources.get<T>();
  }

  /// Removes a resource of type [T].
  ///
  /// Returns the removed resource, or null if it didn't exist.
  T? removeResource<T>() {
    return resources.remove<T>();
  }

  /// Returns true if a resource of type [T] exists.
  bool hasResource<T>() {
    return resources.contains<T>();
  }

  // ===== Event Methods =====

  /// Registers an event type for use in the world.
  ///
  /// This must be called before using [EventReader] or [EventWriter]
  /// for this event type.
  ///
  /// ```dart
  /// world.registerEvent<CollisionEvent>();
  /// world.registerEvent<DamageEvent>();
  /// ```
  void registerEvent<T>() {
    events.register<T>();
  }

  /// Gets an event reader for type [T].
  ///
  /// ```dart
  /// final reader = world.eventReader<CollisionEvent>();
  /// for (final event in reader.read()) {
  ///   // Handle event
  /// }
  /// ```
  EventReader<T> eventReader<T>() {
    return EventReader(events.queue<T>());
  }

  /// Gets an event writer for type [T].
  ///
  /// ```dart
  /// final writer = world.eventWriter<CollisionEvent>();
  /// writer.send(CollisionEvent(entityA, entityB));
  /// ```
  EventWriter<T> eventWriter<T>() {
    return EventWriter(events.queue<T>());
  }

  /// Updates all event queues, making current frame's events readable.
  ///
  /// This should be called once per frame, typically at the start.
  void updateEvents() {
    events.update();
  }

  // ===== Query Methods =====

  /// Creates a query for entities with component [T1].
  ///
  /// ```dart
  /// for (final (entity, pos) in world.query1<Position>().iter()) {
  ///   print('Entity $entity at ${pos.x}, ${pos.y}');
  /// }
  /// ```
  Query1<T1> query1<T1>({QueryFilter? filter}) {
    return Query1<T1>(archetypes, filter: filter);
  }

  /// Creates a query for entities with components [T1] and [T2].
  ///
  /// ```dart
  /// for (final (entity, pos, vel) in world.query2<Position, Velocity>().iter()) {
  ///   pos.x += vel.dx;
  ///   pos.y += vel.dy;
  /// }
  /// ```
  Query2<T1, T2> query2<T1, T2>({QueryFilter? filter}) {
    return Query2<T1, T2>(archetypes, filter: filter);
  }

  /// Creates a query for entities with components [T1], [T2], and [T3].
  Query3<T1, T2, T3> query3<T1, T2, T3>({QueryFilter? filter}) {
    return Query3<T1, T2, T3>(archetypes, filter: filter);
  }

  /// Creates a query for entities with components [T1], [T2], [T3], and [T4].
  Query4<T1, T2, T3, T4> query4<T1, T2, T3, T4>({QueryFilter? filter}) {
    return Query4<T1, T2, T3, T4>(archetypes, filter: filter);
  }
}

/// Builder for spawning entities with components.
///
/// Provides a fluent API for adding components to a newly spawned entity.
class EntityCommands {
  final World _world;
  final Entity _entity;

  EntityCommands._(this._world, this._entity);

  /// The entity being built.
  Entity get entity => _entity;

  /// Inserts a component into the entity.
  ///
  /// Returns this builder for method chaining.
  EntityCommands insert<T>(T component) {
    _world.insert(_entity, component);
    return this;
  }

  /// Removes a component from the entity.
  ///
  /// Returns this builder for method chaining.
  EntityCommands remove<T>() {
    _world.remove<T>(_entity);
    return this;
  }
}
