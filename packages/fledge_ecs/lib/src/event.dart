/// Type-safe event system for inter-system communication.
///
/// Events allow systems to communicate without direct coupling.
/// The event system uses double-buffering: events written this frame
/// are read next frame.
///
/// ## Example
///
/// ```dart
/// // Define an event
/// class CollisionEvent {
///   final Entity a;
///   final Entity b;
///   CollisionEvent(this.a, this.b);
/// }
///
/// // Register with world
/// world.registerEvent<CollisionEvent>();
///
/// // Write events
/// @system
/// void collisionSystem(EventWriter<CollisionEvent> writer) {
///   writer.send(CollisionEvent(entityA, entityB));
/// }
///
/// // Read events
/// @system
/// void damageSystem(EventReader<CollisionEvent> reader) {
///   for (final event in reader.read()) {
///     // Handle collision
///   }
/// }
/// ```
library;

/// Double-buffered event queue for a specific event type.
///
/// Events written in the current frame are readable in the next frame.
/// This prevents systems from seeing events they just wrote.
class EventQueue<T> {
  /// Events from the previous frame (readable).
  List<T> _readBuffer = [];

  /// Events from the current frame (writable).
  List<T> _writeBuffer = [];

  /// The number of events available to read.
  int get length => _readBuffer.length;

  /// Returns true if there are no events to read.
  bool get isEmpty => _readBuffer.isEmpty;

  /// Returns true if there are events to read.
  bool get isNotEmpty => _readBuffer.isNotEmpty;

  /// Sends an event to be read next frame.
  void send(T event) {
    _writeBuffer.add(event);
  }

  /// Sends multiple events to be read next frame.
  void sendBatch(Iterable<T> events) {
    _writeBuffer.addAll(events);
  }

  /// Returns an iterator over events from the previous frame.
  Iterable<T> read() => _readBuffer;

  /// Swaps the buffers, making current frame's events readable.
  ///
  /// This should be called once per frame, typically at the start.
  /// Allocates a fresh write buffer to avoid any stale references.
  void update() {
    _readBuffer = _writeBuffer;
    _writeBuffer = <T>[];
  }

  /// Clears all events from both buffers.
  void clear() {
    _readBuffer.clear();
    _writeBuffer.clear();
  }
}

/// Container for all event queues.
///
/// Manages registration and access to typed event queues.
class Events {
  final Map<Type, EventQueue<dynamic>> _queues = {};

  /// Registers an event type.
  ///
  /// This must be called before using [EventReader] or [EventWriter]
  /// for this event type.
  void register<T>() {
    _queues[T] = EventQueue<T>();
  }

  /// Returns the event queue for type [T].
  ///
  /// Throws if the event type is not registered.
  EventQueue<T> queue<T>() {
    final queue = _queues[T];
    if (queue == null) {
      throw StateError(
        'Event type $T is not registered. '
        'Call world.registerEvent<$T>() first.',
      );
    }
    return queue as EventQueue<T>;
  }

  /// Returns the event queue for type [T], or null if not registered.
  EventQueue<T>? tryQueue<T>() {
    return _queues[T] as EventQueue<T>?;
  }

  /// Returns true if an event type is registered.
  bool isRegistered<T>() {
    return _queues.containsKey(T);
  }

  /// Updates all event queues, swapping their buffers.
  ///
  /// This should be called once per frame.
  void update() {
    for (final queue in _queues.values) {
      queue.update();
    }
  }

  /// Clears all events from all queues.
  void clear() {
    for (final queue in _queues.values) {
      queue.clear();
    }
  }
}

/// Read access to events of type [T].
///
/// Used in systems to read events sent in the previous frame.
///
/// ```dart
/// @system
/// void handleCollisions(EventReader<CollisionEvent> reader) {
///   for (final event in reader.read()) {
///     print('Collision between ${event.a} and ${event.b}');
///   }
/// }
/// ```
class EventReader<T> {
  final EventQueue<T> _queue;

  /// Creates an event reader.
  EventReader(this._queue);

  /// Returns an iterator over all events from the previous frame.
  ///
  /// Each event is only available for one frame after being sent.
  Iterable<T> read() => _queue.read();

  /// Returns the number of events available to read.
  int get length => _queue.length;

  /// Returns true if there are no events to read.
  bool get isEmpty => _queue.isEmpty;

  /// Returns true if there are events to read.
  bool get isNotEmpty => _queue.isNotEmpty;
}

/// Write access to events of type [T].
///
/// Used in systems to send events that will be readable next frame.
///
/// ```dart
/// @system
/// void detectCollisions(EventWriter<CollisionEvent> writer) {
///   // When collision detected:
///   writer.send(CollisionEvent(entityA, entityB));
/// }
/// ```
class EventWriter<T> {
  final EventQueue<T> _queue;

  /// Creates an event writer.
  EventWriter(this._queue);

  /// Sends an event to be read next frame.
  void send(T event) {
    _queue.send(event);
  }

  /// Sends multiple events to be read next frame.
  void sendBatch(Iterable<T> events) {
    _queue.sendBatch(events);
  }
}

/// Combined read and write access to events of type [T].
///
/// Used when a system needs both to read and write events of the same type.
///
/// ```dart
/// @system
/// void chainReactions(EventReadWriter<ExplosionEvent> events) {
///   for (final event in events.read()) {
///     // Check for chain reactions
///     if (causesChainReaction(event)) {
///       events.send(ExplosionEvent(newLocation));
///     }
///   }
/// }
/// ```
class EventReadWriter<T> {
  final EventQueue<T> _queue;

  /// Creates an event read/writer.
  EventReadWriter(this._queue);

  /// Returns an iterator over all events from the previous frame.
  Iterable<T> read() => _queue.read();

  /// Sends an event to be read next frame.
  void send(T event) {
    _queue.send(event);
  }

  /// Sends multiple events to be read next frame.
  void sendBatch(Iterable<T> events) {
    _queue.sendBatch(events);
  }

  /// Returns the number of events available to read.
  int get length => _queue.length;

  /// Returns true if there are no events to read.
  bool get isEmpty => _queue.isEmpty;

  /// Returns true if there are events to read.
  bool get isNotEmpty => _queue.isNotEmpty;
}
