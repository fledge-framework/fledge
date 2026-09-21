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
/// Systems contain the logic that operates on entities with specific
/// components. The function signature determines which components and
/// resources the system accesses, and the code generator emits a matching
/// [SystemMeta] so the scheduler can safely parallelise non-conflicting
/// systems.
///
/// ## Query access is inferred by parameter *type*, not by inspection
///
/// The generator does **not** analyse the function body to work out which
/// components you mutate. Instead, intent is declared at the type level:
///
/// - `QueryN<...>`    — every type argument is treated as a **read**.
/// - `QueryMutN<...>` — every type argument is treated as a **write**.
///
/// This keeps the generator simple and predictable, and it makes access
/// intent visible at the call site.
///
/// ```dart
/// // Reads Position and Velocity — can run in parallel with other reads.
/// @system
/// void logMovementSystem(Query2<Position, Velocity> query) {
///   for (final (_, pos, vel) in query.iter()) {
///     print('$pos moving by $vel');
///   }
/// }
///
/// // Writes Position and Velocity — serialised against any conflicting
/// // reader/writer of those components.
/// @system
/// void movementSystem(QueryMut2<Position, Velocity> query, Res<WallTime> time) {
///   for (final (_, pos, vel) in query.iter()) {
///     pos.x += vel.dx * time.value.delta;
///     pos.y += vel.dy * time.value.delta;
///   }
/// }
/// ```
///
/// ## Mixed reads/writes on the same query
///
/// A single query cannot mix read and write intent across its components.
/// If a system needs to read some components while writing others, split
/// the access into two parameters — one `Query`, one `QueryMut`:
///
/// ```dart
/// @system
/// void applyDamageSystem(
///   Query1<Damage> incoming,           // reads Damage
///   QueryMut1<Health> targets,         // writes Health
/// ) { ... }
/// ```
///
/// If the two accesses genuinely overlap on the same entities and cannot
/// be split, drop the annotation and implement `System` directly, then
/// declare `reads`/`writes` by hand on the `SystemMeta`.
///
/// ## Runtime behavior
///
/// `Query` and `QueryMut` are runtime-identical — both wrap the same
/// storage and return mutable references from `iter()`. The distinction is
/// a nominal marker consumed by the generator; it is not enforced at
/// runtime.
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
/// class WallTime {
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
