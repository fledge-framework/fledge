import 'package:fledge_render/fledge_render.dart';
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

/// Orthographic projection settings for 2D rendering.
///
/// Defines how world coordinates map to screen coordinates.
class OrthographicProjection {
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

  /// Creates an orthographic projection.
  OrthographicProjection({
    this.scalingMode = ScalingMode.fixedHeight,
    this.viewportWidth = 10,
    this.viewportHeight = 10,
    this.near = -1000,
    this.far = 1000,
  });

  /// Creates a projection with pixel-perfect mapping.
  ///
  /// One world unit = one screen pixel.
  factory OrthographicProjection.pixelPerfect() => OrthographicProjection(
        scalingMode: ScalingMode.none,
      );

  /// Get the projection matrix for the given screen size.
  Matrix4 matrix(RenderSize screenSize) {
    double halfWidth;
    double halfHeight;

    switch (scalingMode) {
      case ScalingMode.fixedWidth:
        halfWidth = viewportWidth / 2;
        halfHeight = halfWidth / screenSize.aspectRatio;
      case ScalingMode.fixedHeight:
      case ScalingMode.fixedVertical:
        halfHeight = viewportHeight / 2;
        halfWidth = halfHeight * screenSize.aspectRatio;
      case ScalingMode.none:
        halfWidth = screenSize.width / 2;
        halfHeight = screenSize.height / 2;
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

  /// The visible width in world units for the given screen size.
  double visibleWidth(RenderSize screenSize) {
    switch (scalingMode) {
      case ScalingMode.fixedWidth:
        return viewportWidth;
      case ScalingMode.fixedHeight:
      case ScalingMode.fixedVertical:
        return viewportHeight * screenSize.aspectRatio;
      case ScalingMode.none:
        return screenSize.width;
    }
  }

  /// The visible height in world units for the given screen size.
  double visibleHeight(RenderSize screenSize) {
    switch (scalingMode) {
      case ScalingMode.fixedWidth:
        return viewportWidth / screenSize.aspectRatio;
      case ScalingMode.fixedHeight:
      case ScalingMode.fixedVertical:
        return viewportHeight;
      case ScalingMode.none:
        return screenSize.height;
    }
  }
}
