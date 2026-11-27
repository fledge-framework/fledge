import 'dart:math' as math;

import 'package:fledge_ecs/fledge_ecs.dart';

import 'global_transform.dart';
import 'static_transform.dart';
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
///
/// A [StaticTransform] root and its subtree are computed once, then marked
/// [TransformFrozen] and never visited again, so scenery that never moves
/// costs nothing per frame (bumping [StaticTransforms.generation]). Debug
/// builds check every [frozenCheckInterval] runs that frozen entities
/// haven't moved.
class TransformPropagateSystem implements System {
  static const String systemName = 'transform_propagate';

  /// Runs between debug checks that frozen entities kept their transforms.
  static const frozenCheckInterval = 120;

  int _runs = 0;

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
    // Static roots are done once, below.
    for (final (_, transform, global)
        in world
            .query2<Transform2D, GlobalTransform2D>(
              filter:
                  const And<
                    (
                      Without<Parent>,
                      Without<Children>,
                      Without<StaticTransform>,
                    )
                  >([
                    Without<Parent>(),
                    Without<Children>(),
                    Without<StaticTransform>(),
                  ]),
            )
            .iter()) {
      _computeRoot(global, transform);
    }
    // Roots with children, and everything below them.
    for (final (_, transform, global, children)
        in world
            .query3<Transform2D, GlobalTransform2D, Children>(
              filter: const And<(Without<Parent>, Without<StaticTransform>)>([
                Without<Parent>(),
                Without<StaticTransform>(),
              ]),
            )
            .iter()) {
      _computeRoot(global, transform);
      _propagate(world, global, children, force: false);
    }
    // Static roots not frozen yet: computed with their subtrees once, then
    // frozen (skipped from now on).
    List<Entity>? freeze;
    for (final (entity, transform, global)
        in world
            .query2<Transform2D, GlobalTransform2D>(
              filter:
                  const And<
                    (
                      With<StaticTransform>,
                      Without<Parent>,
                      Without<TransformFrozen>,
                    )
                  >([
                    With<StaticTransform>(),
                    Without<Parent>(),
                    Without<TransformFrozen>(),
                  ]),
            )
            .iter()) {
      _computeRoot(global, transform);
      final children = world.get<Children>(entity);
      if (children != null) _propagate(world, global, children, force: false);
      (freeze ??= []).add(entity);
    }
    // Newcomers under frozen entities (a child spawned under static
    // scenery after it was frozen): computed from their frozen parent once
    // and frozen with it, else nothing would ever compute them.
    final late = _lateChildren(world);
    for (final (child, parent) in late) {
      final local = world.get<Transform2D>(child);
      final parentGlobal = world.get<GlobalTransform2D>(parent);
      if (local == null || parentGlobal == null) continue;
      final global = _globalOf(world, child);
      _computeChild(global, parentGlobal, local, force: true);
      final grandchildren = world.get<Children>(child);
      if (grandchildren != null) {
        _propagate(world, global, grandchildren, force: true);
      }
      (freeze ??= []).add(child);
    }
    if (freeze != null) {
      for (final root in freeze) {
        _freeze(world, root);
      }
      var frozen = world.getResource<StaticTransforms>();
      if (frozen == null) {
        frozen = StaticTransforms();
        world.insertResource(frozen);
      }
      frozen.generation++;
    }
    assert(() {
      if (++_runs % frozenCheckInterval == 0) _checkFrozen(world);
      return true;
    }());
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

  /// Entities not frozen whose parent is, each with that parent: children
  /// added under static scenery after it was frozen. One whose global
  /// transform was computed under a parent already (it has a source
  /// parent) isn't new; only those never computed are checked for a frozen
  /// parent.
  static List<(Entity, Entity)> _lateChildren(World world) {
    final out = <(Entity, Entity)>[];
    for (final (entity, _, parent, global)
        in world
            .query3<Transform2D, Parent, GlobalTransform2D>(
              filter: const Without<TransformFrozen>(),
            )
            .iter()) {
      if (global.sourceParent != null) continue;
      if (world.has<TransformFrozen>(parent.entity)) {
        out.add((entity, parent.entity));
      }
    }
    for (final (entity, _, parent)
        in world
            .query2<Transform2D, Parent>(
              filter:
                  const And<
                    (Without<TransformFrozen>, Without<GlobalTransform2D>)
                  >([Without<TransformFrozen>(), Without<GlobalTransform2D>()]),
            )
            .iter()) {
      if (world.has<TransformFrozen>(parent.entity)) {
        out.add((entity, parent.entity));
      }
    }
    return out;
  }

  /// Marks [entity] and everything below it [TransformFrozen].
  static void _freeze(World world, Entity entity) {
    if (!world.isAlive(entity)) return;
    world.insert(entity, const TransformFrozen());
    final children = world.get<Children>(entity);
    if (children == null) return;
    for (final child in [...children.children]) {
      _freeze(world, child);
    }
  }

  /// Debug only: fails if a frozen entity's local transform changed since
  /// it was frozen (it broke [StaticTransform]'s contract and would be
  /// drawn where it was).
  static void _checkFrozen(World world) {
    for (final (entity, t, g)
        in world
            .query2<Transform2D, GlobalTransform2D>(
              filter: const With<TransformFrozen>(),
            )
            .iter()) {
      final same =
          g.sourceX == t.translation.x &&
          g.sourceY == t.translation.y &&
          g.sourceRotation == t.rotation &&
          g.sourceScaleX == t.scale.x &&
          g.sourceScaleY == t.scale.y &&
          g.sourceSkew == t.skew;
      if (!same) {
        throw StateError(
          'Entity $entity has StaticTransform (or is under a static root) '
          'but its Transform2D changed after it was frozen. Scenery that '
          'moves must not be marked StaticTransform.',
        );
      }
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
