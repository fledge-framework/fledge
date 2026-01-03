import 'package:fledge_render/fledge_render.dart';

import '../batch/sprite_batch.dart';
import '../camera/camera2d.dart';

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
          'SpriteRenderNode requires SpriteRenderContext, got ${context.runtimeType}');
    }

    final cameraView = graph.getInput<CameraView>('view');
    final batches = context.renderWorld.getResource<SpriteBatches>();

    if (batches == null) return;

    // Get the frame context for drawing
    final frame = context.frameContext;
    if (frame == null) return;

    // Draw each batch
    for (final batch in batches.all) {
      if (batch.isEmpty) continue;

      // Convert to backend format
      final backendSprites = <BackendSpriteData>[];
      for (final instance in batch.instances) {
        backendSprites.add(BackendSpriteData(
          sourceRect: instance.sourceRect,
          destRect: instance.destRect,
          transform: instance.transform,
          color: instance.color,
          viewProjection: cameraView?.viewProjection,
        ));
      }

      // Submit to renderer
      context.drawSpriteBatch(batch.texture, backendSprites);
    }
  }
}

/// Context for sprite rendering.
class SpriteRenderContext {
  /// The render world with extracted sprites.
  final RenderWorld renderWorld;

  /// The frame context for issuing draw calls (may be null in tests).
  final dynamic frameContext;

  /// Callback to draw a sprite batch.
  final void Function(dynamic texture, List<BackendSpriteData> sprites)?
      _drawCallback;

  /// Creates a sprite render context.
  SpriteRenderContext({
    required this.renderWorld,
    this.frameContext,
    void Function(dynamic texture, List<BackendSpriteData> sprites)?
        drawCallback,
  }) : _drawCallback = drawCallback;

  /// Draw a sprite batch.
  void drawSpriteBatch(dynamic texture, List<BackendSpriteData> sprites) {
    _drawCallback?.call(texture, sprites);
  }
}

/// Sprite data for backend rendering.
///
/// Contains all the information needed by the backend to draw a sprite.
class BackendSpriteData {
  /// Source rectangle in the texture.
  final dynamic sourceRect;

  /// Destination rectangle on screen.
  final dynamic destRect;

  /// Transformation matrix.
  final dynamic transform;

  /// Tint color.
  final dynamic color;

  /// View-projection matrix from camera.
  final dynamic viewProjection;

  /// Creates backend sprite data.
  BackendSpriteData({
    required this.sourceRect,
    required this.destRect,
    required this.transform,
    required this.color,
    this.viewProjection,
  });
}
