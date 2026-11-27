import 'dart:ui' show Offset;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';

/// Where [entity]'s origin lies in world space: its local [Transform2D]
/// translation ([local]) carried up through every ancestor's
/// [Transform2D] along the [Parent] chain.
///
/// A collider spawned as a child (a tilemap's tile and object colliders
/// sit under the map root, which holds the map's position) is placed
/// where it's drawn, not at its local offset from the parent. Computed
/// from the local transforms, so it's current within the tick even before
/// `TransformPropagateSystem` has run. Only the origin is carried: shapes
/// stay axis-aligned and unscaled, whatever the ancestors' rotation or
/// scale.
Offset worldOrigin(World world, Entity entity, Transform2D local) {
  var x = local.translation.x;
  var y = local.translation.y;
  var parent = world.get<Parent>(entity);
  // Bounded, so a broken (cyclic) hierarchy can't hang the physics step.
  for (var depth = 0; parent != null && depth < 64; depth++) {
    final t = world.get<Transform2D>(parent.entity);
    if (t != null &&
        t.rotation == 0 &&
        t.skew == 0 &&
        t.scale.x == 1 &&
        t.scale.y == 1) {
      x += t.translation.x;
      y += t.translation.y;
    } else if (t != null) {
      final m = t.toMatrix().storage;
      final nx = m[0] * x + m[3] * y + m[6];
      final ny = m[1] * x + m[4] * y + m[7];
      x = nx;
      y = ny;
    }
    parent = world.get<Parent>(parent.entity);
  }
  return Offset(x, y);
}
