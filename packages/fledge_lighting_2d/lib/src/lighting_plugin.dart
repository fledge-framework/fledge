import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart'
    show Extractors, ViewPasses;

import 'ambient_light.dart';
import 'light_extractor.dart';
import 'lighting_view_pass.dart';

/// Wires 2D lighting into an [App].
///
/// - Inserts the [AmbientLight] resource (adjust it at runtime, e.g. for
///   the time of day).
/// - Registers [LightExtractor] on the render pipeline's `Extractors`
///   registry. `RenderPlugin` must have already inserted that
///   resource — add `RenderPlugin` before `LightingPlugin` in your
///   plugin list.
///
/// - Adds [LightingViewPass] to the app's `ViewPasses`, so every
///   `FledgeRenderView` showing the app draws the lighting.
///
/// No per-tick systems run in the main world; the light draw happens in
/// the view pass on the paint thread.
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
    // Every FledgeRenderView of the app draws the lighting.
    app.world.getResource<ViewPasses>()?.add(const LightingViewPass());
  }

  @override
  void cleanup() {}
}
