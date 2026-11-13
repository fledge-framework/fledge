import 'dart:ui'
    show Canvas, FilterQuality, Offset, Paint, PictureRecorder, Rect, Size;

import 'package:fledge_ecs/fledge_ecs.dart' show World;

/// World-space position of the active camera, as far as the widget
/// render path is concerned.
///
/// The widget rendering path (`FledgeRenderView`,
/// `LitFledgeRenderView`, `DebugGizmosLayer`,
/// `renderLightsToCanvas`) draws world-space content directly on the
/// Flutter `Canvas`, so it needs to know where the camera is looking
/// to translate world coordinates into screen ones. This resource is
/// the single hand-off point.
///
/// - `fledge_camera_2d`'s camera-driver system writes it every frame.
/// - `fledge_render_2d`'s widgets read it (via
///   [activeCameraCanvasOffset]) and translate the canvas so the
///   camera's world position sits at the widget centre.
///
/// Games that don't use `fledge_camera_2d` can either write this
/// resource themselves or leave it unset. When unset, widgets render
/// with world = screen (1:1, camera-less) — the pre-Batch-3-#15
/// behaviour.
///
/// The `SpriteRenderNode` render-graph path is unaffected by this
/// resource — it reads `CameraView` off the render graph as before.
class ActiveCameraView {
  /// World-space position of the camera's centre.
  double x;

  /// World-space position of the camera's centre.
  double y;

  /// Whether the underlying camera is pixel-perfect. Publishers should
  /// mirror `Camera2D.pixelPerfect` here so the widget path can round
  /// the derived canvas offset to whole pixels, avoiding a half-pixel
  /// canvas translation on odd-sized viewports.
  bool pixelPerfect;

  /// Whether [paintActiveCameraView] draws the world with the camera on
  /// whole pixels and then shifts the finished frame by the leftover
  /// fraction of a pixel, so the camera scrolls evenly at any speed.
  /// Publishers mirror `Camera2D.subpixelScroll` here. While on, the
  /// camera offset is not rounded, so every layer lines up with the
  /// shifted frame.
  bool subpixelScroll;

  /// Logical pixels per world unit for a widget of the given size, or
  /// `null` (the default) to draw one world unit per logical pixel.
  ///
  /// `fledge_camera_2d` fills this in from the camera's projection when
  /// `Camera2D.scaleWidgetView` is on, so e.g. a projection with
  /// `viewportHeight: 270` fills the widget's height with 270 world units.
  double Function(Size viewportSize)? zoomFor;

  /// Physical pixels per logical pixel of the widget the world was last
  /// drawn into (recorded by [paintActiveCameraView]; 1 until then). A
  /// pixel-perfect [zoomFor] uses it to put every world unit on a whole
  /// number of physical pixels, whatever the display scaling.
  double devicePixelRatio = 1;

  /// The size of the widget the world was last drawn into, in logical
  /// pixels. The widget render paths record it on every paint (through
  /// [withActiveCameraCanvas]), so extractors can skip what is off screen.
  /// `null` until the first paint.
  Size? viewportSize;

  /// The world-space area the camera showed at its last paint, or `null`
  /// before the first one. Extractors use it to cull: they should widen it
  /// by a margin, since the camera can move between that paint and the
  /// next.
  Rect? get visibleWorldRect {
    final size = viewportSize;
    if (size == null || size.isEmpty) return null;
    final zoom = zoomFor?.call(size) ?? 1;
    if (!zoom.isFinite || zoom <= 0) return null;
    return Rect.fromCenter(
      center: Offset(x, y),
      width: size.width / zoom,
      height: size.height / zoom,
    );
  }

  /// Creates the resource at the world origin.
  ActiveCameraView({
    this.x = 0,
    this.y = 0,
    this.pixelPerfect = false,
    this.subpixelScroll = false,
    this.zoomFor,
  });

  /// Set both coordinates at once (leaves [pixelPerfect] untouched).
  void set(double x, double y) {
    this.x = x;
    this.y = y;
  }
}

/// Logical pixels per world unit for the widget render path: the
/// [ActiveCameraView.zoomFor] result, or 1 when there is no camera view or
/// it doesn't set a zoom.
double activeCameraZoom(World world, Size viewportSize) {
  final zoomFor = world.getResource<ActiveCameraView>()?.zoomFor;
  if (zoomFor == null) return 1;
  final zoom = zoomFor(viewportSize);
  return zoom.isFinite && zoom > 0 ? zoom : 1;
}

/// Canvas offset that places the [ActiveCameraView]'s world position
/// at the centre of [viewportSize]. With a zoom (see [activeCameraZoom])
/// this is where the world origin lands on screen; the canvas is scaled
/// by the zoom after translating.
///
/// Returns `null` when no `ActiveCameraView` resource has been
/// installed, letting callers fall back to the 1:1 world = screen
/// mapping used before camera-aware rendering existed.
///
/// ```dart
/// final offset = activeCameraCanvasOffset(app.world, size);
/// if (offset != null) {
///   canvas.save();
///   canvas.translate(offset.dx, offset.dy);
///   // draw world-space content
///   canvas.restore();
/// }
/// ```
Offset? activeCameraCanvasOffset(World world, Size viewportSize) {
  final view = world.getResource<ActiveCameraView>();
  if (view == null) return null;
  final zoom = activeCameraZoom(world, viewportSize);
  final rawX = viewportSize.width / 2 - view.x * zoom;
  final rawY = viewportSize.height / 2 - view.y * zoom;
  if (view.pixelPerfect && !view.subpixelScroll) {
    // Round to whole pixels so pixel-art tiles don't fall on half
    // pixels when the viewport width or height is odd (or the camera
    // ends up at a non-integer world position).
    return Offset(rawX.roundToDouble(), rawY.roundToDouble());
  }
  return Offset(rawX, rawY);
}

/// Convenience wrapper that pushes a camera-aware translation onto
/// [canvas] before running [body] and pops it afterwards.
///
/// Falls through to a plain `body()` call when no
/// [ActiveCameraView] resource exists — callers don't need to
/// branch.
void withActiveCameraCanvas(
  World world,
  Canvas canvas,
  Size size,
  void Function() body,
) {
  world.getResource<ActiveCameraView>()?.viewportSize = size;
  final offset = activeCameraCanvasOffset(world, size);
  if (offset == null) {
    body();
    return;
  }
  final zoom = activeCameraZoom(world, size);
  canvas.save();
  canvas.translate(offset.dx, offset.dy);
  if (zoom != 1) canvas.scale(zoom);
  try {
    body();
  } finally {
    canvas.restore();
  }
}

/// Paints world-space content through the active camera: like
/// [withActiveCameraCanvas], but hands [body] the canvas to draw on, and
/// honours [ActiveCameraView.subpixelScroll].
///
/// With sub-pixel scrolling, [body] draws into an offscreen image with the
/// camera on whole physical pixels (so nearest-neighbour art stays crisp),
/// and the image is drawn onto [canvas] shifted by the remaining fraction
/// of a pixel with bilinear filtering, which blends only across one
/// physical pixel. [devicePixelRatio] is the canvas's physical pixels per
/// logical pixel.
void paintActiveCameraView(
  World world,
  Canvas canvas,
  Size size,
  void Function(Canvas canvas) body, {
  double devicePixelRatio = 1,
}) {
  final view = world.getResource<ActiveCameraView>();
  if (view == null || !view.subpixelScroll || size.isEmpty) {
    withActiveCameraCanvas(world, canvas, size, () => body(canvas));
    return;
  }
  view.viewportSize = size;
  final dpr = devicePixelRatio > 0 ? devicePixelRatio : 1.0;
  view.devicePixelRatio = dpr;
  final zoom = activeCameraZoom(world, size);
  final offset = activeCameraCanvasOffset(world, size)!;
  // The offset in physical pixels, split into a whole part (drawn into the
  // image) and the fraction left over (applied when the image is drawn).
  final px = offset.dx * dpr;
  final py = offset.dy * dpr;
  final wholeX = px.roundToDouble();
  final wholeY = py.roundToDouble();
  // A one-pixel margin, so the shifted image still covers every edge.
  const margin = 1;
  final width = (size.width * dpr).ceil() + margin * 2;
  final height = (size.height * dpr).ceil() + margin * 2;

  final recorder = PictureRecorder();
  final offscreen = Canvas(recorder);
  offscreen
    ..translate(wholeX + margin, wholeY + margin)
    ..scale(zoom * dpr);
  body(offscreen);
  final picture = recorder.endRecording();
  final image = picture.toImageSync(width, height);
  picture.dispose();

  canvas
    ..save()
    ..scale(1 / dpr)
    ..drawImage(
      image,
      Offset(px - wholeX - margin, py - wholeY - margin),
      Paint()..filterQuality = FilterQuality.low,
    )
    ..restore();
  // The canvas keeps its own reference until it's drawn.
  image.dispose();
}

/// Converts a point in widget-local logical pixels (e.g. a pointer
/// position) to world coordinates, using the same mapping as
/// [withActiveCameraCanvas]. Without an [ActiveCameraView] the mapping is
/// world = screen.
Offset activeCameraScreenToWorld(
  World world,
  Size viewportSize,
  Offset screen,
) {
  final offset = activeCameraCanvasOffset(world, viewportSize);
  if (offset == null) return screen;
  return (screen - offset) / activeCameraZoom(world, viewportSize);
}

/// Inverse of [activeCameraScreenToWorld]: world coordinates to
/// widget-local logical pixels.
Offset activeCameraWorldToScreen(
  World world,
  Size viewportSize,
  Offset worldPoint,
) {
  final offset = activeCameraCanvasOffset(world, viewportSize);
  if (offset == null) return worldPoint;
  return worldPoint * activeCameraZoom(world, viewportSize) + offset;
}

/// The world-space rectangle visible in a widget of [viewportSize].
Rect activeCameraVisibleWorldRect(World world, Size viewportSize) {
  final topLeft = activeCameraScreenToWorld(world, viewportSize, Offset.zero);
  final bottomRight = activeCameraScreenToWorld(
    world,
    viewportSize,
    Offset(viewportSize.width, viewportSize.height),
  );
  return Rect.fromPoints(topLeft, bottomRight);
}
