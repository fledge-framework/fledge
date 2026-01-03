import 'package:fledge_render/fledge_render.dart';
import 'package:test/test.dart';

/// Test node that records when it runs.
class RecordingNode implements RenderNode {
  @override
  final String name;
  final List<String> log;

  @override
  final List<SlotInfo> inputs;

  @override
  final List<SlotInfo> outputs;

  RecordingNode(
    this.name,
    this.log, {
    this.inputs = const [],
    this.outputs = const [],
  });

  @override
  void run(RenderGraphContext graph, Object context) {
    log.add(name);
  }
}

/// Test node that passes a value through.
class PassThroughNode implements RenderNode {
  @override
  final String name;
  final String inputSlot;
  final String outputSlot;
  final dynamic Function(dynamic)? transform;

  @override
  List<SlotInfo> get inputs => [
        SlotInfo(name: inputSlot, type: SlotType.custom),
      ];

  @override
  List<SlotInfo> get outputs => [
        SlotInfo(name: outputSlot, type: SlotType.custom),
      ];

  PassThroughNode(
    this.name, {
    required this.inputSlot,
    required this.outputSlot,
    this.transform,
  });

  @override
  void run(RenderGraphContext graph, Object context) {
    final value = graph.getInput<dynamic>(inputSlot);
    final result = transform != null ? transform!(value) : value;
    graph.setOutput(outputSlot, SlotValue(SlotType.custom, result));
  }
}

/// Test node that produces a value.
class ProducerNode implements RenderNode {
  @override
  final String name;
  final String slot;
  final dynamic value;

  @override
  List<SlotInfo> get inputs => const [];

  @override
  List<SlotInfo> get outputs => [
        SlotInfo(name: slot, type: SlotType.custom),
      ];

  ProducerNode(this.name, {required this.slot, required this.value});

  @override
  void run(RenderGraphContext graph, Object context) {
    graph.setOutput(slot, SlotValue(SlotType.custom, value));
  }
}

/// Test node that consumes a value.
class ConsumerNode implements RenderNode {
  @override
  final String name;
  final String slot;
  dynamic receivedValue;
  final bool required;

  @override
  List<SlotInfo> get inputs => [
        SlotInfo(name: slot, type: SlotType.custom, required: required),
      ];

  @override
  List<SlotInfo> get outputs => const [];

  ConsumerNode(this.name, {required this.slot, this.required = true});

  @override
  void run(RenderGraphContext graph, Object context) {
    receivedValue = graph.getInput<dynamic>(slot);
  }
}

void main() {
  group('SlotId', () {
    test('equality', () {
      const a = SlotId('node1', 'slot1');
      const b = SlotId('node1', 'slot1');
      const c = SlotId('node1', 'slot2');
      const d = SlotId('node2', 'slot1');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(d)));
    });

    test('hashCode', () {
      const a = SlotId('node1', 'slot1');
      const b = SlotId('node1', 'slot1');

      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString', () {
      const slot = SlotId('myNode', 'mySlot');
      expect(slot.toString(), equals('myNode::mySlot'));
    });
  });

  group('SlotInfo', () {
    test('equality', () {
      const a = SlotInfo(name: 'slot', type: SlotType.texture);
      const b = SlotInfo(name: 'slot', type: SlotType.texture);
      const c = SlotInfo(name: 'slot', type: SlotType.buffer);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('optional slot', () {
      const required = SlotInfo(name: 'slot', type: SlotType.texture);
      const optional =
          SlotInfo(name: 'slot', type: SlotType.texture, required: false);

      expect(required.required, isTrue);
      expect(optional.required, isFalse);
    });
  });

  group('SlotValue', () {
    test('as<T> casts value', () {
      final value = SlotValue(SlotType.custom, 42);
      expect(value.as<int>(), equals(42));
    });

    test('value getter returns raw value', () {
      final value = SlotValue(SlotType.custom, 'hello');
      expect(value.value, equals('hello'));
    });
  });

  group('Edge', () {
    test('equality', () {
      final a = Edge(
        from: const SlotId('a', 'out'),
        to: const SlotId('b', 'in'),
      );
      final b = Edge(
        from: const SlotId('a', 'out'),
        to: const SlotId('b', 'in'),
      );
      final c = Edge(
        from: const SlotId('a', 'out'),
        to: const SlotId('c', 'in'),
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('Edge.connect factory', () {
      final edge = Edge.connect('nodeA', 'output', 'nodeB', 'input');
      expect(edge.from, equals(const SlotId('nodeA', 'output')));
      expect(edge.to, equals(const SlotId('nodeB', 'input')));
    });
  });

  group('RenderGraph', () {
    test('addNode adds node to graph', () {
      final graph = RenderGraph();
      final log = <String>[];
      final node = RecordingNode('test', log);

      graph.addNode(node);

      expect(graph.hasNode('test'), isTrue);
      expect(graph.getNode('test'), equals(node));
    });

    test('addNode throws on duplicate name', () {
      final graph = RenderGraph();
      final log = <String>[];

      graph.addNode(RecordingNode('test', log));

      expect(
        () => graph.addNode(RecordingNode('test', log)),
        throwsArgumentError,
      );
    });

    test('removeNode removes node and edges', () {
      final graph = RenderGraph();
      graph.addNode(ProducerNode('a', slot: 'out', value: 1));
      graph.addNode(ConsumerNode('b', slot: 'in', required: false));
      graph.addEdge(
        const SlotId('a', 'out'),
        const SlotId('b', 'in'),
      );

      graph.removeNode('a');

      expect(graph.hasNode('a'), isFalse);
      expect(graph.edges, isEmpty);
    });

    test('execute runs nodes in topological order', () {
      final graph = RenderGraph();
      final log = <String>[];

      // Add nodes in arbitrary order
      graph.addNode(RecordingNode('c', log));
      graph.addNode(RecordingNode('a', log, outputs: [
        const SlotInfo(name: 'out', type: SlotType.custom),
      ]));
      graph.addNode(RecordingNode('b', log, inputs: [
        const SlotInfo(name: 'in', type: SlotType.custom),
      ], outputs: [
        const SlotInfo(name: 'out', type: SlotType.custom),
      ]));

      // a -> b (c is independent)
      graph.addEdge(
        const SlotId('a', 'out'),
        const SlotId('b', 'in'),
      );

      graph.execute(Object());

      // a must run before b, c can run anytime
      final aIndex = log.indexOf('a');
      final bIndex = log.indexOf('b');
      expect(aIndex, lessThan(bIndex));
      expect(log, contains('c'));
    });

    test('execute passes values through edges', () {
      final graph = RenderGraph();

      graph.addNode(ProducerNode('producer', slot: 'value', value: 42));
      final consumer = ConsumerNode('consumer', slot: 'value');
      graph.addNode(consumer);
      graph.addEdge(
        const SlotId('producer', 'value'),
        const SlotId('consumer', 'value'),
      );

      graph.execute(Object());

      expect(consumer.receivedValue, equals(42));
    });

    test('execute chains multiple nodes', () {
      final graph = RenderGraph();

      graph.addNode(ProducerNode('start', slot: 'out', value: 10));
      graph.addNode(PassThroughNode(
        'double',
        inputSlot: 'in',
        outputSlot: 'out',
        transform: (v) => (v as int) * 2,
      ));
      final end = ConsumerNode('end', slot: 'in');
      graph.addNode(end);

      graph.addEdge(
        const SlotId('start', 'out'),
        const SlotId('double', 'in'),
      );
      graph.addEdge(
        const SlotId('double', 'out'),
        const SlotId('end', 'in'),
      );

      graph.execute(Object());

      expect(end.receivedValue, equals(20));
    });

    test('addEdge validates source node exists', () {
      final graph = RenderGraph();
      graph.addNode(ConsumerNode('b', slot: 'in'));

      expect(
        () => graph.addEdge(
          const SlotId('a', 'out'),
          const SlotId('b', 'in'),
        ),
        throwsArgumentError,
      );
    });

    test('addEdge validates destination node exists', () {
      final graph = RenderGraph();
      graph.addNode(ProducerNode('a', slot: 'out', value: 1));

      expect(
        () => graph.addEdge(
          const SlotId('a', 'out'),
          const SlotId('b', 'in'),
        ),
        throwsArgumentError,
      );
    });

    test('addEdge validates output slot exists', () {
      final graph = RenderGraph();
      graph.addNode(ProducerNode('a', slot: 'out', value: 1));
      graph.addNode(ConsumerNode('b', slot: 'in'));

      expect(
        () => graph.addEdge(
          const SlotId('a', 'wrong'),
          const SlotId('b', 'in'),
        ),
        throwsArgumentError,
      );
    });

    test('addEdge validates input slot exists', () {
      final graph = RenderGraph();
      graph.addNode(ProducerNode('a', slot: 'out', value: 1));
      graph.addNode(ConsumerNode('b', slot: 'in'));

      expect(
        () => graph.addEdge(
          const SlotId('a', 'out'),
          const SlotId('b', 'wrong'),
        ),
        throwsArgumentError,
      );
    });

    test('execute throws on unconnected required input', () {
      final graph = RenderGraph();
      graph.addNode(ConsumerNode('consumer', slot: 'required', required: true));

      expect(
        () => graph.execute(Object()),
        throwsA(isA<MissingInputError>()),
      );
    });

    test('execute allows unconnected optional input', () {
      final graph = RenderGraph();
      final consumer =
          ConsumerNode('consumer', slot: 'optional', required: false);
      graph.addNode(consumer);

      graph.execute(Object());

      expect(consumer.receivedValue, isNull);
    });

    test('execute detects cycles', () {
      final graph = RenderGraph();

      graph.addNode(PassThroughNode('a', inputSlot: 'in', outputSlot: 'out'));
      graph.addNode(PassThroughNode('b', inputSlot: 'in', outputSlot: 'out'));

      // Create a cycle: a -> b -> a
      graph.addEdge(const SlotId('a', 'out'), const SlotId('b', 'in'));
      graph.addEdge(const SlotId('b', 'out'), const SlotId('a', 'in'));

      expect(
        () => graph.execute(Object()),
        throwsA(isA<RenderGraphCycleError>()),
      );
    });

    test('addNodeAfter auto-connects matching slots', () {
      final graph = RenderGraph();

      graph.addNode(ProducerNode('a', slot: 'data', value: 'hello'));
      graph.addNodeAfter(
        ConsumerNode('b', slot: 'data'),
        'a',
      );

      expect(graph.edges, hasLength(1));
      expect(graph.edges.first.from, equals(const SlotId('a', 'data')));
      expect(graph.edges.first.to, equals(const SlotId('b', 'data')));
    });

    test('clear removes all nodes and edges', () {
      final graph = RenderGraph();
      final log = <String>[];

      graph.addNode(RecordingNode('a', log));
      graph.addNode(RecordingNode('b', log));

      graph.clear();

      expect(graph.nodes, isEmpty);
      expect(graph.edges, isEmpty);
    });

    test('executionOrder returns sorted order after execute', () {
      final graph = RenderGraph();
      final log = <String>[];

      graph.addNode(RecordingNode('a', log, outputs: [
        const SlotInfo(name: 'out', type: SlotType.custom),
      ]));
      graph.addNode(RecordingNode('b', log, inputs: [
        const SlotInfo(name: 'in', type: SlotType.custom),
      ]));
      graph.addEdge(const SlotId('a', 'out'), const SlotId('b', 'in'));

      expect(graph.executionOrder, isNull);

      graph.execute(Object());

      final order = graph.executionOrder;
      expect(order, isNotNull);
      expect(order!.indexOf('a'), lessThan(order.indexOf('b')));
    });

    test('invalidateOrder clears cached order', () {
      final graph = RenderGraph();
      final log = <String>[];

      graph.addNode(RecordingNode('a', log));
      graph.execute(Object());

      expect(graph.executionOrder, isNotNull);

      graph.invalidateOrder();

      expect(graph.executionOrder, isNull);
    });
  });

  group('RenderGraphContext', () {
    test('getInput returns null for missing slot', () {
      final context = RenderGraphContext('test');
      expect(context.getInput<int>('missing'), isNull);
    });

    test('setOutput and getSlotValue work together', () {
      final context = RenderGraphContext('test');
      context.setOutput('out', const SlotValue(SlotType.custom, 42));

      final value = context.getSlotValue(const SlotId('test', 'out'));
      expect(value?.as<int>(), equals(42));
    });

    test('copySlot copies value between slots', () {
      final context = RenderGraphContext('test');
      context.setSlotValue(
        const SlotId('a', 'out'),
        const SlotValue(SlotType.custom, 'copied'),
      );

      context.copySlot(
        const SlotId('a', 'out'),
        const SlotId('b', 'in'),
      );

      final copied = context.getSlotValue(const SlotId('b', 'in'));
      expect(copied?.as<String>(), equals('copied'));
    });
  });
}
