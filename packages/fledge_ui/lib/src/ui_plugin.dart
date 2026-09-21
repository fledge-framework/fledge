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
/// Requires [RenderPlugin] to be added first (it inserts the
/// `Extractors` registry and the `RenderWorld`).
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

    app.addSystem(LayoutSystem(), schedule: Schedules.postUpdate);
    extractors.register(UiExtractor());
  }

  @override
  void cleanup() {}
}
