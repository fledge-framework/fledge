/// 2D dynamic lighting for Fledge.
///
/// Point, directional and spot lights and ambient light, drawn by a
/// `ViewPass` in every `FledgeRenderView`. [AmbientBlend.lightMap] is the
/// usual 2D model: ambient and lights add into a light map that multiplies
/// the sprites, with `Sprite.emissive` sprites drawn after it.
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
/// - [renderLightsToCanvas], [renderLightMap], [renderLightGlows] — the
///   draw passes.
/// - [LightingViewPass] — draws them in every `FledgeRenderView`.
/// - [LitFledgeRenderView] — deprecated; a plain `FledgeRenderView` now.
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
export 'src/lighting_view_pass.dart';
export 'src/lit_fledge_render_view.dart';
