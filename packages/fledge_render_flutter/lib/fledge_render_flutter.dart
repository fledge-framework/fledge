/// Flutter integration for Fledge rendering.
///
/// **DEPRECATED**: This package has been merged into `fledge_render`.
/// All exports are now available directly from `package:fledge_render/fledge_render.dart`.
///
/// Migration:
/// ```dart
/// // Before
/// import 'package:fledge_render_flutter/fledge_render_flutter.dart';
///
/// // After
/// import 'package:fledge_render/fledge_render.dart';
/// ```
///
/// This package now re-exports from `fledge_render` for backwards compatibility
/// but will be removed in a future release.
@Deprecated('Use package:fledge_render/fledge_render.dart instead')
library;

// Re-export from fledge_render for backwards compatibility
export 'package:fledge_render/fledge_render.dart'
    show
        RenderLayer,
        CompositeRenderLayer,
        TransformedRenderLayer,
        ClippedRenderLayer,
        ConditionalRenderLayer,
        RenderWorld;
