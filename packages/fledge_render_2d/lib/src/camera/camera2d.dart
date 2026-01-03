import 'package:fledge_ecs/fledge_ecs.dart' show Entity;
import 'package:fledge_render/fledge_render.dart';
import 'package:vector_math/vector_math.dart';

import '../transform/global_transform.dart';
import 'projection.dart';

/// Viewport rectangle for camera rendering.
class Viewport {
  /// X position in normalized coordinates (0-1).
  final double x;

  /// Y position in normalized coordinates (0-1).
  final double y;

  /// Width in normalized coordinates (0-1).
  final double width;

  /// Height in normalized coordinates (0-1).
  final double height;

  /// Creates a viewport.
  const Viewport({
    this.x = 0,
    this.y = 0,
    this.width = 1,
    this.height = 1,
  });

  /// Full screen viewport.
  static const fullScreen = Viewport();

  /// Get pixel rect for the given screen size.
  RenderSize toPixelSize(RenderSize screenSize) => RenderSize(
        screenSize.width * width,
        screenSize.height * height,
      );
}

/// 2D camera component.
///
/// Cameras determine what portion of the world is visible and how
/// it maps to the screen. Attach to an entity with [Transform2D]
/// to control the camera position.
///
/// ## Pixel-Perfect Rendering
///
/// For pixel art games or tile-based games, enable [pixelPerfect] to
/// prevent visual artifacts like tile seams. When enabled, the camera
/// position should be snapped to whole pixels before rendering.
///
/// Use [snapToPixel] extension on Vector2 in your camera follow system:
/// ```dart
/// cameraTransform.translation
///   ..x = playerTransform.translation.x
///   ..y = playerTransform.translation.y;
/// if (camera.pixelPerfect) {
///   cameraTransform.translation.snapToPixel();
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
  OrthographicProjection projection;

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

  /// Creates a 2D camera.
  Camera2D({
    OrthographicProjection? projection,
    this.order = 0,
    this.viewport = Viewport.fullScreen,
    this.isActive = true,
    this.pixelPerfect = false,
  }) : projection = projection ?? OrthographicProjection();

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

  /// Convert screen coordinates to world coordinates.
  Vector2 screenToWorld(
    Vector2 screenPos,
    GlobalTransform2D transform,
    RenderSize screenSize,
  ) {
    // Get inverse view-projection
    final vp = viewProjectionMatrix(transform, screenSize);
    final inv = Matrix4.zero();
    vp.copyInverse(inv);

    // Convert screen to normalized device coordinates (-1 to 1)
    final viewportSize = viewport.toPixelSize(screenSize);
    final ndcX = (screenPos.x / viewportSize.width) * 2 - 1;
    final ndcY = (screenPos.y / viewportSize.height) * 2 - 1;

    // Transform to world space
    final world = Vector4(ndcX, -ndcY, 0, 1);
    inv.transform(world);

    return Vector2(world.x, world.y);
  }

  /// Convert world coordinates to screen coordinates.
  Vector2 worldToScreen(
    Vector2 worldPos,
    GlobalTransform2D transform,
    RenderSize screenSize,
  ) {
    final vp = viewProjectionMatrix(transform, screenSize);

    // Transform to clip space
    final clip = Vector4(worldPos.x, worldPos.y, 0, 1);
    vp.transform(clip);

    // Convert from NDC to screen
    final viewportSize = viewport.toPixelSize(screenSize);
    final screenX = (clip.x + 1) / 2 * viewportSize.width;
    final screenY = (-clip.y + 1) / 2 * viewportSize.height;

    return Vector2(screenX, screenY);
  }
}

/// Camera view data passed through render graph slots.
class CameraView {
  /// The camera entity.
  final Entity entity;

  /// The view-projection matrix.
  final Matrix4 viewProjection;

  /// The viewport in normalized coordinates.
  final Viewport viewport;

  /// Creates camera view data.
  const CameraView(this.entity, this.viewProjection, this.viewport);
}
