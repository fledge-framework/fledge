/// Metadata about a field in a component.
///
/// Used by the reflection system to provide runtime type information
/// for serialization and editor tooling.
class FieldInfo {
  /// The field name.
  final String name;

  /// The field type.
  final Type type;

  /// Whether the field is nullable.
  final bool isNullable;

  /// An optional default value factory.
  final dynamic Function()? defaultValue;

  /// Creates field metadata.
  const FieldInfo({
    required this.name,
    required this.type,
    this.isNullable = false,
    this.defaultValue,
  });

  @override
  String toString() => 'FieldInfo($name: $type${isNullable ? '?' : ''})';
}

/// Runtime type information for a component.
///
/// [ComponentTypeInfo] provides metadata about a component type including
/// its fields and serialization functions. This is used for:
///
/// - Serialization/deserialization to JSON
/// - Editor tooling (inspectors, property editors)
/// - Runtime type introspection
///
/// ```dart
/// final info = TypeRegistry.instance.getByType<Position>()!;
///
/// // Serialize to JSON
/// final json = info.toJson(position);
///
/// // Deserialize from JSON
/// final restored = info.fromJson(json) as Position;
/// ```
class ComponentTypeInfo<T> {
  /// The component type.
  final Type type;

  /// The component name (usually the class name).
  final String name;

  /// The fields in this component.
  final List<FieldInfo> fields;

  /// Creates a new instance from a JSON map.
  final T Function(Map<String, dynamic> json) fromJson;

  /// Converts an instance to a JSON map.
  final Map<String, dynamic> Function(T instance) toJson;

  /// Optional factory function to create a default instance.
  final T Function()? defaultFactory;

  /// Converts an instance to a JSON map, accepting dynamic input.
  ///
  /// This is used internally when the static type is not known at compile time.
  Map<String, dynamic> toJsonDynamic(dynamic instance) => toJson(instance as T);

  /// Creates component type info.
  const ComponentTypeInfo({
    required this.type,
    required this.name,
    required this.fields,
    required this.fromJson,
    required this.toJson,
    this.defaultFactory,
  });

  @override
  String toString() => 'ComponentTypeInfo<$name>';
}

/// A registry for component type metadata.
///
/// The [TypeRegistry] is a singleton that stores runtime type information
/// for components marked with `@reflectable`. This enables:
///
/// - Dynamic serialization without code generation
/// - Editor tooling like property inspectors
/// - Runtime type queries
///
/// ## Registration
///
/// Components are registered either:
/// 1. Automatically via the `@reflectable` annotation (requires build_runner)
/// 2. Manually via [registerComponent]
///
/// ```dart
/// // Manual registration
/// TypeRegistry.instance.registerComponent(ComponentTypeInfo<Position>(
///   type: Position,
///   name: 'Position',
///   fields: [
///     FieldInfo(name: 'x', type: double),
///     FieldInfo(name: 'y', type: double),
///   ],
///   fromJson: (json) => Position(json['x'] as double, json['y'] as double),
///   toJson: (pos) => {'x': pos.x, 'y': pos.y},
/// ));
/// ```
///
/// ## Usage
///
/// ```dart
/// final info = TypeRegistry.instance.getByType<Position>();
/// if (info != null) {
///   // Serialize
///   final json = info.toJson(myPosition);
///
///   // Deserialize
///   final restored = info.fromJson(json);
///
///   // Inspect fields
///   for (final field in info.fields) {
///     print('${field.name}: ${field.type}');
///   }
/// }
/// ```
class TypeRegistry {
  /// The singleton instance.
  static final TypeRegistry instance = TypeRegistry._();

  /// Private constructor for singleton.
  TypeRegistry._();

  /// Registered component types by Type.
  final Map<Type, ComponentTypeInfo> _byType = {};

  /// Registered component types by name.
  final Map<String, ComponentTypeInfo> _byName = {};

  /// Registers a component type.
  ///
  /// Replaces any existing registration for the same type.
  void registerComponent<T>(ComponentTypeInfo<T> info) {
    _byType[T] = info;
    _byName[info.name] = info;
  }

  /// Gets type info by static type.
  ///
  /// Returns null if the type is not registered.
  ComponentTypeInfo<T>? getByType<T>() {
    return _byType[T] as ComponentTypeInfo<T>?;
  }

  /// Gets type info by Type object.
  ///
  /// Returns null if the type is not registered.
  ComponentTypeInfo? getByRuntimeType(Type type) {
    return _byType[type];
  }

  /// Gets type info by name.
  ///
  /// Returns null if no type with that name is registered.
  ComponentTypeInfo? getByName(String name) {
    return _byName[name];
  }

  /// Returns true if a type is registered.
  bool isRegistered<T>() => _byType.containsKey(T);

  /// Returns true if a type (by runtime Type) is registered.
  bool isRegisteredType(Type type) => _byType.containsKey(type);

  /// Returns true if a type with the given name is registered.
  bool isRegisteredName(String name) => _byName.containsKey(name);

  /// All registered component types.
  Iterable<ComponentTypeInfo> get registeredTypes => _byType.values;

  /// All registered type names.
  Iterable<String> get registeredNames => _byName.keys;

  /// The number of registered types.
  int get count => _byType.length;

  /// Clears all registered types.
  ///
  /// Useful for testing.
  void clear() {
    _byType.clear();
    _byName.clear();
  }
}

/// Extension to make registration more convenient.
extension TypeRegistryExtension on TypeRegistry {
  /// Registers a simple component with position-based constructor.
  ///
  /// This is a convenience method for common cases where fields
  /// can be directly mapped to constructor parameters.
  void registerSimple<T>({
    required String name,
    required List<FieldInfo> fields,
    required T Function(List<dynamic> args) constructor,
    required List<dynamic> Function(T instance) getFields,
  }) {
    registerComponent(ComponentTypeInfo<T>(
      type: T,
      name: name,
      fields: fields,
      fromJson: (json) {
        final args = fields.map((f) => json[f.name]).toList();
        return constructor(args);
      },
      toJson: (instance) {
        final values = getFields(instance);
        final map = <String, dynamic>{};
        for (var i = 0; i < fields.length; i++) {
          map[fields[i].name] = values[i];
        }
        return map;
      },
    ));
  }
}
