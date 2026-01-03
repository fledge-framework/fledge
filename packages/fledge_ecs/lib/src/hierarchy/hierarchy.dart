import '../entity.dart';
import '../world.dart';

/// Component that stores a reference to an entity's parent.
///
/// Used by the hierarchy system to track parent-child relationships.
/// Use [WorldHierarchyExtension.setParent] instead of manually inserting this.
class Parent {
  /// The parent entity.
  final Entity entity;

  /// Creates a parent component pointing to the given entity.
  const Parent(this.entity);

  @override
  String toString() => 'Parent($entity)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Parent && entity == other.entity;

  @override
  int get hashCode => entity.hashCode;
}

/// Component that stores references to an entity's children.
///
/// Used by the hierarchy system to track parent-child relationships.
/// This component is automatically managed by [WorldHierarchyExtension.setParent]
/// and [WorldHierarchyExtension.removeParent].
class Children {
  final List<Entity> _children;

  /// Creates a children component with an optional initial list.
  Children([List<Entity>? children]) : _children = children ?? [];

  /// The list of child entities (read-only view).
  List<Entity> get list => List.unmodifiable(_children);

  /// The number of children.
  int get length => _children.length;

  /// Whether there are any children.
  bool get isEmpty => _children.isEmpty;

  /// Whether there are children.
  bool get isNotEmpty => _children.isNotEmpty;

  /// Adds a child entity.
  void add(Entity child) {
    if (!_children.contains(child)) {
      _children.add(child);
    }
  }

  /// Removes a child entity.
  bool remove(Entity child) => _children.remove(child);

  /// Whether this contains the given child.
  bool contains(Entity child) => _children.contains(child);

  /// Iterates over children.
  Iterable<Entity> get children => _children;

  @override
  String toString() => 'Children($_children)';
}

/// Extension on [World] for managing entity hierarchies.
///
/// Provides methods for setting up parent-child relationships,
/// traversing hierarchies, and recursively despawning entities.
///
/// ```dart
/// final parent = world.spawn().entity;
/// final child = world.spawn().entity;
///
/// world.setParent(child, parent);
///
/// // Traverse hierarchy
/// for (final ancestor in world.ancestors(child)) {
///   print(ancestor);
/// }
///
/// // Despawn parent and all children
/// world.despawnRecursive(parent);
/// ```
extension WorldHierarchyExtension on World {
  /// Sets the parent of a child entity.
  ///
  /// If the child already has a parent, it is first removed from that parent.
  /// The parent entity will have a [Children] component added or updated.
  ///
  /// ```dart
  /// world.setParent(child, parent);
  /// ```
  void setParent(Entity child, Entity parent) {
    if (!isAlive(child) || !isAlive(parent)) return;

    // Remove from old parent if exists
    final oldParent = get<Parent>(child);
    if (oldParent != null) {
      _removeFromParentChildren(child, oldParent.entity);
    }

    // Set new parent
    insert(child, Parent(parent));

    // Add to parent's children list
    var children = get<Children>(parent);
    if (children == null) {
      children = Children();
      insert(parent, children);
    }
    children.add(child);
  }

  /// Removes the parent from a child entity.
  ///
  /// The child will be removed from its parent's [Children] list.
  ///
  /// ```dart
  /// world.removeParent(child);
  /// ```
  void removeParent(Entity child) {
    if (!isAlive(child)) return;

    final parent = get<Parent>(child);
    if (parent != null) {
      _removeFromParentChildren(child, parent.entity);
      remove<Parent>(child);
    }
  }

  /// Internal helper to remove a child from a parent's Children component.
  void _removeFromParentChildren(Entity child, Entity parent) {
    if (!isAlive(parent)) return;

    final children = get<Children>(parent);
    if (children != null) {
      children.remove(child);
      // Optionally remove empty Children component
      if (children.isEmpty) {
        remove<Children>(parent);
      }
    }
  }

  /// Gets the parent entity of the given entity.
  ///
  /// Returns null if the entity has no parent or is dead.
  ///
  /// ```dart
  /// final parent = world.getParent(child);
  /// ```
  Entity? getParent(Entity entity) {
    if (!isAlive(entity)) return null;
    return get<Parent>(entity)?.entity;
  }

  /// Gets the direct children of the given entity.
  ///
  /// Returns an empty iterable if the entity has no children or is dead.
  ///
  /// ```dart
  /// for (final child in world.getChildren(parent)) {
  ///   print(child);
  /// }
  /// ```
  Iterable<Entity> getChildren(Entity entity) {
    if (!isAlive(entity)) return const [];
    return get<Children>(entity)?.children ?? const [];
  }

  /// Checks if an entity has a parent.
  bool hasParent(Entity entity) => get<Parent>(entity) != null;

  /// Checks if an entity has children.
  bool hasChildren(Entity entity) {
    final children = get<Children>(entity);
    return children != null && children.isNotEmpty;
  }

  /// Returns the root ancestor of the given entity.
  ///
  /// If the entity has no parent, returns the entity itself.
  ///
  /// ```dart
  /// final root = world.root(entity);
  /// ```
  Entity root(Entity entity) {
    var current = entity;
    while (true) {
      final parent = getParent(current);
      if (parent == null) return current;
      current = parent;
    }
  }

  /// Iterates over all ancestors of the given entity.
  ///
  /// The first element is the direct parent, then grandparent, etc.
  /// Stops when reaching an entity with no parent.
  ///
  /// ```dart
  /// for (final ancestor in world.ancestors(entity)) {
  ///   print('Ancestor: $ancestor');
  /// }
  /// ```
  Iterable<Entity> ancestors(Entity entity) sync* {
    var current = getParent(entity);
    while (current != null) {
      yield current;
      current = getParent(current);
    }
  }

  /// Iterates over all descendants of the given entity.
  ///
  /// Uses depth-first traversal. Direct children come first,
  /// followed by their children, etc.
  ///
  /// ```dart
  /// for (final descendant in world.descendants(entity)) {
  ///   print('Descendant: $descendant');
  /// }
  /// ```
  Iterable<Entity> descendants(Entity entity) sync* {
    for (final child in getChildren(entity)) {
      yield child;
      yield* descendants(child);
    }
  }

  /// Despawns an entity and all its descendants recursively.
  ///
  /// Also removes the entity from its parent's children list.
  ///
  /// ```dart
  /// // Despawns parent and all children/grandchildren
  /// world.despawnRecursive(parent);
  /// ```
  void despawnRecursive(Entity entity) {
    if (!isAlive(entity)) return;

    // Remove from parent's children list first
    final parent = get<Parent>(entity);
    if (parent != null) {
      _removeFromParentChildren(entity, parent.entity);
    }

    // Collect all descendants (depth-first)
    final toRemove = <Entity>[entity];
    void collectDescendants(Entity e) {
      for (final child in getChildren(e)) {
        toRemove.add(child);
        collectDescendants(child);
      }
    }
    collectDescendants(entity);

    // Despawn in reverse order (children before parents)
    for (final e in toRemove.reversed) {
      despawn(e);
    }
  }

  /// Spawns a new entity as a child of the given parent.
  ///
  /// Returns the EntityCommands for the new child entity.
  ///
  /// ```dart
  /// final child = world.spawnChild(parent)
  ///   ..insert(Position(0, 0));
  /// ```
  EntityCommands spawnChild(Entity parent) {
    final child = spawn();
    setParent(child.entity, parent);
    return child;
  }
}
