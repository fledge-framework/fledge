import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart' show Extractors;

import 'ambient_light.dart';
import 'light_extractor.dart';

/// Wires 2D lighting into an [App].
///
/// - Inserts the [AmbientLight] resource so [LitFledgeRenderView] can
///   read it (and users can adjust it at runtime).
/// - Registers [LightExtractor] on the render pipeline's `Extractors`
///   registry. `RenderPlugin` must have already inserted that
///   resource — add `RenderPlugin` before `LightingPlugin` in your
///   plugin list.
///
/// No per-tick systems run in the main world; the actual light draw
/// happens inside [LitFledgeRenderView] on the paint thread.
///
/// ## Example
///
/// ```dart
/// final app = App()
///   ..addPlugin(RenderPlugin())
///   ..addPlugin(LightingPlugin(ambient: AmbientLight.dark));
/// ```
class LightingPlugin implements Plugin {
  /// Ambient light inserted as a resource on `build`. Defaults to
  /// [AmbientLight.white] (a neutral, half-lit scene).
  final AmbientLight ambient;

  /// Creates a lighting plugin.
  const LightingPlugin({this.ambient = AmbientLight.white});

  @override
  void build(App app) {
    app.insertResource(ambient);

    final extractors = app.world.getResource<Extractors>();
    if (extractors == null) {
      throw StateError(
        'LightingPlugin requires RenderPlugin to be added first '
        '(RenderPlugin inserts the shared Extractors registry that '
        'LightExtractor registers into).',
      );
    }
    extractors.register(LightExtractor());
  }

  @override
  void cleanup() {}
}
