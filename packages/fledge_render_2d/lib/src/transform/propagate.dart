import 'dart:math' as math;

import 'package:fledge_ecs/fledge_ecs.dart';

import 'global_transform.dart';
import 'transform2d.dart';

/// System that computes [GlobalTransform2D] from [Transform2D] down the
/// [Parent]/[Children] hierarchy.
///
/// Walks from the roots once, so every entity is computed at most once per
/// run, and writes each matrix in place (no allocation). An entity whose
/// local transform and parent are unchanged since its last run is skipped:
/// static scenery costs a comparison, not a matrix multiply. Children of an
/// entity that has a [GlobalTransform2D] but no [Transform2D] (one whose
/// global is set by hand) are recomputed every run, since that matrix
/// can't be tracked.
class TransformPropagateSystem implements System {
  static const String systemName = 'transform_propagate';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
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
  void run(World world) {
    // Roots seen for the first time get their global transform.
    for (final (entity, _)
        in world
            .query1<Transform2D>(
              filter: const And<(Without<Parent>, Without<GlobalTransform2D>)>([
                Without<Parent>(),
                Without<GlobalTransform2D>(),
              ]),
            )
            .iter()) {
      world.insert(entity, GlobalTransform2D());
    }
    // Roots without children (most of a scene: props, tiles' owners).
    for (final (_, transform, global)
        in world
            .query2<Transform2D, GlobalTransform2D>(
              filter: const And<(Without<Parent>, Without<Children>)>([
                Without<Parent>(),
                Without<Children>(),
              ]),
            )
            .iter()) {
      _computeRoot(global, transform);
    }
    // Roots with children, and everything below them.
    for (final (_, transform, global, children)
        in world
            .query3<Transform2D, GlobalTransform2D, Children>(
              filter: const Without<Parent>(),
            )
            .iter()) {
      _computeRoot(global, transform);
      _propagate(world, global, children, force: false);
    }
    // Roots whose global is set by hand: their children follow it.
    for (final (_, children, global)
        in world
            .query2<Children, GlobalTransform2D>(
              filter: const And<(Without<Parent>, Without<Transform2D>)>([
                Without<Parent>(),
                Without<Transform2D>(),
              ]),
            )
            .iter()) {
      _propagate(world, global, children, force: true);
    }
  }

  static GlobalTransform2D _globalOf(World world, Entity entity) {
    final existing = world.get<GlobalTransform2D>(entity);
    if (existing != null) return existing;
    final created = GlobalTransform2D();
    world.insert(entity, created);
    return created;
  }

  static bool _unchanged(
    GlobalTransform2D g,
    Transform2D t,
    GlobalTransform2D? parent,
  ) =>
      identical(g.sourceParent, parent) &&
      g.sourceParentVersion == (parent?.version ?? 0) &&
      g.sourceX == t.translation.x &&
      g.sourceY == t.translation.y &&
      g.sourceRotation == t.rotation &&
      g.sourceScaleX == t.scale.x &&
      g.sourceScaleY == t.scale.y &&
      g.sourceSkew == t.skew;

  static void _remember(
    GlobalTransform2D g,
    Transform2D t,
    GlobalTransform2D? parent,
  ) {
    g
      ..sourceParent = parent
      ..sourceParentVersion = parent?.version ?? 0
      ..sourceX = t.translation.x
      ..sourceY = t.translation.y
      ..sourceRotation = t.rotation
      ..sourceScaleX = t.scale.x
      ..sourceScaleY = t.scale.y
      ..sourceSkew = t.skew
      ..version += 1;
  }

  static void _computeRoot(GlobalTransform2D g, Transform2D t) {
    if (_unchanged(g, t, null)) return;
    final cos = math.cos(t.rotation);
    final sin = math.sin(t.rotation);
    final m = g.matrix.storage;
    m[0] = cos * t.scale.x;
    m[1] = sin * t.scale.x;
    m[2] = 0;
    m[3] = (cos * t.skew - sin) * t.scale.y;
    m[4] = (sin * t.skew + cos) * t.scale.y;
    m[5] = 0;
    m[6] = t.translation.x;
    m[7] = t.translation.y;
    m[8] = 1;
    _remember(g, t, null);
  }

  /// [child] = [parent] × the local transform [t], in place.
  static void _computeChild(
    GlobalTransform2D child,
    GlobalTransform2D parent,
    Transform2D t, {
    required bool force,
  }) {
    if (!force && _unchanged(child, t, parent)) return;
    final cos = math.cos(t.rotation);
    final sin = math.sin(t.rotation);
    final la = cos * t.scale.x, lb = sin * t.scale.x;
    final lc = (cos * t.skew - sin) * t.scale.y;
    final ld = (sin * t.skew + cos) * t.scale.y;
    final lx = t.translation.x, ly = t.translation.y;
    final p = parent.matrix.storage;
    final pa = p[0], pb = p[1], pc = p[3], pd = p[4], px = p[6], py = p[7];
    final m = child.matrix.storage;
    m[0] = pa * la + pc * lb;
    m[1] = pb * la + pd * lb;
    m[2] = 0;
    m[3] = pa * lc + pc * ld;
    m[4] = pb * lc + pd * ld;
    m[5] = 0;
    m[6] = pa * lx + pc * ly + px;
    m[7] = pb * lx + pd * ly + py;
    m[8] = 1;
    _remember(child, t, parent);
  }

  void _propagate(
    World world,
    GlobalTransform2D parent,
    Children children, {
    required bool force,
  }) {
    for (final child in children.children) {
      final local = world.get<Transform2D>(child);
      if (local == null) continue;
      final global = _globalOf(world, child);
      _computeChild(global, parent, local, force: force);
      final grandchildren = world.get<Children>(child);
      if (grandchildren != null) {
        _propagate(world, global, grandchildren, force: false);
      }
    }
  }
}

/// Runs [TransformPropagateSystem] once, outside a schedule.
void propagateTransforms(World world) {
  TransformPropagateSystem().run(world);
}
