import 'dart:ui' show Canvas, Offset, Size;

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

  /// Creates the resource at the world origin.
  ActiveCameraView({this.x = 0, this.y = 0});

  /// Set both coordinates at once.
  void set(double x, double y) {
    this.x = x;
    this.y = y;
  }
}

/// Canvas offset that places the [ActiveCameraView]'s world position
/// at the centre of [viewportSize].
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
  return Offset(viewportSize.width / 2 - view.x, viewportSize.height / 2 - view.y);
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
  final offset = activeCameraCanvasOffset(world, size);
  if (offset == null) {
    body();
    return;
  }
  canvas.save();
  canvas.translate(offset.dx, offset.dy);
  try {
    body();
  } finally {
    canvas.restore();
  }
}
