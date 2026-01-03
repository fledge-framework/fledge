import 'slot.dart';

/// A node in the render graph that performs GPU work.
///
/// Nodes define their inputs and outputs via [SlotInfo], and execute
/// their rendering logic in the [run] method.
///
/// Example:
/// ```dart
/// class SpriteRenderNode implements RenderNode {
///   @override
///   String get name => 'sprite_render';
///
///   @override
///   List<SlotInfo> get inputs => const [
///     SlotInfo(name: 'view', type: SlotType.camera),
///   ];
///
///   @override
///   List<SlotInfo> get outputs => const [];
///
///   @override
///   void run(RenderGraphContext graph, covariant RenderContext context) {
///     final view = graph.getInput<CameraView>('view');
///     // Render sprites...
///   }
/// }
/// ```
abstract class RenderNode {
  /// Unique name for this node in the graph.
  String get name;

  /// Input slots this node reads from.
  ///
  /// Connected via edges from other nodes' output slots.
  List<SlotInfo> get inputs => const [];

  /// Output slots this node produces.
  ///
  /// Can be connected via edges to other nodes' input slots.
  List<SlotInfo> get outputs => const [];

  /// Execute the node's rendering work.
  ///
  /// The [graph] context provides access to input slot values and
  /// allows setting output slot values.
  ///
  /// The [context] provides access to the render world and GPU commands.
  void run(RenderGraphContext graph, covariant Object context);
}

/// Context for accessing graph resources during node execution.
///
/// Provides methods to read input slot values and write output slot values.
class RenderGraphContext {
  final Map<SlotId, SlotValue> _slots = {};
  final String _currentNode;

  /// Creates a graph context for the specified node.
  RenderGraphContext(this._currentNode);

  /// Get input value from a slot.
  ///
  /// Returns `null` if the slot is not connected or has no value.
  T? getInput<T>(String slotName) {
    final slotId = SlotId(_currentNode, slotName);
    final value = _slots[slotId];
    return value?.as<T>();
  }

  /// Set output value to a slot.
  void setOutput(String slotName, SlotValue value) {
    final slotId = SlotId(_currentNode, slotName);
    _slots[slotId] = value;
  }

  /// Internal: Get a slot value by its full ID.
  SlotValue? getSlotValue(SlotId id) => _slots[id];

  /// Internal: Set a slot value by its full ID.
  void setSlotValue(SlotId id, SlotValue value) {
    _slots[id] = value;
  }

  /// Internal: Copy an output value to an input slot.
  void copySlot(SlotId from, SlotId to) {
    final value = _slots[from];
    if (value != null) {
      _slots[to] = value;
    }
  }
}
