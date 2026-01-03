import 'package:meta/meta.dart';

/// A unique identifier for a component type.
///
/// Each component type is assigned a unique [ComponentId] when first registered.
/// This ID is used for efficient storage and lookup in the archetype system.
@immutable
class ComponentId implements Comparable<ComponentId> {
  /// The numeric identifier for this component type.
  final int id;

  const ComponentId._(this.id);

  /// Registry mapping types to their component IDs.
  static final Map<Type, ComponentId> _registry = {};

  /// Counter for assigning new component IDs.
  static int _nextId = 0;

  /// Gets or creates a [ComponentId] for the given type [T].
  ///
  /// The first call for a given type will assign a new ID.
  /// Subsequent calls return the same ID.
  static ComponentId of<T>() {
    return _registry.putIfAbsent(T, () => ComponentId._(_nextId++));
  }

  /// Gets or creates a [ComponentId] for the given runtime [type].
  ///
  /// Prefer [of<T>()] when the type is known at compile time.
  static ComponentId ofType(Type type) {
    return _registry.putIfAbsent(type, () => ComponentId._(_nextId++));
  }

  /// Returns the [ComponentId] for type [T] if it has been registered.
  static ComponentId? tryOf<T>() => _registry[T];

  /// Returns the [ComponentId] for [type] if it has been registered.
  static ComponentId? tryOfType(Type type) => _registry[type];

  /// Resets the component registry. Only use for testing.
  @visibleForTesting
  static void resetRegistry() {
    _registry.clear();
    _nextId = 0;
  }

  @override
  int compareTo(ComponentId other) => id.compareTo(other.id);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ComponentId && id == other.id;

  @override
  int get hashCode => id;

  @override
  String toString() => 'ComponentId($id)';
}

/// Descriptor for a component type with its metadata.
///
/// This is used internally to manage component storage and
/// can be extended by the code generator for additional metadata.
class ComponentDescriptor<T> {
  /// The unique identifier for this component type.
  final ComponentId id;

  /// The runtime type of the component.
  final Type type;

  ComponentDescriptor._(this.id, this.type);

  /// Creates a descriptor for component type [T].
  factory ComponentDescriptor() {
    return ComponentDescriptor._(ComponentId.of<T>(), T);
  }

  @override
  String toString() => 'ComponentDescriptor<$type>(id: $id)';
}
