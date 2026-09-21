import 'package:fledge_ecs/fledge_ecs.dart' show Entity;
import 'package:vector_math/vector_math.dart';

import '../context/render_context.dart';

/// Viewport rectangle for camera rendering.
///
/// The viewport is specified in **normalized** screen coordinates
/// (0..1) so that a single camera setup renders correctly at any
/// resolution. `x = 0.5, width = 0.5` places the render target on the
/// right half of the screen, useful for split-screen setups.
///
/// This lives in `fledge_render_2d` (not `fledge_camera_2d`) because
/// [CameraView] — the value that flows through the render graph — is
/// owned by the render pipeline. Camera components in
/// `fledge_camera_2d` reference this type without pulling any of the
/// camera package's other machinery.
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
  const Viewport({this.x = 0, this.y = 0, this.width = 1, this.height = 1});

  /// Full screen viewport.
  static const fullScreen = Viewport();

  /// Get pixel rect for the given screen size.
  RenderSize toPixelSize(RenderSize screenSize) =>
      RenderSize(screenSize.width * width, screenSize.height * height);
}

/// Camera view data passed through render graph slots.
///
/// Produced by the camera driver node (in `fledge_camera_2d`) and
/// consumed by `SpriteRenderNode`. This is the *only* type that the
/// render pipeline needs to know about a camera — the concrete
/// `Camera2D` / `Projection` types live in `fledge_camera_2d`, which
/// depends on this package.
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
