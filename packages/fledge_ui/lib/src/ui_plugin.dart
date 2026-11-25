import 'package:fledge_camera_2d/fledge_camera_2d.dart' show ViewportSize;
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart' show Extractors;

import 'extraction/ui_extractor.dart';
import 'systems/ui_layout_system.dart';

/// Wires the retained-mode UI pipeline into an [App].
///
/// Adds a [LayoutSystem] to `Schedules.postUpdate` and registers a
/// [UiExtractor] on the render pipeline's shared `Extractors`
/// registry.
///
/// Requires `RenderPlugin` to be added first (it inserts the
/// `Extractors` registry and the `RenderWorld`); throws a [StateError]
/// otherwise.
///
/// Layout fills the [ViewportSize] resource's rect. `CameraPlugin` inserts
/// one; if it is missing, this plugin inserts a default (1280×720) itself,
/// so the plugins can be added in either order. Nothing resizes it
/// automatically: update it to the size of your `FledgeUiOverlay` (e.g.
/// from a `LayoutBuilder`) so anchors land where the overlay draws.
///
/// ## Example
///
/// ```dart
/// final app = App()
///   ..addPlugin(RenderPlugin())
///   ..addPlugin(const CameraPlugin())
///   ..addPlugin(const UiPlugin());
/// ```
class UiPlugin implements Plugin {
  /// Creates a UI plugin.
  const UiPlugin();

  @override
  void build(App app) {
    final extractors = app.world.getResource<Extractors>();
    if (extractors == null) {
      throw StateError(
        'UiPlugin requires RenderPlugin to be added first '
        '(RenderPlugin inserts the shared Extractors registry that '
        'UiExtractor registers into).',
      );
    }

    if (!app.world.hasResource<ViewportSize>()) {
      app.insertResource(ViewportSize());
    }
    app.addSystem(LayoutSystem(), schedule: Schedules.postUpdate);
    extractors.register(UiExtractor());
  }

  @override
  void cleanup() {}
}
