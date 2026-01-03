import 'package:meta/meta.dart';

import '../component.dart';

/// Identifies an archetype by its set of component types.
///
/// An archetype is defined by a unique combination of component types.
/// Entities with the same set of components share an archetype and are
/// stored together for cache-efficient iteration.
///
/// ## Example
///
/// ```dart
/// // Create an archetype for entities with Position and Velocity
/// final archetype = ArchetypeId.of([
///   ComponentId.of<Position>(),
///   ComponentId.of<Velocity>(),
/// ]);
/// ```
@immutable
class ArchetypeId {
  /// The sorted list of component IDs that define this archetype.
  ///
  /// Sorting ensures that the same set of components always produces
  /// the same archetype ID, regardless of insertion order.
  final List<ComponentId> components;

  /// Cached hash code for fast comparison.
  final int _hashCode;

  ArchetypeId._(this.components, this._hashCode);

  /// Creates an [ArchetypeId] from an iterable of [ComponentId]s.
  ///
  /// The components are sorted to ensure consistent ordering.
  factory ArchetypeId.of(Iterable<ComponentId> componentIds) {
    final sorted = componentIds.toList()..sort();
    return ArchetypeId._(
      List.unmodifiable(sorted),
      _computeHash(sorted),
    );
  }

  /// Creates an empty archetype (entity with no components).
  factory ArchetypeId.empty() => ArchetypeId._(const [], 0);

  /// The number of component types in this archetype.
  int get length => components.length;

  /// Returns true if this archetype has no components.
  bool get isEmpty => components.isEmpty;

  /// Returns true if this archetype contains the given [componentId].
  bool contains(ComponentId componentId) {
    // Binary search since components are sorted
    return _binarySearch(componentId) >= 0;
  }

  /// Returns a new [ArchetypeId] with the given [componentId] added.
  ///
  /// If the component is already present, returns this archetype unchanged.
  ArchetypeId withComponent(ComponentId componentId) {
    if (contains(componentId)) return this;

    final newComponents = List<ComponentId>.from(components)
      ..add(componentId)
      ..sort();

    return ArchetypeId._(
      List.unmodifiable(newComponents),
      _computeHash(newComponents),
    );
  }

  /// Returns a new [ArchetypeId] with the given [componentId] removed.
  ///
  /// If the component is not present, returns this archetype unchanged.
  ArchetypeId withoutComponent(ComponentId componentId) {
    final index = _binarySearch(componentId);
    if (index < 0) return this;

    final newComponents = List<ComponentId>.from(components)..removeAt(index);

    return ArchetypeId._(
      List.unmodifiable(newComponents),
      _computeHash(newComponents),
    );
  }

  /// Returns true if this archetype contains all components in [other].
  bool containsAll(ArchetypeId other) {
    if (other.length > length) return false;

    int i = 0, j = 0;
    while (i < length && j < other.length) {
      final cmp = components[i].compareTo(other.components[j]);
      if (cmp == 0) {
        i++;
        j++;
      } else if (cmp < 0) {
        i++;
      } else {
        return false;
      }
    }
    return j == other.length;
  }

  /// Returns true if this archetype contains any component in [other].
  bool containsAny(ArchetypeId other) {
    int i = 0, j = 0;
    while (i < length && j < other.length) {
      final cmp = components[i].compareTo(other.components[j]);
      if (cmp == 0) {
        return true;
      } else if (cmp < 0) {
        i++;
      } else {
        j++;
      }
    }
    return false;
  }

  int _binarySearch(ComponentId target) {
    int low = 0;
    int high = components.length - 1;

    while (low <= high) {
      final mid = (low + high) >> 1;
      final cmp = components[mid].compareTo(target);

      if (cmp < 0) {
        low = mid + 1;
      } else if (cmp > 0) {
        high = mid - 1;
      } else {
        return mid;
      }
    }
    return -1;
  }

  static int _computeHash(List<ComponentId> components) {
    // Use a simple but effective hash combining strategy
    int hash = 0;
    for (final component in components) {
      hash = (hash * 31 + component.id) & 0x3FFFFFFF;
    }
    return hash;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ArchetypeId) return false;
    if (_hashCode != other._hashCode) return false;
    if (length != other.length) return false;

    for (int i = 0; i < length; i++) {
      if (components[i] != other.components[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => _hashCode;

  @override
  String toString() {
    final ids = components.map((c) => c.id).join(', ');
    return 'ArchetypeId([$ids])';
  }
}
