import '../entity.dart';
import '../hierarchy/hierarchy.dart';
import '../world.dart';

/// A deferred command to be executed on the world.
sealed class Command {
  /// Executes this command on the world.
  void execute(World world);
}

/// Command to spawn a new entity.
class SpawnCommand extends Command {
  final List<dynamic> _components = [];
  Entity? _spawnedEntity;

  /// The entity that was spawned (available after execution).
  Entity? get entity => _spawnedEntity;

  /// Adds a component to be inserted when the entity is spawned.
  ///
  /// Returns this command for cascade chaining:
  /// ```dart
  /// commands.spawn()
  ///   ..insert(Position(0, 0))
  ///   ..insert(Velocity(1, 1));
  /// ```
  SpawnCommand insert<T>(T component) {
    _components.add(component);
    return this;
  }

  @override
  void execute(World world) {
    _spawnedEntity = world.spawnWith(_components);
  }
}

/// Command to despawn an entity.
class DespawnCommand extends Command {
  final Entity entity;

  DespawnCommand(this.entity);

  @override
  void execute(World world) {
    world.despawn(entity);
  }
}

/// Command to recursively despawn an entity and all its descendants.
class DespawnRecursiveCommand extends Command {
  final Entity entity;

  DespawnRecursiveCommand(this.entity);

  @override
  void execute(World world) {
    world.despawnRecursive(entity);
  }
}

/// Command to spawn a new entity as a child of a parent.
class SpawnChildCommand extends Command {
  final Entity parent;
  final List<dynamic> _components = [];
  Entity? _spawnedEntity;

  SpawnChildCommand(this.parent);

  /// The entity that was spawned (available after execution).
  Entity? get entity => _spawnedEntity;

  /// Adds a component to be inserted when the entity is spawned.
  ///
  /// Returns this command for cascade chaining:
  /// ```dart
  /// commands.spawnChild(parentEntity)
  ///   ..insert(Position(0, 0))
  ///   ..insert(Velocity(1, 1));
  /// ```
  SpawnChildCommand insert<T>(T component) {
    _components.add(component);
    return this;
  }

  @override
  void execute(World world) {
    if (world.isAlive(parent)) {
      final childEntity = world.spawnWith(_components);
      world.setParent(childEntity, parent);
      _spawnedEntity = childEntity;
    }
  }
}

/// Command to insert a component into an entity.
class InsertCommand<T> extends Command {
  final Entity entity;
  final T component;

  InsertCommand(this.entity, this.component);

  @override
  void execute(World world) {
    if (world.isAlive(entity)) {
      world.insert(entity, component);
    }
  }
}

/// Command to remove a component from an entity.
class RemoveCommand<T> extends Command {
  final Entity entity;

  RemoveCommand(this.entity);

  @override
  void execute(World world) {
    if (world.isAlive(entity)) {
      world.remove<T>(entity);
    }
  }
}

/// Command to run a custom function on the world.
class CustomCommand extends Command {
  final void Function(World world) action;

  CustomCommand(this.action);

  @override
  void execute(World world) {
    action(world);
  }
}

/// A buffer for deferred world mutations.
///
/// Commands allows systems to queue mutations that will be applied later,
/// avoiding issues with modifying the world during iteration.
///
/// ## Why Use Commands?
///
/// When iterating over entities in a query, modifying entity archetypes
/// (adding/removing components, spawning/despawning) can invalidate
/// iterators. Commands defer these operations until a safe point.
///
/// ## Example
///
/// ```dart
/// void spawnBulletSystem(World world, Commands commands) {
///   for (final (entity, gun, transform) in world.query2<Gun, Transform>().iter()) {
///     if (gun.shouldFire) {
///       // Spawn uses cascade syntax, same as world.spawn()
///       commands.spawn()
///         ..insert(Bullet())
///         ..insert(Transform(position: transform.position))
///         ..insert(Velocity(direction: transform.forward * gun.bulletSpeed));
///       gun.shouldFire = false;
///     }
///   }
/// }
///
/// // Later, apply all commands
/// commands.apply(world);
/// ```
class Commands {
  final List<Command> _queue = [];

  /// Queues a command to spawn a new entity.
  ///
  /// Use cascade syntax to add components:
  /// ```dart
  /// commands.spawn()
  ///   ..insert(Position(0, 0))
  ///   ..insert(Velocity(1, 1));
  /// ```
  ///
  /// Returns a [SpawnCommand] that will contain the spawned entity
  /// after [apply] is called.
  SpawnCommand spawn() {
    final command = SpawnCommand();
    _queue.add(command);
    return command;
  }

  /// Queues a command to despawn an entity.
  void despawn(Entity entity) {
    _queue.add(DespawnCommand(entity));
  }

  /// Queues a command to recursively despawn an entity and all its descendants.
  ///
  /// This will despawn the entity's children, grandchildren, etc.
  void despawnRecursive(Entity entity) {
    _queue.add(DespawnRecursiveCommand(entity));
  }

  /// Queues a command to spawn a new entity as a child of a parent.
  ///
  /// Use cascade syntax to add components:
  /// ```dart
  /// commands.spawnChild(parentEntity)
  ///   ..insert(Position(0, 0))
  ///   ..insert(Velocity(1, 1));
  /// ```
  ///
  /// Returns a [SpawnChildCommand] that will contain the spawned entity
  /// after [apply] is called.
  SpawnChildCommand spawnChild(Entity parent) {
    final command = SpawnChildCommand(parent);
    _queue.add(command);
    return command;
  }

  /// Queues a command to insert a component into an entity.
  void insert<T>(Entity entity, T component) {
    _queue.add(InsertCommand<T>(entity, component));
  }

  /// Queues a command to remove a component from an entity.
  void remove<T>(Entity entity) {
    _queue.add(RemoveCommand<T>(entity));
  }

  /// Queues a custom command.
  void custom(void Function(World world) action) {
    _queue.add(CustomCommand(action));
  }

  /// Applies all queued commands to the world in order.
  ///
  /// The command queue is cleared after execution.
  void apply(World world) {
    for (final command in _queue) {
      command.execute(world);
    }
    _queue.clear();
  }

  /// Returns true if there are no queued commands.
  bool get isEmpty => _queue.isEmpty;

  /// Returns true if there are queued commands.
  bool get isNotEmpty => _queue.isNotEmpty;

  /// The number of queued commands.
  int get length => _queue.length;

  /// Clears all queued commands without executing them.
  void clear() {
    _queue.clear();
  }
}
