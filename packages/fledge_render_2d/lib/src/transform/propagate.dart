import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:vector_math/vector_math.dart';

import 'global_transform.dart';
import 'transform2d.dart';

/// System that propagates local transforms through the entity hierarchy
/// to compute global (world-space) transforms.
///
/// This system should run after any transform modifications and before
/// rendering systems that need world-space positions.
///
/// The system:
/// 1. Updates root entities (no parent) - GlobalTransform = LocalTransform
/// 2. Propagates to children - GlobalTransform = Parent.Global * Local
class TransformPropagateSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'transform_propagate',
        writes: {ComponentId.of<GlobalTransform2D>()},
        reads: {
          ComponentId.of<Transform2D>(),
          ComponentId.of<Parent>(),
          ComponentId.of<Children>(),
        },
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) async {
    // First pass: Update root entities (no parent)
    for (final (entity, transform) in world
        .query1<Transform2D>(filter: const Without<Parent>())
        .iter()) {
      final globalMatrix = transform.toMatrix();

      // Get or create GlobalTransform2D
      final existing = world.get<GlobalTransform2D>(entity);
      if (existing != null) {
        existing.matrix.setFrom(globalMatrix);
      } else {
        world.insert(entity, GlobalTransform2D(globalMatrix));
      }
    }

    // Second pass: Propagate to children
    _propagateToChildren(world);
  }

  void _propagateToChildren(World world) {
    // Get all entities with children
    for (final (_, children, parentGlobal) in
        world.query2<Children, GlobalTransform2D>().iter()) {
      for (final childEntity in children.children) {
        final childLocal = world.get<Transform2D>(childEntity);
        if (childLocal == null) continue;

        // Compute child's global transform
        final childMatrix = parentGlobal.matrix * childLocal.toMatrix();

        // Get or create GlobalTransform2D
        final existing = world.get<GlobalTransform2D>(childEntity);
        if (existing != null) {
          existing.matrix.setFrom(childMatrix);
        } else {
          world.insert(childEntity, GlobalTransform2D(childMatrix));
        }

        // Recursively propagate to this child's children
        final childChildren = world.get<Children>(childEntity);
        if (childChildren != null) {
          _propagateFromEntity(world, childEntity, childMatrix);
        }
      }
    }
  }

  void _propagateFromEntity(
      World world, Entity parent, Matrix3 parentMatrix) {
    final children = world.get<Children>(parent);
    if (children == null) return;

    for (final childEntity in children.children) {
      final childLocal = world.get<Transform2D>(childEntity);
      if (childLocal == null) continue;

      // Compute child's global transform
      final childMatrix = parentMatrix * childLocal.toMatrix();

      // Get or create GlobalTransform2D
      final existing = world.get<GlobalTransform2D>(childEntity);
      if (existing != null) {
        existing.matrix.setFrom(childMatrix);
      } else {
        world.insert(childEntity, GlobalTransform2D(childMatrix));
      }

      // Recursively propagate to grandchildren
      _propagateFromEntity(world, childEntity, childMatrix);
    }
  }
}

/// Convenience function to create and run the transform propagation system.
void propagateTransforms(World world) {
  TransformPropagateSystem().run(world);
}
