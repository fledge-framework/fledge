/// Unique identifier for a slot in the render graph.
///
/// Slots are identified by a combination of node name and slot name.
class SlotId {
  /// The name of the node that owns this slot.
  final String node;

  /// The name of this slot within the node.
  final String slot;

  /// Creates a slot identifier.
  const SlotId(this.node, this.slot);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SlotId && node == other.node && slot == other.slot;

  @override
  int get hashCode => Object.hash(node, slot);

  @override
  String toString() => '$node::$slot';
}

/// Type of resource a slot can hold.
enum SlotType {
  /// A texture resource.
  texture,

  /// A GPU buffer resource.
  buffer,

  /// A texture sampler.
  sampler,

  /// Entity data.
  entity,

  /// Camera view data.
  camera,

  /// Custom user-defined type.
  custom,
}

/// Information about a slot.
///
/// Describes the name, type, and whether the slot is required.
class SlotInfo {
  /// The name of this slot.
  final String name;

  /// The type of resource this slot accepts.
  final SlotType type;

  /// Whether this slot must be connected for the node to run.
  final bool required;

  /// Creates slot information.
  const SlotInfo({
    required this.name,
    required this.type,
    this.required = true,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SlotInfo &&
          name == other.name &&
          type == other.type &&
          required == other.required;

  @override
  int get hashCode => Object.hash(name, type, required);

  @override
  String toString() => 'SlotInfo($name, $type${required ? '' : ', optional'})';
}

/// A value passed through a slot in the render graph.
class SlotValue {
  /// The type of this value.
  final SlotType type;

  /// The actual value.
  final dynamic _value;

  /// Creates a slot value.
  const SlotValue(this.type, this._value);

  /// Gets the value cast to the specified type.
  T as<T>() => _value as T;

  /// Gets the raw value.
  dynamic get value => _value;

  @override
  String toString() => 'SlotValue($type, $_value)';
}
