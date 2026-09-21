/// 2D dynamic lighting for Fledge.
///
/// Phase 6c of the restructure: point / directional / spot lights,
/// ambient light, and a lighting-aware `CustomPaint` widget that
/// stacks the three passes (ambient → sprites → additive lights) on
/// top of the existing `fledge_render_2d` sprite pipeline.
///
/// ## Contents
///
/// - [Light2D], [LightType] — light component + kind.
/// - [Light2D.point], [Light2D.directional], [Light2D.spot] —
///   convenience constructors.
/// - [AmbientLight] — scene-wide base illumination (resource).
/// - [ExtractedLight] — render-side data.
/// - [LightExtractor] — extractor mirroring `SpriteExtractor`.
/// - [linearAttenuation] — falloff math shared with the drawer.
/// - [renderLightsToCanvas] — the additive-light draw pass.
/// - [LitFledgeRenderView] — lighting-aware widget wrapper.
/// - [LightingPlugin] — wires the extractor + ambient resource.
///
/// Shadow tracing, per-pixel normal-mapped lighting, and cookie
/// textures are future work — see the README's "Future work"
/// section.
library;

export 'src/ambient_light.dart';
export 'src/attenuation.dart';
export 'src/extracted_light.dart';
export 'src/light2d.dart';
export 'src/light_extractor.dart';
export 'src/lighting_plugin.dart';
export 'src/lighting_render_node.dart';
export 'src/lit_fledge_render_view.dart';
