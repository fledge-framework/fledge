import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:test/test.dart';

class TestEvent {
  final int value;
  TestEvent(this.value);
}

class AnotherEvent {
  final String message;
  AnotherEvent(this.message);
}

void main() {
  group('EventQueue', () {
    late EventQueue<TestEvent> queue;

    setUp(() {
      queue = EventQueue<TestEvent>();
    });

    test('newly created queue is empty', () {
      expect(queue.isEmpty, isTrue);
      expect(queue.length, equals(0));
    });

    test('send adds event to write buffer', () {
      queue.send(TestEvent(1));
      // Not readable until update
      expect(queue.isEmpty, isTrue);
    });

    test('update makes events readable', () {
      queue.send(TestEvent(1));
      queue.send(TestEvent(2));
      queue.update();

      expect(queue.isEmpty, isFalse);
      expect(queue.length, equals(2));
    });

    test('read returns events from previous frame', () {
      queue.send(TestEvent(1));
      queue.send(TestEvent(2));
      queue.update();

      final events = queue.read().toList();
      expect(events.length, equals(2));
      expect(events[0].value, equals(1));
      expect(events[1].value, equals(2));
    });

    test('events are cleared after update', () {
      queue.send(TestEvent(1));
      queue.update();
      queue.update();

      expect(queue.isEmpty, isTrue);
    });

    test('sendBatch adds multiple events', () {
      queue.sendBatch([TestEvent(1), TestEvent(2), TestEvent(3)]);
      queue.update();

      expect(queue.length, equals(3));
    });

    test('clear removes all events', () {
      queue.send(TestEvent(1));
      queue.update();
      queue.send(TestEvent(2));
      queue.clear();

      expect(queue.isEmpty, isTrue);
      queue.update();
      expect(queue.isEmpty, isTrue);
    });
  });

  group('Events', () {
    late Events events;

    setUp(() {
      events = Events();
    });

    test('register creates queue for event type', () {
      events.register<TestEvent>();
      expect(events.isRegistered<TestEvent>(), isTrue);
    });

    test('isRegistered returns false for unregistered type', () {
      expect(events.isRegistered<TestEvent>(), isFalse);
    });

    test('queue returns registered queue', () {
      events.register<TestEvent>();
      final queue = events.queue<TestEvent>();
      expect(queue, isNotNull);
    });

    test('queue throws for unregistered type', () {
      expect(() => events.queue<TestEvent>(), throwsStateError);
    });

    test('tryQueue returns null for unregistered type', () {
      expect(events.tryQueue<TestEvent>(), isNull);
    });

    test('update updates all queues', () {
      events.register<TestEvent>();
      events.register<AnotherEvent>();

      events.queue<TestEvent>().send(TestEvent(1));
      events.queue<AnotherEvent>().send(AnotherEvent('hello'));
      events.update();

      expect(events.queue<TestEvent>().length, equals(1));
      expect(events.queue<AnotherEvent>().length, equals(1));
    });

    test('clear clears all queues', () {
      events.register<TestEvent>();
      events.queue<TestEvent>().send(TestEvent(1));
      events.update();
      events.clear();

      expect(events.queue<TestEvent>().isEmpty, isTrue);
    });
  });

  group('EventReader', () {
    late EventQueue<TestEvent> queue;
    late EventReader<TestEvent> reader;

    setUp(() {
      queue = EventQueue<TestEvent>();
      reader = EventReader(queue);
    });

    test('read returns events', () {
      queue.send(TestEvent(1));
      queue.update();

      final events = reader.read().toList();
      expect(events.length, equals(1));
      expect(events[0].value, equals(1));
    });

    test('isEmpty reflects queue state', () {
      expect(reader.isEmpty, isTrue);

      queue.send(TestEvent(1));
      queue.update();

      expect(reader.isEmpty, isFalse);
    });

    test('length reflects queue state', () {
      expect(reader.length, equals(0));

      queue.send(TestEvent(1));
      queue.send(TestEvent(2));
      queue.update();

      expect(reader.length, equals(2));
    });
  });

  group('EventWriter', () {
    late EventQueue<TestEvent> queue;
    late EventWriter<TestEvent> writer;

    setUp(() {
      queue = EventQueue<TestEvent>();
      writer = EventWriter(queue);
    });

    test('send adds event', () {
      writer.send(TestEvent(1));
      queue.update();

      expect(queue.read().first.value, equals(1));
    });

    test('sendBatch adds multiple events', () {
      writer.sendBatch([TestEvent(1), TestEvent(2)]);
      queue.update();

      expect(queue.length, equals(2));
    });
  });

  group('EventReadWriter', () {
    late EventQueue<TestEvent> queue;
    late EventReadWriter<TestEvent> readWriter;

    setUp(() {
      queue = EventQueue<TestEvent>();
      readWriter = EventReadWriter(queue);
    });

    test('can read and write', () {
      readWriter.send(TestEvent(1));
      queue.update();

      expect(readWriter.read().first.value, equals(1));
    });

    test('can chain reactions', () {
      queue.send(TestEvent(1));
      queue.update();

      // Read existing events, write new ones
      for (final event in readWriter.read()) {
        if (event.value < 5) {
          readWriter.send(TestEvent(event.value + 1));
        }
      }

      queue.update();
      expect(queue.read().first.value, equals(2));
    });
  });

  group('World event methods', () {
    late World world;

    setUp(() {
      world = World();
    });

    test('registerEvent and eventReader', () {
      world.registerEvent<TestEvent>();

      final writer = world.eventWriter<TestEvent>();
      writer.send(TestEvent(42));

      world.updateEvents();

      final reader = world.eventReader<TestEvent>();
      expect(reader.read().first.value, equals(42));
    });

    test('updateEvents swaps buffers', () {
      world.registerEvent<TestEvent>();

      world.eventWriter<TestEvent>().send(TestEvent(1));
      expect(world.eventReader<TestEvent>().isEmpty, isTrue);

      world.updateEvents();
      expect(world.eventReader<TestEvent>().isNotEmpty, isTrue);
    });
  });
}
