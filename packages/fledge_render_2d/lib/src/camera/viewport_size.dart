import 'dart:ui' show Size;

/// Resource that stores the current viewport (screen) dimensions.
///
/// Used by extractors to determine what portion of the world is visible,
/// enabling early culling during extraction rather than at render time.
///
/// ## Usage
///
/// Register as a resource in your game plugin:
///
/// ```dart
/// app.insertResource(ViewportSize());
/// ```
///
/// Update each frame before `tick()` runs (typically in your game loop):
///
/// ```dart
/// void _gameLoop() {
///   // Update viewport before tick so extractors can cull properly
///   world.getResource<ViewportSize>()?.updateFromSize(screenSize);
///   app.tick();
/// }
/// ```
///
/// Extractors can then use this to cull entities outside the visible area:
///
/// ```dart
/// class MyExtractor extends Extractor {
///   @override
///   void extract(World mainWorld, RenderWorld renderWorld) {
///     final viewport = mainWorld.getResource<ViewportSize>();
///     final camera = mainWorld.query2<Camera2D, Transform2D>().iter().first;
///     // Calculate visible bounds and only extract visible entities...
///   }
/// }
/// ```
class ViewportSize {
  /// The current viewport width in logical pixels.
  double width;

  /// The current viewport height in logical pixels.
  double height;

  /// Creates a viewport size resource.
  ///
  /// Defaults to a reasonable window size (1280x720). Should be updated
  /// each frame before extraction runs.
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
