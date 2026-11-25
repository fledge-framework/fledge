import 'dart:ui' show Size;

/// Resource that stores the size of the game's view, in logical pixels.
///
/// Read by:
/// - `CameraFollow.bounds`, for the visible size until the camera's widget
///   has painted once (after that it uses the painted size recorded on
///   `ActiveCameraView`);
/// - `fledge_ui`'s layout pass, which anchors UI nodes inside this rect.
///
/// Extractors don't read it: sprite culling uses
/// `ActiveCameraView.visibleWorldRect`.
///
/// Nothing updates it automatically. `CameraPlugin` (and `UiPlugin`)
/// insert a 1280×720 default; keep it at the size of the widget you draw
/// into, e.g. from a `LayoutBuilder`:
///
/// ```dart
/// LayoutBuilder(
///   builder: (context, constraints) {
///     app.world.getResource<ViewportSize>()?.updateFromSize(
///       constraints.biggest,
///     );
///     return FledgeUiOverlay(app: app, child: FledgeRenderView(app: app));
///   },
/// )
/// ```
class ViewportSize {
  /// The current viewport width in logical pixels.
  double width;

  /// The current viewport height in logical pixels.
  double height;

  /// Creates a viewport size resource.
  ///
  /// Defaults to a reasonable window size (1280x720). Update it whenever
  /// the view's size changes.
  ViewportSize({this.width = 1280, this.height = 720});

  /// The viewport as a [Size] object.
  Size get size => Size(width, height);

  /// Updates the viewport dimensions.
  void update(double newWidth, double newHeight) {
    width = newWidth;
    height = newHeight;
  }

  /// Updates the viewport from a [Size] object.
  void updateFromSize(Size size) {
    width = size.width;
    height = size.height;
  }
}
