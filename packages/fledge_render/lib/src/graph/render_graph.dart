import 'edge.dart';
import 'render_node.dart';
import 'slot.dart';

/// Exception thrown when the render graph contains a cycle.
class RenderGraphCycleError extends Error {
  /// The nodes involved in the cycle.
  final List<String> cycle;

  /// Creates a cycle error.
  RenderGraphCycleError(this.cycle);

  @override
  String toString() =>
      'RenderGraphCycleError: Cycle detected: ${cycle.join(' -> ')}';
}

/// Exception thrown when a required input slot is not connected.
class MissingInputError extends Error {
  /// The node with the missing input.
  final String node;

  /// The name of the missing input slot.
  final String slot;

  /// Creates a missing input error.
  MissingInputError(this.node, this.slot);

  @override
  String toString() =>
      'MissingInputError: Node "$node" has unconnected required input "$slot"';
}

/// Exception thrown when slot types don't match.
class SlotTypeMismatchError extends Error {
  /// The source slot.
  final SlotId from;

  /// The destination slot.
  final SlotId to;

  /// The type of the source slot.
  final SlotType fromType;

  /// The type of the destination slot.
  final SlotType toType;

  /// Creates a slot type mismatch error.
  SlotTypeMismatchError(this.from, this.to, this.fromType, this.toType);

  @override
  String toString() =>
      'SlotTypeMismatchError: Cannot connect $from ($fromType) to $to ($toType)';
}

/// DAG-based render pipeline.
///
/// The render graph manages a collection of [RenderNode]s connected by
/// [Edge]s. Nodes are executed in topological order, ensuring that
/// dependencies are satisfied before each node runs.
///
/// Example:
/// ```dart
/// final graph = RenderGraph();
/// graph.addNode(CameraDriverNode());
/// graph.addNode(SpriteRenderNode());
/// graph.addEdge(SlotId('camera_driver', 'view'), SlotId('sprite_render', 'view'));
/// graph.execute(context);
/// ```
class RenderGraph {
  final Map<String, RenderNode> _nodes = {};
  final List<Edge> _edges = [];
  List<String>? _sortedOrder;

  /// All nodes in the graph.
  Iterable<RenderNode> get nodes => _nodes.values;

  /// All edges in the graph.
  List<Edge> get edges => List.unmodifiable(_edges);

  /// Add a node to the graph.
  ///
  /// Throws [ArgumentError] if a node with the same name already exists.
  void addNode(RenderNode node) {
    if (_nodes.containsKey(node.name)) {
      throw ArgumentError('Node "${node.name}" already exists in the graph');
    }
    _nodes[node.name] = node;
    _sortedOrder = null; // Invalidate cache
  }

  /// Remove a node from the graph.
  ///
  /// Also removes all edges connected to this node.
  void removeNode(String name) {
    _nodes.remove(name);
    _edges.removeWhere((e) => e.from.node == name || e.to.node == name);
    _sortedOrder = null;
  }

  /// Get a node by name.
  RenderNode? getNode(String name) => _nodes[name];

  /// Check if the graph contains a node.
  bool hasNode(String name) => _nodes.containsKey(name);

  /// Connect two slots with an edge.
  ///
  /// Validates that:
  /// - Both nodes exist
  /// - The output slot exists on the source node
  /// - The input slot exists on the destination node
  /// - The slot types match
  void addEdge(SlotId from, SlotId to) {
    // Validate nodes exist
    final fromNode = _nodes[from.node];
    if (fromNode == null) {
      throw ArgumentError('Source node "${from.node}" does not exist');
    }
    final toNode = _nodes[to.node];
    if (toNode == null) {
      throw ArgumentError('Destination node "${to.node}" does not exist');
    }

    // Validate slots exist
    final outputSlot =
        fromNode.outputs.where((s) => s.name == from.slot).firstOrNull;
    if (outputSlot == null) {
      throw ArgumentError(
          'Output slot "${from.slot}" does not exist on node "${from.node}"');
    }
    final inputSlot = toNode.inputs.where((s) => s.name == to.slot).firstOrNull;
    if (inputSlot == null) {
      throw ArgumentError(
          'Input slot "${to.slot}" does not exist on node "${to.node}"');
    }

    // Validate type compatibility
    if (outputSlot.type != inputSlot.type &&
        inputSlot.type != SlotType.custom &&
        outputSlot.type != SlotType.custom) {
      throw SlotTypeMismatchError(from, to, outputSlot.type, inputSlot.type);
    }

    _edges.add(Edge(from: from, to: to));
    _sortedOrder = null;
  }

  /// Add node and connect it after another node.
  ///
  /// This is a convenience method that adds a node and automatically
  /// connects matching slots between the two nodes.
  void addNodeAfter(RenderNode node, String afterNode) {
    addNode(node);

    final prevNode = _nodes[afterNode];
    if (prevNode == null) {
      throw ArgumentError('Node "$afterNode" does not exist');
    }

    // Auto-connect matching slots
    for (final input in node.inputs) {
      for (final output in prevNode.outputs) {
        if (input.name == output.name && input.type == output.type) {
          _edges.add(Edge(
            from: SlotId(afterNode, output.name),
            to: SlotId(node.name, input.name),
          ));
        }
      }
    }
    _sortedOrder = null;
  }

  /// Execute graph in topological order.
  ///
  /// Validates all required inputs are connected, sorts nodes by
  /// dependencies, then runs each node in order.
  void execute(Object context) {
    _validateRequiredInputs();
    _sortedOrder ??= _topologicalSort();

    final graphContext = RenderGraphContext('');

    for (final nodeName in _sortedOrder!) {
      final node = _nodes[nodeName]!;

      // Copy values from connected output slots to input slots
      for (final edge in _edges.where((e) => e.to.node == nodeName)) {
        graphContext.copySlot(edge.from, edge.to);
      }

      // Create node-specific context
      final nodeContext = _NodeGraphContext(graphContext, nodeName);

      // Run the node
      node.run(nodeContext, context);

      // Copy outputs to the shared graph context
      for (final output in node.outputs) {
        final outputId = SlotId(nodeName, output.name);
        final value = nodeContext.getSlotValue(outputId);
        if (value != null) {
          graphContext.setSlotValue(outputId, value);
        }
      }
    }
  }

  /// Validate that all required inputs are connected.
  void _validateRequiredInputs() {
    for (final node in _nodes.values) {
      for (final input in node.inputs) {
        if (!input.required) continue;

        final hasConnection = _edges.any(
          (e) => e.to.node == node.name && e.to.slot == input.name,
        );

        if (!hasConnection) {
          throw MissingInputError(node.name, input.name);
        }
      }
    }
  }

  /// Topologically sort nodes using Kahn's algorithm.
  List<String> _topologicalSort() {
    // Build adjacency list
    final inDegree = <String, int>{};
    final adjacency = <String, List<String>>{};

    for (final name in _nodes.keys) {
      inDegree[name] = 0;
      adjacency[name] = [];
    }

    for (final edge in _edges) {
      adjacency[edge.from.node]!.add(edge.to.node);
      inDegree[edge.to.node] = inDegree[edge.to.node]! + 1;
    }

    // Start with nodes that have no incoming edges
    final queue = <String>[];
    for (final entry in inDegree.entries) {
      if (entry.value == 0) {
        queue.add(entry.key);
      }
    }

    final sorted = <String>[];

    while (queue.isNotEmpty) {
      final node = queue.removeAt(0);
      sorted.add(node);

      for (final neighbor in adjacency[node]!) {
        inDegree[neighbor] = inDegree[neighbor]! - 1;
        if (inDegree[neighbor] == 0) {
          queue.add(neighbor);
        }
      }
    }

    // Check for cycles
    if (sorted.length != _nodes.length) {
      final remaining = _nodes.keys.where((n) => !sorted.contains(n)).toList();
      throw RenderGraphCycleError(remaining);
    }

    return sorted;
  }

  /// Get the execution order of nodes.
  ///
  /// Returns `null` if the graph has not been sorted yet.
  List<String>? get executionOrder =>
      _sortedOrder != null ? List.unmodifiable(_sortedOrder!) : null;

  /// Force recalculation of execution order.
  void invalidateOrder() {
    _sortedOrder = null;
  }

  /// Clear all nodes and edges.
  void clear() {
    _nodes.clear();
    _edges.clear();
    _sortedOrder = null;
  }
}

/// Internal context wrapper that tracks the current node.
class _NodeGraphContext extends RenderGraphContext {
  final RenderGraphContext _parent;
  final String _nodeName;

  _NodeGraphContext(this._parent, this._nodeName) : super(_nodeName);

  @override
  T? getInput<T>(String slotName) {
    final slotId = SlotId(_nodeName, slotName);
    return _parent.getSlotValue(slotId)?.as<T>();
  }

  @override
  void setOutput(String slotName, SlotValue value) {
    final slotId = SlotId(_nodeName, slotName);
    setSlotValue(slotId, value);
  }
}
