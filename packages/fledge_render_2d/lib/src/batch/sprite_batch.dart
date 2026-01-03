import 'dart:ui' show Color, Offset, Rect;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render/fledge_render.dart';
import 'package:vector_math/vector_math.dart';

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

  /// Creates a sprite instance.
  const SpriteInstance({
    required this.sourceRect,
    required this.destRect,
    required this.transform,
    required this.color,
    this.rotation = 0,
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

      // Compute destination rect based on size and anchor
      final anchorOffsetX = (sprite.anchor.x - 0.5) * sprite.size.x;
      final anchorOffsetY = (sprite.anchor.y - 0.5) * sprite.size.y;

      final destRect = Rect.fromCenter(
        center: Offset(anchorOffsetX, anchorOffsetY),
        width: sprite.size.x,
        height: sprite.size.y,
      );

      // Handle flipping by adjusting source rect
      var srcRect = sprite.sourceRect;
      if (sprite.flipX || sprite.flipY) {
        srcRect = Rect.fromLTRB(
          sprite.flipX ? srcRect.right : srcRect.left,
          sprite.flipY ? srcRect.bottom : srcRect.top,
          sprite.flipX ? srcRect.left : srcRect.right,
          sprite.flipY ? srcRect.top : srcRect.bottom,
        );
      }

      batch.add(SpriteInstance(
        sourceRect: srcRect,
        destRect: destRect,
        transform: sprite.transform,
        color: sprite.color,
      ));
    }

    // Store batches as resource
    renderWorld.insertResource(SpriteBatches(batches.values.toList()));
  }
}
