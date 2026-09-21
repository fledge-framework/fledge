import 'slot.dart';

/// A connection between two slots in the render graph.
///
/// Edges define data flow from an output slot of one node to an
/// input slot of another node.
class Edge {
  /// The output slot that produces the value.
  final SlotId from;

  /// The input slot that receives the value.
  final SlotId to;

  /// Creates an edge between two slots.
  const Edge({required this.from, required this.to});

  /// Creates an edge using a more compact syntax.
  ///
  /// Example:
  /// ```dart
  /// Edge.connect('camera_driver', 'view', 'sprite_render', 'view')
  /// ```
  Edge.connect(
    String fromNode,
    String fromSlot,
    String toNode,
    String toSlot,
  )   : from = SlotId(fromNode, fromSlot),
        to = SlotId(toNode, toSlot);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Edge && from == other.from && to == other.to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => 'Edge($from -> $to)';
}
