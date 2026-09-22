## 0.3.1

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_ui): placement mode. ([7a378aef](https://github.com/fledge-framework/fledge/commit/7a378aeff4540bfc9b78f4755875ac02fbd153d0))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

## 0.3.0

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_ui): placement mode. ([8316d6de](https://github.com/fledge-framework/fledge/commit/8316d6decd15d9d98b4250aba965e29c2458a25b))
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
- Retained-mode HUD components: `UiText`, `UiImage`, `UiRect`, `UiContainer`.
- Anchor-based `LayoutSystem`.
- `FledgeUiOverlay` widget rendered on top of the sprite pipeline.


## [0.1.0] - 2026-09-20

### Added

- Initial release. Phase 7 of the Fledge restructure.
- `UiNode`, `UiSize`, `UiOffset`, `UiComputedRect` — foundational
  components.
- `UiAnchor` enum + `UiAnchorComponent` — 9-way anchor within the
  parent's rect.
- `UiContainer` + `LayoutMode` (`stack` / `row` / `column`) — layout
  container with padding and gap.
- `UiText` — mutable-text HUD label.
- `UiImage` — textured UI quad wrapping `TextureHandle`.
- `UiRect` — solid-colour panel with optional `borderRadius`.
- `LayoutSystem` — runs in `Schedules.postUpdate`, walks the UI
  hierarchy from roots (UI nodes with no `Parent`), writes
  `UiComputedRect` on every UI entity.
- `UiExtractor` — mirrors `SpriteExtractor`'s shape; emits
  `ExtractedUiImage` / `ExtractedUiRect` / `ExtractedUiText` on the
  render world for the widget paint pass.
- `FledgeUiOverlay` widget — layers a UI paint pass on top of any
  Fledge render view. Renders images via `Canvas.drawImageRect`,
  rects via `Canvas.drawRect` / `drawRRect`, text via
  `Canvas.drawParagraph`.
- `UiPlugin` — wires the layout system and registers the extractor.

### Deferred to phase 7b

- Focus + keyboard/gamepad navigation.
- Flexbox / grid layouts.
- Theming / styles system.
- Font bundling.
