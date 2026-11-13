import 'package:fledge_ecs/fledge_ecs.dart' show App;
import 'package:fledge_render_2d/fledge_render_2d.dart' show FledgeRenderView;
import 'package:flutter/widgets.dart';

/// The lighting-aware render view from before lighting became a view pass.
///
/// `LightingPlugin` now adds the lighting to every `FledgeRenderView` of
/// the app (see `LightingViewPass`), so this is a plain `FledgeRenderView`.
@Deprecated(
  'Use FledgeRenderView: LightingPlugin lights every FledgeRenderView now.',
)
class LitFledgeRenderView extends StatelessWidget {
  /// The Fledge app whose render world will be painted.
  final App app;

  /// Creates a lighting-aware render view.
  const LitFledgeRenderView({super.key, required this.app});

  @override
  Widget build(BuildContext context) => FledgeRenderView(app: app);
}
