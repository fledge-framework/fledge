## 0.3.1

 - **FIX**(fledge_camera_2d): CameraFollow.marker stays quiet until a target appears. ([d1894e64](https://github.com/fledge-framework/fledge/commit/d1894e645754d3a9418e273826b8d14a80e52c2f))
 - **FIX**(fledge_camera_2d): order ActiveCameraViewSystem after transform_propagate. ([42af6b8b](https://github.com/fledge-framework/fledge/commit/42af6b8baf01bcfc3f58d0c37392cc1912d7a4d1))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_camera_2d): expose CameraFollowSystem.systemName and ActiveCameraViewSystem.systemName. ([d42ccd1e](https://github.com/fledge-framework/fledge/commit/d42ccd1eb519d38eb71fc91e7787914cada05f75))
 - **FEAT**(fledge_render_2d): pixel-snap the camera canvas offset when pixelPerfect. ([3137dc16](https://github.com/fledge-framework/fledge/commit/3137dc16178b2d2c35eb4aa9d6d08eae13ccdbe9))
 - **FEAT**: camera-aware widget render path. ([6b8ff1b7](https://github.com/fledge-framework/fledge/commit/6b8ff1b7f1eaf6a930a73d7a4c5a0c4e26f12385))
 - **FEAT**(fledge_camera_2d): CameraFollow updates root camera GlobalTransform2D + marker target. ([4794cfc9](https://github.com/fledge-framework/fledge/commit/4794cfc90072f4ba2c1b05ba3881bb69d71ca3db))
 - **FEAT**(fledge_camera_2d): CameraFollowSystem — declare order + honour pixelPerfect. ([e7a77ef0](https://github.com/fledge-framework/fledge/commit/e7a77ef06b9f96d57dce359a2223212b37ea7f2d))
 - **FEAT**(fledge_render_2d): render interpolation between fixed ticks. ([6179b2d5](https://github.com/fledge-framework/fledge/commit/6179b2d5d1392d5719448521f100bbac640b6b7a))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

## 0.3.0

 - **FIX**(fledge_camera_2d): CameraFollow.marker stays quiet until a target appears. ([d1894e64](https://github.com/fledge-framework/fledge/commit/d1894e645754d3a9418e273826b8d14a80e52c2f))
 - **FIX**(fledge_camera_2d): order ActiveCameraViewSystem after transform_propagate. ([42af6b8b](https://github.com/fledge-framework/fledge/commit/42af6b8baf01bcfc3f58d0c37392cc1912d7a4d1))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_render_2d): pixel-snap the camera canvas offset when pixelPerfect. ([3137dc16](https://github.com/fledge-framework/fledge/commit/3137dc16178b2d2c35eb4aa9d6d08eae13ccdbe9))
 - **FEAT**: camera-aware widget render path. ([6b8ff1b7](https://github.com/fledge-framework/fledge/commit/6b8ff1b7f1eaf6a930a73d7a4c5a0c4e26f12385))
 - **FEAT**(fledge_camera_2d): CameraFollow updates root camera GlobalTransform2D + marker target. ([4794cfc9](https://github.com/fledge-framework/fledge/commit/4794cfc90072f4ba2c1b05ba3881bb69d71ca3db))
 - **FEAT**(fledge_camera_2d): CameraFollowSystem — declare order + honour pixelPerfect. ([e7a77ef0](https://github.com/fledge-framework/fledge/commit/e7a77ef06b9f96d57dce359a2223212b37ea7f2d))
 - **FEAT**(fledge_render_2d): render interpolation between fixed ticks. ([6179b2d5](https://github.com/fledge-framework/fledge/commit/6179b2d5d1392d5719448521f100bbac640b6b7a))
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
