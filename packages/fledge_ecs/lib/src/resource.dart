/// Global singleton resources for the ECS world.
///
/// Resources are shared data that systems can access. Unlike components,
/// resources are not attached to entities - they are global singletons.
///
/// ## Example
///
/// ```dart
/// // Define a resource
/// class Time {
///   double delta = 0.0;
///   double elapsed = 0.0;
/// }
///
/// // Insert into world
/// world.insertResource(Time());
///
/// // Access in a system
/// @system
/// void updateSystem(Query1<Position> query, Res<Time> time) {
///   for (final (entity, pos) in query.iter()) {
///     pos.x += time.value.delta;
///   }
/// }
/// ```
library;

/// Container for global singleton resources.
///
/// Resources are stored by type and can be accessed using [get], [getOrInsert],
/// or through [Res] and [ResMut] wrappers in systems.
class Resources {
  final Map<Type, dynamic> _resources = {};

  /// Inserts a resource of type [T].
  ///
  /// If a resource of this type already exists, it is replaced.
  void insert<T>(T resource) {
    _resources[T] = resource;
  }

  /// Gets a resource of type [T].
  ///
  /// Returns null if no resource of this type exists.
  T? get<T>() {
    return _resources[T] as T?;
  }

  /// Gets a resource of type [T], inserting a default if it doesn't exist.
  T getOrInsert<T>(T Function() defaultValue) {
    if (!_resources.containsKey(T)) {
      _resources[T] = defaultValue();
    }
    return _resources[T] as T;
  }

  /// Removes a resource of type [T].
  ///
  /// Returns the removed resource, or null if it didn't exist.
  T? remove<T>() {
    return _resources.remove(T) as T?;
  }

  /// Returns true if a resource of type [T] exists.
  bool contains<T>() {
    return _resources.containsKey(T);
  }

  /// Clears all resources.
  void clear() {
    _resources.clear();
  }

  /// The number of resources.
  int get length => _resources.length;
}

/// Read-only accessor for a resource.
///
/// Used in systems to declare read access to a resource.
///
/// ```dart
/// @system
/// void mySystem(Res<Time> time) {
///   print('Delta: ${time.value.delta}');
/// }
/// ```
class Res<T> {
  final T _value;

  /// Creates a read-only resource accessor.
  Res(this._value);

  /// The resource value.
  T get value => _value;

  /// Allows using the resource directly in expressions.
  T call() => _value;

  @override
  String toString() => 'Res<$T>($_value)';
}

/// Mutable accessor for a resource.
///
/// Used in systems to declare write access to a resource.
///
/// ```dart
/// @system
/// void timeSystem(ResMut<Time> time) {
///   time.value.elapsed += time.value.delta;
/// }
/// ```
class ResMut<T> {
  final T _value;

  /// Creates a mutable resource accessor.
  ResMut(this._value);

  /// The resource value.
  T get value => _value;

  /// Allows using the resource directly in expressions.
  T call() => _value;

  @override
  String toString() => 'ResMut<$T>($_value)';
}

/// Optional resource accessor.
///
/// Used when a resource might not exist.
///
/// ```dart
/// @system
/// void mySystem(ResOption<Config> config) {
///   if (config.value != null) {
///     // Use config
///   }
/// }
/// ```
class ResOption<T> {
  final T? _value;

  /// Creates an optional resource accessor.
  ResOption(this._value);

  /// The resource value, or null if it doesn't exist.
  T? get value => _value;

  /// Returns true if the resource exists.
  bool get exists => _value != null;

  /// Allows using the resource directly in expressions.
  T? call() => _value;

  @override
  String toString() => 'ResOption<$T>($_value)';
}
