import 'dart:ui';

import 'package:vector_math/vector_math_64.dart';

import '../world/render_world.dart';

/// Abstract base class for render layers.
///
/// Render layers provide a clean way to organize rendering into distinct
/// passes, each responsible for a specific type of content (tilemaps, sprites,
/// particles, UI, etc.).
///
/// ## Usage
///
/// Implement [RenderLayer] for each distinct rendering category:
///
/// ```dart
/// class TilemapLayer extends RenderLayer {
///   @override
///   void paint(Canvas canvas, Size size, RenderWorld renderWorld) {
///     final tiles = renderWorld.query1<ExtractedTile>()
///       .iter()
///       .toList()
///       ..sort((a, b) => a.$2.sortKey.compareTo(b.$2.sortKey));
///
///     for (final (_, tile) in tiles) {
///       // Draw tile...
///     }
///   }
/// }
///
/// class SpriteLayer extends RenderLayer {
///   @override
///   void paint(Canvas canvas, Size size, RenderWorld renderWorld) {
///     final sprites = renderWorld.query1<ExtractedSprite>()
///       .iter()
///       .toList()
///       ..sort((a, b) => a.$2.sortKey.compareTo(b.$2.sortKey));
///
///     for (final (_, sprite) in sprites) {
///       // Draw sprite...
///     }
///   }
/// }
/// ```
///
/// ## Composing Layers
///
/// Use [CompositeRenderLayer] or a custom painter to combine layers:
///
/// ```dart
/// class GamePainter extends CustomPainter {
///   final RenderWorld renderWorld;
///   final List<RenderLayer> layers;
///
///   GamePainter(this.renderWorld, {required this.layers});
///
///   @override
///   void paint(Canvas canvas, Size size) {
///     for (final layer in layers) {
///       layer.paint(canvas, size, renderWorld);
///     }
///   }
/// }
///
/// // Usage
/// CustomPaint(
///   painter: GamePainter(
///     renderWorld,
///     layers: [
///       TilemapLayer(),
///       SpriteLayer(),
///       ParticleLayer(),
///       UILayer(),
///     ],
///   ),
/// )
/// ```
///
/// ## Layer Order
///
/// Layers are rendered in the order they appear in the list:
/// - First layer renders at the back (background)
/// - Last layer renders at the front (foreground)
///
/// For entities that need to intermix across layers (e.g., NPCs walking
/// behind trees), consider using layer-encoded sort keys instead of
/// separate layers. See [SortableExtractedData] for sort key patterns.
///
/// See also:
/// - [CompositeRenderLayer] for combining multiple layers
/// - [SortableExtractedData] for sort key patterns
/// - [RenderWorld] for querying extracted data
abstract class RenderLayer {
  /// Paints this layer's content to the canvas.
  ///
  /// Implementations should:
  /// 1. Query the [renderWorld] for their specific extracted component type
  /// 2. Sort entities if needed (typically by [SortableExtractedData.sortKey])
  /// 3. Draw each entity to the [canvas]
  ///
  /// The [size] parameter provides the available drawing area.
  void paint(Canvas canvas, Size size, RenderWorld renderWorld);
}

/// A render layer that composes multiple child layers.
///
/// Renders child layers in order, from first (back) to last (front).
///
/// ```dart
/// final gameLayer = CompositeRenderLayer([
///   BackgroundLayer(),
///   TilemapLayer(),
///   EntityLayer(),
///   ParticleLayer(),
/// ]);
///
/// // In your painter
/// gameLayer.paint(canvas, size, renderWorld);
/// ```
class CompositeRenderLayer extends RenderLayer {
  /// The child layers to render, in order.
  final List<RenderLayer> layers;

  /// Creates a composite layer from the given child layers.
  CompositeRenderLayer(this.layers);

  @override
  void paint(Canvas canvas, Size size, RenderWorld renderWorld) {
    for (final layer in layers) {
      layer.paint(canvas, size, renderWorld);
    }
  }
}

/// A render layer that applies a transformation before rendering.
///
/// Useful for camera transforms, scrolling, or zoom effects.
///
/// ```dart
/// final cameraLayer = TransformedRenderLayer(
///   transform: cameraMatrix,
///   child: gameContentLayer,
/// );
/// ```
class TransformedRenderLayer extends RenderLayer {
  /// The transformation matrix to apply.
  final Matrix4 transform;

  /// The child layer to render with the transformation.
  final RenderLayer child;

  /// Creates a transformed render layer.
  TransformedRenderLayer({
    required this.transform,
    required this.child,
  });

  @override
  void paint(Canvas canvas, Size size, RenderWorld renderWorld) {
    canvas.save();
    canvas.transform(transform.storage);
    child.paint(canvas, size, renderWorld);
    canvas.restore();
  }
}

/// A render layer that clips its content to a rectangle.
///
/// Useful for viewports, split-screen, or UI panels.
///
/// ```dart
/// final viewportLayer = ClippedRenderLayer(
///   clipRect: Rect.fromLTWH(0, 0, 400, 300),
///   child: gameLayer,
/// );
/// ```
class ClippedRenderLayer extends RenderLayer {
  /// The rectangle to clip to.
  final Rect clipRect;

  /// The child layer to render clipped.
  final RenderLayer child;

  /// Creates a clipped render layer.
  ClippedRenderLayer({
    required this.clipRect,
    required this.child,
  });

  @override
  void paint(Canvas canvas, Size size, RenderWorld renderWorld) {
    canvas.save();
    canvas.clipRect(clipRect);
    child.paint(canvas, size, renderWorld);
    canvas.restore();
  }
}

/// A render layer that conditionally renders based on a predicate.
///
/// Useful for debug overlays, pause screens, or optional effects.
///
/// ```dart
/// final debugLayer = ConditionalRenderLayer(
///   condition: () => showDebugOverlay,
///   child: DebugInfoLayer(),
/// );
/// ```
class ConditionalRenderLayer extends RenderLayer {
  /// The condition that determines whether to render.
  final bool Function() condition;

  /// The child layer to conditionally render.
  final RenderLayer child;

  /// Creates a conditional render layer.
  ConditionalRenderLayer({
    required this.condition,
    required this.child,
  });

  @override
  void paint(Canvas canvas, Size size, RenderWorld renderWorld) {
    if (condition()) {
      child.paint(canvas, size, renderWorld);
    }
  }
}
