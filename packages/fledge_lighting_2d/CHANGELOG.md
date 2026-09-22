## 0.3.0

 - **FIX**(fledge_lighting_2d): camera-aware additive light pass fills the visible world viewport. ([23bae1ac](https://github.com/fledge-framework/fledge/commit/23bae1acc5358817a3a469ee8000f379e21e46bf))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_lighting_2d): optional AmbientLight.bounds clips the overSprites multiply. ([e6429852](https://github.com/fledge-framework/fledge/commit/e64298524b34d0fcdcb755570f262c67727e75c1))
 - **FEAT**: camera-aware widget render path. ([6b8ff1b7](https://github.com/fledge-framework/fledge/commit/6b8ff1b7f1eaf6a930a73d7a4c5a0c4e26f12385))
 - **FEAT**(fledge_lighting_2d): AmbientBlend.overSprites — ambient darkens sprites too. ([7d0c33db](https://github.com/fledge-framework/fledge/commit/7d0c33dbb8bb5bb6a89b4d73faecfa04d2780a07))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

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
