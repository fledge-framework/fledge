import 'dart:ui' show Color;
import 'package:tiled/tiled.dart' as tiled;

/// Type-safe wrapper for Tiled custom properties.
///
/// Provides convenient accessors for different property types with
/// optional default values.
///
/// Example:
/// ```dart
/// final props = TiledProperties.fromTiled(object.properties);
///
/// final health = props.getIntOr('health', 100);
/// final speed = props.getDoubleOr('speed', 5.0);
/// final isBoss = props.getBoolOr('is_boss', false);
/// final spawnType = props.getStringOr('spawn_type', 'enemy');
/// ```
class TiledProperties {
  final Map<String, dynamic> _properties;

  TiledProperties(this._properties);

  /// Creates an empty TiledProperties.
  TiledProperties.empty() : _properties = const {};

  /// Creates from Tiled's CustomProperties.
  factory TiledProperties.fromCustomProperties(
      tiled.CustomProperties properties) {
    final map = <String, dynamic>{};
    for (final prop in properties) {
      map[prop.name] = _parsePropertyValue(prop);
    }
    return TiledProperties(map);
  }

  /// Creates from Tiled's property list (legacy).
  factory TiledProperties.fromTiled(List<tiled.Property<Object>> properties) {
    final map = <String, dynamic>{};
    for (final prop in properties) {
      map[prop.name] = _parsePropertyValue(prop);
    }
    return TiledProperties(map);
  }

  static dynamic _parsePropertyValue(tiled.Property<Object> prop) {
    // The tiled package already parses values, but we normalize them here
    final value = prop.value;

    // Handle different property types
    switch (prop.type) {
      case tiled.PropertyType.bool:
        if (value is bool) return value;
        if (value is String) return value.toLowerCase() == 'true';
        return false;
      case tiled.PropertyType.int:
        if (value is int) return value;
        if (value is String) return int.tryParse(value) ?? 0;
        return 0;
      case tiled.PropertyType.float:
        if (value is double) return value;
        if (value is int) return value.toDouble();
        if (value is String) return double.tryParse(value) ?? 0.0;
        return 0.0;
      case tiled.PropertyType.color:
        // Colors are stored as Color objects
        if (value is Color) {
          // Convert Color to hex string
          return '#${value.toARGB32().toRadixString(16).padLeft(8, '0')}';
        }
        if (value is String) return value;
        return null;
      case tiled.PropertyType.file:
        return value as String?;
      case tiled.PropertyType.object:
        // Object references are stored as int IDs
        if (value is int) return value;
        if (value is String) return int.tryParse(value);
        return null;
      case tiled.PropertyType.string:
        return value.toString();
    }
  }

  /// Gets a string property.
  String? getString(String name) {
    final value = _properties[name];
    return value?.toString();
  }

  /// Gets a string property with a default value.
  String getStringOr(String name, String defaultValue) =>
      getString(name) ?? defaultValue;

  /// Gets an int property.
  int? getInt(String name) {
    final value = _properties[name];
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Gets an int property with a default value.
  int getIntOr(String name, int defaultValue) => getInt(name) ?? defaultValue;

  /// Gets a double property.
  double? getDouble(String name) {
    final value = _properties[name];
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Gets a double property with a default value.
  double getDoubleOr(String name, double defaultValue) =>
      getDouble(name) ?? defaultValue;

  /// Gets a bool property.
  bool? getBool(String name) {
    final value = _properties[name];
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    if (value is int) return value != 0;
    return null;
  }

  /// Gets a bool property with a default value.
  bool getBoolOr(String name, bool defaultValue) =>
      getBool(name) ?? defaultValue;

  /// Gets a color property.
  ///
  /// Tiled stores colors as #AARRGGBB or #RRGGBB strings.
  Color? getColor(String name) {
    final value = _properties[name];
    if (value == null) return null;

    String hex;
    if (value is String) {
      hex = value.replaceFirst('#', '');
    } else {
      return null;
    }

    // Parse ARGB or RGB hex
    int? intValue;
    if (hex.length == 8) {
      // AARRGGBB format
      intValue = int.tryParse(hex, radix: 16);
    } else if (hex.length == 6) {
      // RRGGBB format, assume full opacity
      intValue = int.tryParse('FF$hex', radix: 16);
    }

    if (intValue == null) return null;
    return Color(intValue);
  }

  /// Gets a color property with a default value.
  Color getColorOr(String name, Color defaultValue) =>
      getColor(name) ?? defaultValue;

  /// Gets a file path property.
  String? getFile(String name) => getString(name);

  /// Gets a file path property with a default value.
  String getFileOr(String name, String defaultValue) =>
      getFile(name) ?? defaultValue;

  /// Gets an object reference property (object ID).
  int? getObjectRef(String name) => getInt(name);

  /// Gets an object reference property with a default value.
  int getObjectRefOr(String name, int defaultValue) =>
      getObjectRef(name) ?? defaultValue;

  /// Checks if a property exists.
  bool has(String name) => _properties.containsKey(name);

  /// Returns all property names.
  Iterable<String> get names => _properties.keys;

  /// Returns the raw property map (read-only).
  Map<String, dynamic> get raw => Map.unmodifiable(_properties);

  /// Returns true if there are no properties.
  bool get isEmpty => _properties.isEmpty;

  /// Returns true if there are properties.
  bool get isNotEmpty => _properties.isNotEmpty;

  /// Number of properties.
  int get length => _properties.length;

  @override
  String toString() => 'TiledProperties($_properties)';
}
