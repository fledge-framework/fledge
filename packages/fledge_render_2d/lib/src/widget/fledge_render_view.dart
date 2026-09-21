import 'dart:ui' show Canvas, Color, Offset, Paint, Rect;

import 'package:fledge_ecs/fledge_ecs.dart' show App;
import 'package:flutter/widgets.dart'
    show
        BuildContext,
        CustomPaint,
        CustomPainter,
        SizedBox,
        Size,
        StatelessWidget,
        Widget;

import '../backend/canvas_render_context.dart' show CanvasSpriteDrawer;
import '../render/world/render_world.dart' show RenderWorld;
import '../sprite/extracted_sprite.dart' show ExtractedSprite;
import '../sprite/sprite.dart' show TextureHandle;
import '../sprite/sprite_render_node.dart' show BackendSpriteData, SpriteDrawer;

/// A widget that paints an [App]'s render world through the installed
/// [SpriteDrawer].
///
/// This is the widget-side plumbing for the sprite pipeline: it owns
/// the frame-lifecycle handshake (`beginFrame` / `endFrame`) with
/// [CanvasSpriteDrawer], reads [ExtractedSprite]s from the app's
/// [RenderWorld], sorts them by [ExtractedSprite.sortKey], groups
/// contiguous same-texture runs into batches, and submits each batch
/// to [SpriteDrawer.drawSpriteBatch].
///
/// Callers still drive the game loop themselves (e.g. via an
/// `AnimationController` ticker calling `App.tick`). `FledgeRenderView`
/// only paints; it does not tick.
///
/// ## Repaint policy
///
/// `shouldRepaint` currently returns `true`, so the view repaints
/// every time the enclosing widget rebuilds. A change-detection-aware
/// policy is a follow-up; correctness first.
class FledgeRenderView extends StatelessWidget {
  /// The Fledge app whose render world will be painted.
  final App app;

  /// Optional solid fill drawn before sprites. `null` = transparent.
  final Color? backgroundColor;

  /// Creates a render view.
  const FledgeRenderView({super.key, required this.app, this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    // `SizedBox.expand` forces the CustomPaint to occupy its
    // parent's constraints. Without it, a childless `CustomPaint`
    // collapses to `Size.zero` and the painter is called with an
    // empty rect — silent zero-pixel rendering.
    return SizedBox.expand(
      child: CustomPaint(
        painter: _FledgeRenderPainter(
          app: app,
          backgroundColor: backgroundColor,
        ),
      ),
    );
  }
}

class _FledgeRenderPainter extends CustomPainter {
  final App app;
  final Color? backgroundColor;

  _FledgeRenderPainter({required this.app, required this.backgroundColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (backgroundColor != null) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = backgroundColor!,
      );
    }

    final drawer = app.world.getResource<SpriteDrawer>();
    final renderWorld = app.world.getResource<RenderWorld>();
    if (drawer == null || renderWorld == null) return;

    // Canvas backend needs a live `Canvas` handle per frame. Other
    // backends (e.g. the GPU stub) ignore this handshake.
    final canvasDrawer = drawer is CanvasSpriteDrawer ? drawer : null;
    canvasDrawer?.beginFrame(canvas);
    try {
      renderSpritesToDrawer(renderWorld, drawer);
    } finally {
      canvasDrawer?.endFrame();
    }
  }

  @override
  bool shouldRepaint(covariant _FledgeRenderPainter oldDelegate) => true;
}

/// Iterate every [ExtractedSprite] in [renderWorld], sort them by
/// [ExtractedSprite.sortKey], group contiguous same-texture runs
/// into batches, and submit each batch to [drawer].
///
/// Exposed as a top-level function so `SpriteRenderNode` and a
/// widget-side painter can share the same batching logic. The
/// one-pass "contiguous same-texture run" strategy preserves the
/// sort order that [ExtractedSprite.sortKey] encodes (layer + Y
/// sub-order) while minimising draw calls: as long as consecutive
/// sprites share a texture, they collapse into one
/// `drawSpriteBatch` call.
void renderSpritesToDrawer(RenderWorld renderWorld, SpriteDrawer drawer) {
  final sprites = <ExtractedSprite>[];
  for (final (_, sprite) in renderWorld.query1<ExtractedSprite>().iter()) {
    sprites.add(sprite);
  }
  if (sprites.isEmpty) return;
  sprites.sort((a, b) => a.sortKey.compareTo(b.sortKey));

  var i = 0;
  while (i < sprites.length) {
    final texture = sprites[i].texture;
    final batch = <BackendSpriteData>[];
    while (i < sprites.length && sprites[i].texture.id == texture.id) {
      batch.add(_toBackendSprite(sprites[i]));
      i++;
    }
    drawer.drawSpriteBatch(texture, batch);
  }
}

/// Build a [BackendSpriteData] from an [ExtractedSprite], mirroring
/// `SpriteBatchSystem`'s destination-rect + flip handling so the
/// widget path produces identical geometry to the render-graph
/// path.
BackendSpriteData _toBackendSprite(ExtractedSprite s) {
  final anchorOffsetX = (s.anchor.x - 0.5) * s.size.x;
  final anchorOffsetY = (s.anchor.y - 0.5) * s.size.y;
  final destRect = Rect.fromCenter(
    center: Offset(anchorOffsetX, anchorOffsetY),
    width: s.size.x,
    height: s.size.y,
  );

  var srcRect = s.sourceRect;
  if (s.flipX || s.flipY) {
    srcRect = Rect.fromLTRB(
      s.flipX ? srcRect.right : srcRect.left,
      s.flipY ? srcRect.bottom : srcRect.top,
      s.flipX ? srcRect.left : srcRect.right,
      s.flipY ? srcRect.top : srcRect.bottom,
    );
  }

  return BackendSpriteData(
    sourceRect: srcRect,
    destRect: destRect,
    transform: s.transform,
    color: s.color,
  );
}

/// Reserved texture id for a "solid colour" 1×1 white pixel that
/// callers register at startup via
/// [CanvasSpriteDrawer.registerTexture]. Games that only need
/// solid-colour rectangles (e.g. the Drifter demo) tint this pixel
/// via `Sprite.color`. Real texture ids start at 1.
const int kSolidColorTextureId = 0;

/// A [TextureHandle] pointing at the 1×1 solid-colour texture
/// convention. Combined with `Sprite.color` this replaces the
/// ad-hoc `Canvas.drawRect` / `drawCircle` calls a game would
/// otherwise need for solid-colour rendering.
const TextureHandle kSolidColorTexture = TextureHandle(
  id: kSolidColorTextureId,
  width: 1,
  height: 1,
);
