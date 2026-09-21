import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:fledge_render_2d/fledge_render_2d.dart' show RenderSize;
import 'package:vector_math/vector_math.dart';

/// Scaling mode for orthographic projection.
enum ScalingMode {
  /// Fixed viewport width, height adjusts to aspect ratio.
  fixedWidth,

  /// Fixed viewport height, width adjusts to aspect ratio.
  fixedHeight,

  /// Fixed vertical size (same as fixedHeight).
  fixedVertical,

  /// No automatic scaling (use screen size directly).
  none,
}

/// Common interface for all camera projections.
///
/// Concrete implementations produce a **world → clip** matrix for the
/// given screen size, plus helpers to compute the visible world
/// bounds. `Camera2D` composes this with the entity's `Transform2D`
/// to produce a view-projection matrix each frame.
///
/// Built-in implementations:
/// - [OrthographicProjection] — flat 2D projection (default).
/// - [IsometricProjection] — 2:1 isometric skew for iso games.
/// - [ObliqueProjection] — parametric skew for oblique games.
abstract class Projection {
  /// Get the projection matrix for the given screen size.
  Matrix4 matrix(RenderSize screenSize);

  /// The visible width in world units for the given screen size.
  double visibleWidth(RenderSize screenSize);

  /// The visible height in world units for the given screen size.
  double visibleHeight(RenderSize screenSize);

  /// Convert a world-space point to screen-space **pixels** in the
  /// screen rect described by [screenSize].
  ///
  /// The default implementation folds [matrix] with the standard
  /// clip-to-screen mapping. Concrete projections may override for
  /// speed or precision.
  Vector2 worldToScreenPoint(Vector2 world, RenderSize screenSize) {
    final m = matrix(screenSize);
    final v = Vector4(world.x, world.y, 0, 1);
    m.transform(v);
    final x = (v.x + 1) / 2 * screenSize.width;
    // Flip Y so that increasing worldY moves "down" in screen space
    // when the projection follows the standard OpenGL convention. The
    // built-in projections use the convention below where clip-Y is
    // already screen-Y up; overrides should follow suit.
    final y = (1 - v.y) / 2 * screenSize.height;
    return Vector2(x, y);
  }
}

/// Optional letterbox / pillarbox configuration.
///
/// When supplied to an [OrthographicProjection], the projection
/// preserves the target aspect ratio and returns black bars ("letter"
/// or "pillar") on the axis that doesn't match. Use
/// [computeLetterbox] and [computeGutter] to draw the bars in the
/// widget layer if needed.
class LetterboxConfig {
  /// Target aspect ratio (width / height). Typical values: `16 / 9`,
  /// `4 / 3`, `21 / 9`.
  final double targetAspect;

  /// Creates a letterbox configuration.
  const LetterboxConfig({required this.targetAspect});
}

/// Compute the game rect **inside** [viewport] that preserves
/// [targetAspect]. If the viewport is wider than the target, this
/// centres horizontally (pillarbox). If narrower, it centres
/// vertically (letterbox).
Rect computeLetterbox(RenderSize viewport, double targetAspect) {
  if (viewport.width <= 0 || viewport.height <= 0 || targetAspect <= 0) {
    return const Rect.fromLTWH(0, 0, 0, 0);
  }
  final viewportAspect = viewport.width / viewport.height;
  if (viewportAspect > targetAspect) {
    // Pillarbox — bars on the left/right.
    final w = viewport.height * targetAspect;
    final x = (viewport.width - w) / 2;
    return Rect.fromLTWH(x, 0, w, viewport.height);
  }
  // Letterbox — bars on top/bottom (or exact fit).
  final h = viewport.width / targetAspect;
  final y = (viewport.height - h) / 2;
  return Rect.fromLTWH(0, y, viewport.width, h);
}

/// The gutter regions (black bars) around a letterboxed game rect.
///
/// Returns up to two rects: `(top-or-left, bottom-or-right)`. Either
/// may be empty. Use for drawing background bars.
List<Rect> computeGutter(RenderSize viewport, Rect gameRect) {
  final vpRect = Rect.fromLTWH(0, 0, viewport.width, viewport.height);
  if (gameRect == vpRect) return const <Rect>[];
  // Horizontal (pillarbox) — bars on left/right.
  if (gameRect.top == vpRect.top && gameRect.bottom == vpRect.bottom) {
    return <Rect>[
      Rect.fromLTRB(vpRect.left, vpRect.top, gameRect.left, vpRect.bottom),
      Rect.fromLTRB(gameRect.right, vpRect.top, vpRect.right, vpRect.bottom),
    ];
  }
  // Vertical (letterbox) — bars on top/bottom.
  return <Rect>[
    Rect.fromLTRB(vpRect.left, vpRect.top, vpRect.right, gameRect.top),
    Rect.fromLTRB(vpRect.left, gameRect.bottom, vpRect.right, vpRect.bottom),
  ];
}

/// Orthographic projection settings for 2D rendering.
///
/// Defines how world coordinates map to screen coordinates. This is
/// the standard flat 2D camera projection.
class OrthographicProjection extends Projection {
  /// Scaling mode for handling different screen sizes.
  ScalingMode scalingMode;

  /// Viewport width in world units (for [ScalingMode.fixedWidth]).
  double viewportWidth;

  /// Viewport height in world units (for [ScalingMode.fixedHeight]).
  double viewportHeight;

  /// Near clipping plane.
  double near;

  /// Far clipping plane.
  double far;

  /// Optional letterbox configuration. When set, the projection
  /// clamps its aspect ratio to the target — the viewport gets black
  /// bars on the axis that doesn't match. See [computeLetterbox].
  LetterboxConfig? letterbox;

  /// Creates an orthographic projection.
  OrthographicProjection({
    this.scalingMode = ScalingMode.fixedHeight,
    this.viewportWidth = 10,
    this.viewportHeight = 10,
    this.near = -1000,
    this.far = 1000,
    this.letterbox,
  });

  /// Creates a projection with pixel-perfect mapping.
  ///
  /// One world unit = one screen pixel.
  factory OrthographicProjection.pixelPerfect() =>
      OrthographicProjection(scalingMode: ScalingMode.none);

  /// The effective render size after applying [letterbox], if set.
  RenderSize _effectiveRenderSize(RenderSize screenSize) {
    final lb = letterbox;
    if (lb == null) return screenSize;
    final rect = computeLetterbox(screenSize, lb.targetAspect);
    return RenderSize(rect.width, rect.height);
  }

  @override
  Matrix4 matrix(RenderSize screenSize) {
    final effective = _effectiveRenderSize(screenSize);
    double halfWidth;
    double halfHeight;

    switch (scalingMode) {
      case ScalingMode.fixedWidth:
        halfWidth = viewportWidth / 2;
        halfHeight = halfWidth / effective.aspectRatio;
      case ScalingMode.fixedHeight:
      case ScalingMode.fixedVertical:
        halfHeight = viewportHeight / 2;
        halfWidth = halfHeight * effective.aspectRatio;
      case ScalingMode.none:
        halfWidth = effective.width / 2;
        halfHeight = effective.height / 2;
    }

    return makeOrthographicMatrix(
      -halfWidth,
      halfWidth,
      -halfHeight,
      halfHeight,
      near,
      far,
    );
  }

  @override
  double visibleWidth(RenderSize screenSize) {
    final effective = _effectiveRenderSize(screenSize);
    switch (scalingMode) {
      case ScalingMode.fixedWidth:
        return viewportWidth;
      case ScalingMode.fixedHeight:
      case ScalingMode.fixedVertical:
        return viewportHeight * effective.aspectRatio;
      case ScalingMode.none:
        return effective.width;
    }
  }

  @override
  double visibleHeight(RenderSize screenSize) {
    final effective = _effectiveRenderSize(screenSize);
    switch (scalingMode) {
      case ScalingMode.fixedWidth:
        return viewportWidth / effective.aspectRatio;
      case ScalingMode.fixedHeight:
      case ScalingMode.fixedVertical:
        return viewportHeight;
      case ScalingMode.none:
        return effective.height;
    }
  }

  @override
  Vector2 worldToScreenPoint(Vector2 world, RenderSize screenSize) {
    // Fast path: skip Matrix4 setup and read the projection scales
    // directly.
    final vw = visibleWidth(screenSize);
    final vh = visibleHeight(screenSize);
    final x = (world.x / (vw / 2) + 1) / 2 * screenSize.width;
    final y = (1 - world.y / (vh / 2)) / 2 * screenSize.height;
    return Vector2(x, y);
  }
}

/// Isometric projection with a 2:1 aspect ratio.
///
/// Maps a world-space point to screen space as if the world were
/// viewed from an isometric angle:
///
/// ```
/// screenX = (worldX - worldY) * tileWidth / 2
/// screenY = (worldX + worldY) * tileHeight / 2
/// ```
///
/// Where `tileWidth : tileHeight = 2 : 1` is the "true" isometric
/// aspect used by nearly all iso games (Diablo, Age of Empires,
/// etc.).
///
/// The projection matrix bakes the iso skew plus an orthographic
/// clip mapping so world space feeds straight into
/// `Canvas.drawRawAtlas`.
class IsometricProjection extends Projection {
  /// Half the visible horizontal extent in world units at the
  /// projection's neutral zoom. Larger = zoomed out.
  double viewportSize;

  /// Near clipping plane.
  double near;

  /// Far clipping plane.
  double far;

  /// Creates an isometric projection.
  IsometricProjection({
    this.viewportSize = 20,
    this.near = -1000,
    this.far = 1000,
  });

  /// The isometric skew matrix.
  ///
  /// Maps `(worldX, worldY, 0, 1)` to
  /// `(worldX - worldY, (worldX + worldY) * 0.5, 0, 1)`. This is a
  /// pure shear — no scale is folded in here.
  static Matrix4 skewMatrix() {
    // Matrix4 column-major storage: [ col0, col1, col2, col3 ]
    // Row-major representation of the skew:
    //   | 1  -1  0  0 |
    //   | 0.5 0.5 0  0 |
    //   | 0   0  1  0 |
    //   | 0   0  0  1 |
    return Matrix4(
      1,
      0.5,
      0,
      0, // col 0
      -1,
      0.5,
      0,
      0, // col 1
      0,
      0,
      1,
      0, // col 2
      0,
      0,
      0,
      1, // col 3
    );
  }

  @override
  Matrix4 matrix(RenderSize screenSize) {
    // Ortho fits [-viewportSize/2, +viewportSize/2] on both axes,
    // adjusted for screen aspect on X so squares stay square.
    final halfHeight = viewportSize / 2;
    final halfWidth = halfHeight * screenSize.aspectRatio;
    final ortho = makeOrthographicMatrix(
      -halfWidth,
      halfWidth,
      -halfHeight,
      halfHeight,
      near,
      far,
    );
    return ortho * skewMatrix();
  }

  @override
  double visibleWidth(RenderSize screenSize) =>
      viewportSize * screenSize.aspectRatio;

  @override
  double visibleHeight(RenderSize screenSize) => viewportSize;

  /// Convert a world-space point directly to isometric screen-pixel
  /// coordinates, ignoring [screenSize] scaling. Useful for tests
  /// and gameplay code that speaks in "iso pixels".
  Vector2 worldToIso(Vector2 world) =>
      Vector2(world.x - world.y, (world.x + world.y) * 0.5);
}

/// Parametric oblique projection.
///
/// Applies a skew on the X-axis at [angleRadians] with a Y-axis
/// depth factor of [depthFactor]. This is the "cabinet" / "cavalier"
/// projection family used by some 2.5D games (e.g. Ultima VII, EarthBound
/// townview).
///
/// ```
/// screenX = worldX + worldY * cos(angle) * depthFactor
/// screenY = worldY * sin(angle) * depthFactor
/// ```
///
/// `depthFactor = 1.0` gives cavalier projection (foreshortening
/// preserved); `depthFactor = 0.5` gives cabinet projection.
class ObliqueProjection extends Projection {
  /// Half the visible horizontal extent in world units.
  double viewportWidth;

  /// Half the visible vertical extent in world units.
  double viewportHeight;

  /// Skew angle in radians. `pi/4` (45°) is standard.
  double angleRadians;

  /// Foreshortening factor. `1.0` = cavalier, `0.5` = cabinet.
  double depthFactor;

  /// Near clipping plane.
  double near;

  /// Far clipping plane.
  double far;

  /// Creates an oblique projection.
  ObliqueProjection({
    this.viewportWidth = 20,
    this.viewportHeight = 20,
    this.angleRadians = math.pi / 4,
    this.depthFactor = 0.5,
    this.near = -1000,
    this.far = 1000,
  });

  /// The oblique skew matrix.
  Matrix4 skewMatrix() {
    final c = math.cos(angleRadians) * depthFactor;
    final s = math.sin(angleRadians) * depthFactor;
    // Row-major:
    //   | 1  c  0  0 |
    //   | 0  s  0  0 |
    //   | 0  0  1  0 |
    //   | 0  0  0  1 |
    return Matrix4(
      1,
      0,
      0,
      0, // col 0
      c,
      s,
      0,
      0, // col 1
      0,
      0,
      1,
      0, // col 2
      0,
      0,
      0,
      1, // col 3
    );
  }

  @override
  Matrix4 matrix(RenderSize screenSize) {
    final halfW = viewportWidth / 2;
    final halfH = viewportHeight / 2;
    final ortho = makeOrthographicMatrix(
      -halfW,
      halfW,
      -halfH,
      halfH,
      near,
      far,
    );
    return ortho * skewMatrix();
  }

  @override
  double visibleWidth(RenderSize screenSize) => viewportWidth;

  @override
  double visibleHeight(RenderSize screenSize) => viewportHeight;

  /// Convert a world-space point directly to oblique screen-pixel
  /// coordinates, ignoring viewport scaling.
  Vector2 worldToOblique(Vector2 world) {
    final c = math.cos(angleRadians) * depthFactor;
    final s = math.sin(angleRadians) * depthFactor;
    return Vector2(world.x + world.y * c, world.y * s);
  }
}
