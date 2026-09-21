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
