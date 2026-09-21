import 'dart:ui' show Canvas, Color, Rect;

import 'package:vector_math/vector_math.dart';

import '../batch/sprite_batch.dart';
import '../render/extract/camera_view.dart';
import '../render/graph/render_node.dart';
import '../render/graph/slot.dart';
import '../render/world/render_world.dart';
import 'sprite.dart';

/// Render node that draws sprite batches.
///
/// This node reads the camera view from input and renders all
/// sprite batches from the render world.
class SpriteRenderNode implements RenderNode {
  @override
  String get name => 'sprite_render_2d';

  @override
  List<SlotInfo> get inputs => const [
    SlotInfo(name: 'view', type: SlotType.camera, required: false),
  ];

  @override
  List<SlotInfo> get outputs => const [];

  @override
  void run(RenderGraphContext graph, Object context) {
    if (context is! SpriteRenderContext) {
      throw ArgumentError(
        'SpriteRenderNode requires SpriteRenderContext, got ${context.runtimeType}',
      );
    }

    final cameraView = graph.getInput<CameraView>('view');
    final batches = context.renderWorld.getResource<SpriteBatches>();

    if (batches == null) return;

    // Draw each batch
    for (final batch in batches.all) {
      if (batch.isEmpty) continue;

      // Convert to backend format
      final backendSprites = <BackendSpriteData>[];
      for (final instance in batch.instances) {
        backendSprites.add(
          BackendSpriteData(
            sourceRect: instance.sourceRect,
            destRect: instance.destRect,
            transform: instance.transform,
            color: instance.color,
            viewProjection: cameraView?.viewProjection,
          ),
        );
      }

      // Submit to renderer
      context.drawSpriteBatch(batch.texture, backendSprites);
    }
  }
}

/// Executes an atlas-batched sprite draw. Backend-owned.
///
/// Concrete implementations live in `lib/src/backend/`:
/// [CanvasSpriteDrawer] (default) and [GpuSpriteDrawer] (stub). A
/// drawer is installed as a resource by [RenderPlugin] based on the
/// [RenderBackend] selected on plugin construction.
abstract class SpriteDrawer {
  /// Draw a batch of sprites sharing [texture].
  ///
  /// Called once per batch per frame from [SpriteRenderNode]. Empty
  /// batches must be safe (implementations should no-op on empty
  /// input and MUST NOT issue a backend draw call for zero sprites).
  void drawSpriteBatch(TextureHandle texture, List<BackendSpriteData> batch);
}

/// Context for sprite rendering.
class SpriteRenderContext {
  /// The render world with extracted sprites.
  final RenderWorld renderWorld;

  /// Backend drawer that executes the atlas draw.
  final SpriteDrawer drawer;

  /// Live canvas for the current frame. Only populated when the
  /// backend is [RenderBackend.canvas] and the outer widget passes
  /// its `Canvas` down per `paint()` call.
  ///
  /// Nothing in [SpriteRenderNode] reads this — the drawer holds its
  /// own canvas reference. It is exposed here so a future node
  /// (e.g. a custom UI overlay) can share the same canvas without
  /// re-plumbing.
  final Canvas? canvas;

  /// Creates a sprite render context.
  const SpriteRenderContext({
    required this.renderWorld,
    required this.drawer,
    this.canvas,
  });

  /// Draw a sprite batch through the installed [drawer].
  void drawSpriteBatch(TextureHandle texture, List<BackendSpriteData> batch) {
    drawer.drawSpriteBatch(texture, batch);
  }
}

/// Sprite data for backend rendering. Immutable.
///
/// The 2D sprite pipeline produces one instance of this per rendered
/// sprite and hands a `List<BackendSpriteData>` to the current
/// [SpriteDrawer]. Fields were previously typed `dynamic`; Phase 3a
/// tightens them so the backend contract is checked at compile time.
class BackendSpriteData {
  /// Source rectangle in the texture (pixel-space).
  final Rect sourceRect;

  /// Destination rectangle in local space, before [transform] is
  /// applied. Centred on the sprite's anchor offset.
  final Rect destRect;

  /// Local-to-world transform for this sprite.
  final Matrix3 transform;

  /// Tint colour applied by the backend.
  final Color color;

  /// Optional view-projection matrix from the active camera. `null`
  /// means "no camera — draw in raw world space." Canvas backends
  /// apply this either as a pre-multiply or via `canvas.transform`.
  final Matrix4? viewProjection;

  /// Creates backend sprite data.
  const BackendSpriteData({
    required this.sourceRect,
    required this.destRect,
    required this.transform,
    required this.color,
    this.viewProjection,
  });
}
