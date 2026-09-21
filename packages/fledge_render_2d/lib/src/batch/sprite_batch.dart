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
/// rendering performance.
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

/// Collection of sprite batches organized by texture.
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
/// 2. Sorts them by sort key
/// 3. Groups them by texture into batches
class SpriteBatchSystem implements RenderSystem {
  @override
  String get name => 'sprite_batch';

  @override
  Future<void> run(World mainWorld, RenderWorld renderWorld) async {
    final batches = <int, SpriteBatch>{};

    // Collect and sort sprites
    final sprites = <ExtractedSprite>[];
    for (final (_, sprite) in renderWorld.query1<ExtractedSprite>().iter()) {
      sprites.add(sprite);
    }

    // Sort by sort key (Y-sorting for typical 2D)
    sprites.sort((a, b) => a.sortKey.compareTo(b.sortKey));

    // Group into batches by texture
    for (final sprite in sprites) {
      final batch = batches.putIfAbsent(
        sprite.texture.id,
        () => SpriteBatch(sprite.texture),
      );

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
      // mirror. The canvas drawer sub-batches by flip flags.
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
    renderWorld.insertResource(SpriteBatches(batches.values.toList()));
  }
}
