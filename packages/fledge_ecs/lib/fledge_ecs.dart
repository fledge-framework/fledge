/// A Bevy-inspired Entity Component System (ECS) for Dart and Flutter.
///
/// Fledge ECS provides a high-performance, type-safe ECS architecture
/// with archetype-based storage and concurrent system execution.
///
/// ## Core Concepts
///
/// - **Entity**: A unique identifier for a game object
/// - **Component**: Pure data attached to entities
/// - **System**: Logic that operates on entities with specific components
/// - **World**: The container for all ECS data
/// - **Query**: Type-safe iteration over entities with specific components
///
/// ## Example
///
/// ```dart
/// // Define components
/// @component
/// class Position {
///   double x, y;
///   Position(this.x, this.y);
/// }
///
/// @component
/// class Velocity {
///   double dx, dy;
///   Velocity(this.dx, this.dy);
/// }
///
/// // Create world and spawn entities
/// final world = World();
/// world.spawn()
///   ..insert(Position(0, 0))
///   ..insert(Velocity(1, 1));
///
/// // Query and update
/// for (final (entity, pos, vel) in world.query2<Position, Velocity>().iter()) {
///   pos.x += vel.dx;
///   pos.y += vel.dy;
/// }
/// ```
library;

// Re-export annotations for convenience
export 'package:fledge_ecs_annotations/fledge_ecs_annotations.dart';

// Core types
export 'src/entity.dart' hide EntityLocation, EntityMeta;
export 'src/component.dart';

// Archetype storage (internal, but exposed for advanced use)
export 'src/archetype/archetype_id.dart';
export 'src/archetype/table.dart';
export 'src/archetype/archetypes.dart';
export 'src/archetype/entities.dart';

// Queries
export 'src/query/query.dart';

// Change Detection
export 'src/change_detection/change_detection.dart';

// Systems
export 'src/system/system.dart';
export 'src/system/schedule.dart';
export 'src/system/commands.dart';
export 'src/system/run_condition.dart';
export 'src/system/system_set.dart';

// State Management
export 'src/state/state.dart';

// Hierarchy
export 'src/hierarchy/hierarchy.dart';

// Observers
export 'src/observer/observer.dart';

// Reflection
export 'src/reflection/reflection.dart';

// Resources
export 'src/resource.dart';

// Events
export 'src/event.dart';

// World
export 'src/world.dart';

// App & Plugins
export 'src/app.dart';
export 'src/plugin.dart';
export 'src/plugins/plugins.dart';

// Traits (utility mixins/interfaces)
export 'src/traits/change_tracking.dart';
export 'src/traits/frame_aware.dart';
