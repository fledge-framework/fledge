/// Linear light attenuation, `1.0` at (or inside) [innerRadius], smoothly
/// falling to `0.0` at (or past) [radius].
///
/// The math matches the additive gradient stops used by
/// [LitFledgeRenderView] and `renderLightsToCanvas`: pixels closer than
/// `innerRadius` sit at full color, pixels at `radius` and beyond
/// contribute nothing, and pixels in between are linearly blended.
///
/// If `innerRadius >= radius`, the function collapses to a hard cutoff
/// at `radius` (values below `radius` are `1.0`, values at/past are
/// `0.0`) — the same behaviour a caller would get from a zero-width
/// falloff band.
double linearAttenuation(double distance, double innerRadius, double radius) {
  // Radius wins over innerRadius when they cross: past the outer
  // radius the light contributes nothing, no matter how the inner
  // radius was set. This keeps degenerate configurations (e.g.
  // callers that raised `innerRadius` above `radius` by mistake)
  // rendering "off" instead of full-bright.
  if (distance >= radius) return 0.0;
  if (distance <= innerRadius) return 1.0;
  final band = radius - innerRadius;
  if (band <= 0) return 0.0;
  return 1.0 - (distance - innerRadius) / band;
}
