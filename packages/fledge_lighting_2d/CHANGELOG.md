# Changelog

## [0.2.2] - 2026-09-21



## [0.2.1] - 2026-09-20

### Added

- `example/example.dart` demonstrating the package's core API (pana requirement).

### Changed

- SDK floor bumped to Dart `>=3.11.0` / Flutter `>=3.41.0` (was 3.6 / 3.38). Matches the workspace-wide floor.


## [0.2.0] - 2026-09-20

### Added

- Initial release.
- `Light2D` with point / directional / spot variants.
- `AmbientLight` resource.
- Additive Canvas passes composited on top of the sprite pipeline.
- `LitFledgeRenderView` widget.

### Deferred

- Shadow tracing / occlusion — planned for a later release.


## [0.1.0] - 2026-09-20

### Added

- Initial release. Phase 6c of the Fledge restructure.
- `Light2D` component with `LightType.point`, `LightType.directional`,
  and `LightType.spot`; factory constructors `Light2D.point`,
  `Light2D.directional`, `Light2D.spot`.
- `AmbientLight` resource — scene-wide base illumination with
  `AmbientLight.white` (dim 0.5) and `AmbientLight.dark` (0.2)
  presets.
- `ExtractedLight` render-side data and `LightExtractor` that mirrors
  `SpriteExtractor` and pulls world-space position off
  `GlobalTransform2D`.
- `LitFledgeRenderView` widget — a lighting-aware wrapper around
  `FledgeRenderView` that paints ambient background → sprites →
  additive lights on the same `CustomPaint`.
- `renderLightsToCanvas` helper — draws each `ExtractedLight` as an
  additive radial gradient (point / spot with a wedge clip / directional
  as a full-screen tint).
- `linearAttenuation` — 1.0 at (or inside) the inner radius,
  smoothly falls to 0.0 at the outer radius.
- `LightingPlugin` — inserts the ambient resource and registers
  `LightExtractor` on the render pipeline's `Extractors` registry.

### Future work

- SDF shadow tracing / occluder rasterization.
- Cookie textures (per-light masks).
- Per-pixel normal-mapped lighting — needs a `FragmentProgram`; the
  `Material.normalMap` slot ships as data plumbing only.
