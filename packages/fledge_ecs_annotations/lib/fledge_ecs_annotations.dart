/// Annotations for the Fledge ECS framework.
///
/// This package provides annotations used to mark classes and functions
/// for code generation by `fledge_ecs_generator`.
library fledge_ecs_annotations;

/// Marks a class as an ECS component.
///
/// Components are pure data containers with no behavior.
/// They are stored efficiently in archetype-based storage.
///
/// ```dart
/// @component
/// class Position {
///   double x;
///   double y;
///   Position(this.x, this.y);
/// }
/// ```
const component = Component();

/// Annotation class for [component].
class Component {
  const Component();
}

/// Marks a function as an ECS system.
///
/// Systems contain the logic that operates on entities with specific components.
/// The function signature determines which components the system accesses.
///
/// ```dart
/// @system
/// void movementSystem(Query<(Position, Velocity)> query, Res<Time> time) {
///   for (final (entity, pos, vel) in query.iter()) {
///     pos.x += vel.dx * time.delta;
///     pos.y += vel.dy * time.delta;
///   }
/// }
/// ```
const system = SystemAnnotation();

/// Annotation class for [system].
///
/// Named `SystemAnnotation` to avoid conflicts with the runtime `System` interface.
class SystemAnnotation {
  /// The schedule stage this system runs in.
  final CoreStage stage;

  const SystemAnnotation({this.stage = CoreStage.update});
}

/// Marks a class as a global resource.
///
/// Resources are singleton data accessible by systems.
/// Unlike components, resources are not attached to entities.
///
/// ```dart
/// @resource
/// class Time {
///   double delta = 0.0;
///   double elapsed = 0.0;
/// }
/// ```
const resource = Resource();

/// Annotation class for [resource].
class Resource {
  const Resource();
}

/// Marks a class as an event type.
///
/// Events provide a way for systems to communicate without
/// direct coupling. Events are processed in a double-buffered queue.
///
/// ```dart
/// @event
/// class CollisionEvent {
///   final Entity a;
///   final Entity b;
///   CollisionEvent(this.a, this.b);
/// }
/// ```
const event = Event();

/// Annotation class for [event].
class Event {
  const Event();
}

/// Marks a component as reflectable for serialization and editor tooling.
///
/// When a component is marked with `@reflectable`, the code generator
/// will create runtime type information including:
///
/// - Field metadata (names, types, nullability)
/// - JSON serialization/deserialization functions
/// - Default value factories
///
/// ```dart
/// @component
/// @reflectable
/// class Position {
///   double x;
///   double y;
///   Position(this.x, this.y);
/// }
///
/// // Usage:
/// final info = TypeRegistry.instance.getByType<Position>()!;
/// final json = info.toJson(position); // {'x': 10.0, 'y': 20.0}
/// final restored = info.fromJson(json) as Position;
/// ```
const reflectable = Reflectable();

/// Annotation class for [reflectable].
class Reflectable {
  const Reflectable();
}

/// Core schedule stages for system execution ordering.
///
/// Systems are grouped into stages, and stages run in order.
/// Within a stage, systems may run concurrently if they don't conflict.
enum CoreStage {
  /// Runs before all other stages. Use for setup that must happen first.
  first,

  /// Runs before the main update. Use for input processing.
  preUpdate,

  /// The main update stage. Most game logic runs here.
  update,

  /// Runs after the main update. Use for reactions to update changes.
  postUpdate,

  /// Runs after all other stages. Use for cleanup and finalization.
  last,
}
