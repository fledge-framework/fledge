import 'dart:math' as math;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:vector_math/vector_math.dart';

import 'emitter.dart';
import 'particle.dart';

/// Extractor that turns every live [Particle] into an
/// [ExtractedSprite] on the render world.
///
/// The design decision here is to reuse `ExtractedSprite` rather than
/// invent a `ParticleRenderNode`: particles ARE sprites with tint,
/// texture, and transform. Slotting them into the existing sprite
/// render path avoids a whole second draw path and gives correct
/// compositing against character sprites through the reserved
/// `DrawLayer.particles` sort range.
///
/// Alpha and additive blending beyond what [Sprite.color] expresses
/// aren't reachable through the sprite path; if a game needs those it
/// can build its own extractor + render node against the same
/// [ParticleEmitter] component.
class ParticleExtractor extends Extractor {
  static final Vector2 _centerAnchor = Vector2(0.5, 0.5);

  @override
  void extract(World mainWorld, RenderWorld renderWorld) {
    for (final (entity, emitter, _)
        in mainWorld.query2<ParticleEmitter, GlobalTransform2D>().iter()) {
      final texture = emitter.texture;
      final layer = emitter.layer;
      final explicitSub = emitter.layerSubOrder;

      for (final p in emitter.pool.live) {
        final size = p.currentSize;
        final sourceRect = texture.fullRect;

        // Y-based sub-order gives particles the same top-down sort
        // behavior as sprites within DrawLayer.particles when the
        // emitter didn't specify a sub-order.
        final sub = explicitSub != 0
            ? explicitSub
            : (p.position.y * 1000)
                .toInt()
                .clamp(0, DrawLayerExtension.layerMultiplier - 1);
        final sortKey = layer.sortKey(subOrder: sub);

        renderWorld.spawn().insert(ExtractedSprite(
              entity: entity,
              texture: texture,
              sourceRect: sourceRect,
              transform: _matrixFor(p, size),
              color: p.color,
              sortKey: sortKey,
              layer: layer,
              layerSubOrder: explicitSub,
              anchor: _centerAnchor.clone(),
              size: Vector2(size, size),
            ));
      }
    }
  }

  /// Build a `Matrix3` for a particle without importing Transform2D.
  ///
  /// Order matches Transform2D.toMatrix: scale, then rotate, then
  /// translate — same convention as the sprite pipeline expects.
  static Matrix3 _matrixFor(Particle p, double size) {
    final cos = math.cos(p.rotation);
    final sin = math.sin(p.rotation);
    // Column-major 3x3: [m0..m2, m3..m5, m6..m8] where column-2 is
    // translation. Scale collapses to `size` on both axes (particles
    // are square quads). Rotation-then-translate for a Y-down 2D world.
    final m = Matrix3.zero();
    m[0] = cos * size;
    m[1] = sin * size;
    m[2] = 0.0;
    m[3] = -sin * size;
    m[4] = cos * size;
    m[5] = 0.0;
    m[6] = p.position.x;
    m[7] = p.position.y;
    m[8] = 1.0;
    return m;
  }
}
