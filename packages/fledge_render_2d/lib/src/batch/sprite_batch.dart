import 'dart:ui' show Color, Offset, Rect;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:vector_math/vector_math.dart';

import '../render/stages/render_schedule.dart';
import '../render/world/render_world.dart';
import '../sprite/extracted_sprite.dart';
import '../sprite/sprite.dart';

/// A single sprite instance in a batch.
class SpriteInstance {
  /// Source rectangle in the texture.
  final Rect sourceRect;

  /// Destination rectangle on screen (before transform).
  final Rect destRect;

  /// Transformation matrix.
  final Matrix3 transform;

  /// Tint color.
  final Color color;

  /// Rotation in radians (additional to transform).
  final double rotation;

  /// Packed flip flags: bit 0 = flipX, bit 1 = flipY. Handed through
  /// to `BackendSpriteData` on the way to the drawer.
  final int flipFlags;

  /// Creates a sprite instance.
  const SpriteInstance({
    required this.sourceRect,
    required this.destRect,
    required this.transform,
    required this.color,
    this.rotation = 0,
    this.flipFlags = 0,
  });
}

/// A batch of sprites sharing the same texture.
///
/// Batching sprites by texture reduces draw calls and improves
/// rendering performance. [SpriteBatchSystem] emits one batch per
/// contiguous same-texture run in draw order, so the same texture can
/// appear in several batches when other textures interleave with it.
class SpriteBatch {
  /// The shared texture for all sprites in this batch.
  final TextureHandle texture;

  /// The sprite instances.
  final List<SpriteInstance> instances = [];

  /// Creates an empty sprite batch.
  SpriteBatch(this.texture);

  /// Add a sprite instance to the batch.
  void add(SpriteInstance instance) {
    instances.add(instance);
  }

  /// Clear all instances.
  void clear() {
    instances.clear();
  }

  /// Number of sprites in the batch.
  int get length => instances.length;

  /// Whether the batch is empty.
  bool get isEmpty => instances.isEmpty;

  /// Whether the batch has sprites.
  bool get isNotEmpty => instances.isNotEmpty;
}

/// Collection of sprite batches in draw order.
///
/// [all] is ordered back to front: drawing the batches in list order
/// (and each batch's instances in order) reproduces the sprites' sort
/// order. A texture may occur in more than one batch.
class SpriteBatches {
  final List<SpriteBatch> _batches;

  /// Creates sprite batches from a list.
  SpriteBatches(this._batches);

  /// All batches.
  List<SpriteBatch> get all => _batches;

  /// Total number of sprites across all batches.
  int get totalSprites => _batches.fold(0, (sum, batch) => sum + batch.length);

  /// Number of batches (draw calls).
  int get batchCount => _batches.length;
}

/// System that batches extracted sprites for efficient rendering.
///
/// This system runs in the queue stage and:
/// 1. Collects all extracted sprites
/// 2. Sorts them into draw order ([ExtractedSprite.sortByDrawOrder])
/// 3. Groups each contiguous same-texture run into a batch
///
/// Only *contiguous* runs are merged, so painter's order is preserved
/// across textures (A, B, A by y stays three batches, drawn in that
/// order). This is the same strategy as `renderSpritesToDrawer`; when
/// every sprite shares a texture, or the textures are already
/// separated by the sort order, it yields the minimum number of
/// batches (one per run).
class SpriteBatchSystem implements RenderSystem {
  @override
  String get name => 'sprite_batch';

  @override
  Future<void> run(World mainWorld, RenderWorld renderWorld) async {
    final batches = <SpriteBatch>[];

    // Collect and sort sprites
    final sprites = <ExtractedSprite>[];
    for (final (_, sprite) in renderWorld.query1<ExtractedSprite>().iter()) {
      sprites.add(sprite);
    }

    // Sort into draw order: sort key, then the unclamped precise
    // sub-order (Y-sorting for typical 2D), stable for full ties.
    ExtractedSprite.sortByDrawOrder(sprites);

    // Group contiguous same-texture runs into batches. Grouping by
    // texture across the whole frame would hoist every later sprite of
    // a texture underneath sprites of other textures it should cover.
    SpriteBatch? batch;
    for (final sprite in sprites) {
      if (batch == null || batch.texture.id != sprite.texture.id) {
        batch = SpriteBatch(sprite.texture);
        batches.add(batch);
      }

      // Compute destination rect based on size and anchor. Anchor is
      // normalised in [0..1] and describes where inside the sprite
      // the entity's transform points; the local destRect extends
      // AWAY from that anchor. Feet anchor (0.5, 1.0) should have
      // the sprite's bottom edge at the entity position → the rect's
      // centre is `size.y / 2` ABOVE origin, hence `(0.5 - anchor)`.
      final anchorOffsetX = (0.5 - sprite.anchor.x) * sprite.size.x;
      final anchorOffsetY = (0.5 - sprite.anchor.y) * sprite.size.y;

      final destRect = Rect.fromCenter(
        center: Offset(anchorOffsetX, anchorOffsetY),
        width: sprite.size.x,
        height: sprite.size.y,
      );

      // Flip is expressed via bit flags on the backend data, not by
      // inverting the source rect — Skia rejects inverted srcRects
      // and the RSTransform path can't represent a single-axis
      // mirror. The canvas drawer mirrors flipped sprites in local space.
      batch.add(
        SpriteInstance(
          sourceRect: sprite.sourceRect,
          destRect: destRect,
          transform: sprite.transform,
          color: sprite.color,
          flipFlags: sprite.flipFlags,
        ),
      );
    }

    // Store batches as resource
    renderWorld.insertResource(SpriteBatches(batches));
  }
}
