## 0.2.3

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

# Changelog

## [0.2.2] - 2026-09-21



## [0.2.1] - 2026-09-20

### Changed

- SDK floor bumped to Dart `>=3.11.0` / Flutter `>=3.41.0` (was 3.6 / 3.38). Matches the workspace-wide floor.


## [0.2.0] - 2026-09-20

### Added

- Initial release; camera components extracted from `fledge_render_2d`.
- `CameraFollow`, `CameraShake`, `Parallax`, `Letterbox`.
- `CameraFadeTransition`, `CameraWipeTransition`.
- `IsometricProjection`, `ObliqueProjection`.


## [0.1.0] - 2026-09-20

### Added

- Initial release. Extracted from `fledge_render_2d`.
- `Camera2D`, `Projection`, `OrthographicProjection` moved from
  `fledge_render_2d`.
- `CameraDriverNode`, `ViewportSize`, `PixelPerfectVector2` moved from
  `fledge_render_2d`.
- `IsometricProjection` (2:1 isometric) and `ObliqueProjection`
  (parametric skew) added.
- `CameraFollow` component + `CameraFollowSystem` — smooth follow with
  damping.
- `CameraShake` component + `CameraShakeSystem` — trauma-based screen
  shake.
- `LetterboxConfig` — target-aspect letterbox / pillarbox baked into
  `OrthographicProjection`.
- `Parallax` component + `ParallaxSystem` — per-entity parallax scroll
  factor.
- `CameraFadeTransition`, `CameraWipeTransition` +
  `CameraTransitionSystem` — camera-level fade / wipe overlays.
- `CameraPlugin` wires all systems into `Schedules.postUpdate` with
  explicit ordering (follow → shake → parallax → transitions).
