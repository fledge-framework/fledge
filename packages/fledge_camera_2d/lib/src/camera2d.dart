import 'dart:ui' show Size;

import 'package:fledge_render_2d/fledge_render_2d.dart'
    show GlobalTransform2D, RenderSize, Viewport;
import 'package:vector_math/vector_math.dart';

import 'projection.dart';

/// 2D camera component.
///
/// Cameras determine what portion of the world is visible and how
/// it maps to the screen. Attach to an entity with `Transform2D`
/// to control the camera position.
///
/// ## Pixel-Perfect Rendering
///
/// For pixel art games or tile-based games, enable [pixelPerfect] to
/// prevent visual artifacts like tile seams. When enabled, the camera
/// position should be snapped to whole pixels before rendering.
///
/// Use the `PixelPerfectVector2` extension on `Vector2` in your
/// camera follow logic:
/// ```dart
/// if (camera.pixelPerfect) {
///   transform.translation.snapToPixel();
/// }
/// ```
///
/// Example:
/// ```dart
/// world.spawn()
///   ..insert(Transform2D.from(0, 0))
///   ..insert(Camera2D(
///     projection: OrthographicProjection(viewportHeight: 20),
///     pixelPerfect: true,
///   ));
/// ```
class Camera2D {
  /// Projection settings.
  ///
  /// Any [Projection] can be used — [OrthographicProjection] (default),
  /// [IsometricProjection], [ObliqueProjection], or a custom
  /// implementation.
  Projection projection;

  /// Render order (lower = renders first, useful for split screen).
  int order;

  /// Viewport rectangle (normalized 0-1, null = full screen).
  Viewport viewport;

  /// Is this the active camera?
  bool isActive;

  /// Enable pixel-perfect rendering.
  ///
  /// When true, indicates that camera position should be snapped to
  /// whole pixels to prevent visual artifacts like tile seams.
  /// Your camera follow system should check this flag and snap the
  /// camera's Transform2D translation accordingly.
  bool pixelPerfect;

  /// Make the widget render path (`FledgeRenderView`,
  /// `LitFledgeRenderView`, `DebugGizmosLayer`) honour the projection's
  /// scale, so the projection's visible height fills the widget.
  ///
  /// Off by default: widgets then draw one world unit per logical pixel and
  /// only follow the camera's position. With [pixelPerfect] also on, the
  /// zoom is rounded down to a whole number (when at least 1) so pixel art
  /// stays crisp; more of the world shows instead of pixels stretching.
  ///
  /// Map pointer positions with `activeCameraScreenToWorld`, which uses the
  /// same zoom.
  bool scaleWidgetView;

  /// Scroll by fractions of a screen pixel in the widget render path, so a
  /// pixel-art camera glides evenly at any speed and refresh rate.
  ///
  /// A [pixelPerfect] camera can only move in whole screen pixels, so a
  /// speed that isn't a whole number of pixels per frame (a 120 units/s
  /// walk at 144 Hz and zoom 2 is 1.67 pixels a frame) mixes 1- and
  /// 2-pixel steps and judders. With this on, the world is drawn with the
  /// camera on whole pixels, as crisp as before, and the finished frame is
  /// then shifted by the leftover fraction of a pixel, blended across one
  /// screen pixel at its edges. The camera follow stops snapping the
  /// camera's transform; the render does it.
  ///
  /// Costs one offscreen image per frame. Only the `FledgeRenderView`
  /// sprite pass is drawn this way; other widget layers line up with it
  /// through the same unrounded camera offset.
  bool subpixelScroll;

  /// Creates a 2D camera.
  Camera2D({
    Projection? projection,
    this.order = 0,
    this.viewport = Viewport.fullScreen,
    this.isActive = true,
    this.pixelPerfect = false,
    this.scaleWidgetView = false,
    this.subpixelScroll = false,
  }) : projection = projection ?? OrthographicProjection();

  /// Logical pixels per world unit for the widget render path at
  /// [widgetSize] (logical pixels, on a display with [devicePixelRatio]
  /// physical pixels per logical one). 1 unless [scaleWidgetView] is on.
  ///
  /// With [pixelPerfect], the zoom is the largest that puts each world unit
  /// on a **whole number of physical pixels**: under fractional display
  /// scaling (125 %, 150 %) a whole logical zoom would draw art pixels at
  /// uneven widths and make anything moving a whole world unit step by
  /// uneven pixel counts, so a sprite on the nearest pixel would visibly
  /// run ahead of a smoothly scrolling camera and snap back.
  double widgetZoom(Size widgetSize, {double devicePixelRatio = 1}) {
    if (!scaleWidgetView) return 1;
    final visible = projection.visibleHeight(
      RenderSize(widgetSize.width, widgetSize.height),
    );
    if (visible <= 0 || widgetSize.height <= 0) return 1;
    final zoom = widgetSize.height / visible;
    if (!pixelPerfect) return zoom;
    final dpr = devicePixelRatio > 0 ? devicePixelRatio : 1.0;
    final physical = zoom * dpr;
    // A whole number of physical pixels, rounding a hair of float error up.
    final whole = (physical + 1e-9).floorToDouble();
    return whole >= 1 ? whole / dpr : zoom;
  }

  /// Get the view matrix (inverse of camera transform).
  Matrix4 viewMatrix(GlobalTransform2D transform) {
    // 2D view matrix - inverse translation
    return Matrix4.identity()
      ..setTranslation(Vector3(-transform.x, -transform.y, 0));
  }

  /// Get the combined view-projection matrix.
  Matrix4 viewProjectionMatrix(
    GlobalTransform2D transform,
    RenderSize screenSize,
  ) {
    final view = viewMatrix(transform);
    final proj = projection.matrix(viewport.toPixelSize(screenSize));
    return proj * view;
  }

  /// Converts a point in the camera's viewport, in logical pixels from its
  /// top-left corner (e.g. a pointer position in a full-screen
  /// `FledgeRenderView`), to world coordinates.
  ///
  /// Uses the widget render path's mapping, so it agrees with what
  /// `FledgeRenderView` draws: **y grows downward** in both screen and world
  /// space, the camera's position ([transform]) sits at the centre of the
  /// viewport, and one world unit spans [widgetZoom] logical pixels (1 unless
  /// [scaleWidgetView] is on). With [pixelPerfect] (and not
  /// [subpixelScroll]) the camera offset is rounded to whole pixels, as the
  /// widget does. Camera rotation is ignored, as it is by the widget path.
  ///
  /// [screenSize] is the size of the whole render target; [viewport] picks
  /// the camera's part of it. [devicePixelRatio] only matters for a
  /// pixel-perfect [widgetZoom].
  ///
  /// [transform] is the camera's own transform, so screen shake (a
  /// render-time offset, see `CameraShake`) isn't included. To map exactly
  /// what was drawn this frame, shake included, use
  /// `activeCameraScreenToWorld` from `fledge_render_2d`.
  ///
  /// The inverse of [worldToScreen].
  Vector2 screenToWorld(
    Vector2 screenPos,
    GlobalTransform2D transform,
    RenderSize screenSize, {
    double devicePixelRatio = 1,
  }) {
    final (offsetX, offsetY, zoom) = _screenMapping(
      transform,
      screenSize,
      devicePixelRatio,
    );
    return Vector2(
      (screenPos.x - offsetX) / zoom,
      (screenPos.y - offsetY) / zoom,
    );
  }

  /// Converts world coordinates to a point in the camera's viewport, in
  /// logical pixels from its top-left corner, with the same y-down mapping
  /// as [screenToWorld] (and the widget render path).
  ///
  /// The inverse of [screenToWorld].
  Vector2 worldToScreen(
    Vector2 worldPos,
    GlobalTransform2D transform,
    RenderSize screenSize, {
    double devicePixelRatio = 1,
  }) {
    final (offsetX, offsetY, zoom) = _screenMapping(
      transform,
      screenSize,
      devicePixelRatio,
    );
    return Vector2(worldPos.x * zoom + offsetX, worldPos.y * zoom + offsetY);
  }

  /// Where the world origin lands in the viewport, and the zoom: the same
  /// numbers `activeCameraCanvasOffset` / `activeCameraZoom` produce.
  (double, double, double) _screenMapping(
    GlobalTransform2D transform,
    RenderSize screenSize,
    double devicePixelRatio,
  ) {
    final size = viewport.toPixelSize(screenSize);
    final zoom = widgetZoom(
      Size(size.width, size.height),
      devicePixelRatio: devicePixelRatio,
    );
    var offsetX = size.width / 2 - transform.x * zoom;
    var offsetY = size.height / 2 - transform.y * zoom;
    if (pixelPerfect && !subpixelScroll) {
      offsetX = offsetX.roundToDouble();
      offsetY = offsetY.roundToDouble();
    }
    return (offsetX, offsetY, zoom);
  }
}
