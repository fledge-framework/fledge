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

        // Y-based sub-order, using exactly the sprite convention
        // (`SpriteExtractor` / `AtlasSpriteExtractor`) when the emitter
        // didn't specify a sub-order: the packed integer is
        // `DrawLayerExtension.ySortSubOrder(y)` and the unclamped
        // tie-breaker is `y * ySortScale`. A particle and a sprite in
        // the same layer therefore interleave by y, and the precise
        // sub-order still orders particles closer than 0.1 px apart or
        // outside the packed 0..9,999.9 window.
        final ySorted = explicitSub == 0;
        final y = p.position.y;
        final sub = ySorted ? DrawLayerExtension.ySortSubOrder(y) : explicitSub;
        final sortKey = layer.sortKey(subOrder: sub);

        renderWorld.addSprite(
          ExtractedSprite(
            entity: entity,
            texture: texture,
            sourceRect: sourceRect,
            transform: _matrixFor(p),
            color: p.color,
            sortKey: sortKey,
            layer: layer,
            layerSubOrder: explicitSub,
            preciseSubOrder: ySorted ? y * DrawLayerExtension.ySortScale : null,
            anchor: _centerAnchor.clone(),
            size: Vector2(size, size),
          ),
        );
      }
    }
  }

  /// Build a `Matrix3` for a particle without importing Transform2D.
  ///
  /// Rotation and translation only: the particle's size is the
  /// sprite's `size` (its quad), and the sprite pipeline scales the quad
  /// by the transform as well, so a scale here would draw it at
  /// `size * size`. Rotation-then-translate for a Y-down 2D world.
  static Matrix3 _matrixFor(Particle p) {
    final cos = math.cos(p.rotation);
    final sin = math.sin(p.rotation);
    // Column-major 3x3: [m0..m2, m3..m5, m6..m8] where column-2 is
    // translation.
    final m = Matrix3.zero();
    m[0] = cos;
    m[1] = sin;
    m[2] = 0.0;
    m[3] = -sin;
    m[4] = cos;
    m[5] = 0.0;
    m[6] = p.position.x;
    m[7] = p.position.y;
    m[8] = 1.0;
    return m;
  }
}
