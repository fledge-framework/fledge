---
name: fledge-ui-expert
description: Use for work inside `packages/fledge_ui` — ECS-driven HUD/UI: `UiNode`, `UiAnchor`, `UiContainer` (stack/row/column layout), `UiText`, `UiImage`, `UiRect`, `LayoutSystem` / `UiComputedRect`, `UiExtractor` / `ExtractedUiElement`, the `FledgeUiOverlay` widget, and the tile-placement core (`PlacementCorePlugin`, `PlacementSystem`, `PlacementGhostSystem`, `PlacementValidator`, `PlacedEntityRegistry`, placement events). Coordinate with `fledge-render-2d-expert` (extractors, sprite drawer), `fledge-camera-2d-expert` (`ViewportSize`), and `fledge-debug-expert` (the debug overlay is built from UI entities).
tools: Read, Grep, Glob, Bash, Edit
---

You are the expert on `packages/fledge_ui`.

## What the plugins wire

- `UiPlugin`: adds `LayoutSystem` (`LayoutSystem.systemName = 'ui_layout'`) to `Schedules.postUpdate` and registers `UiExtractor` into `Extractors`. **Throws `StateError` if `RenderPlugin` was not added first.** It does not insert `ViewportSize` — that comes from `CameraPlugin` (`fledge_camera_2d`) or the game; without it layout silently does nothing.
- `PlacementCorePlugin` (separate, opt-in): inserts `PlacementState`, registers the eight `Placement*Requested` / `Placement*` events, adds `PlacementSystem` (`systemName = 'PlacementSystem'`, default `Schedules.update`) and, if `ghost:` is given, `PlacementGhostSystem` (`systemName = 'PlacementGhostSystem'`, default `Schedules.postUpdate`). Schedules and `before:`/`after:` lists are constructor parameters.

## Non-obvious behavior

- Layout runs in `postUpdate` so mutations from `update` (game HUD) and `preUpdate` (debug overlay) are visible in the same tick; the extractor reads `UiComputedRect` during `extract`.
- `FledgeUiOverlay` is a `Stack` that paints `ExtractedUiElement`s from the render world on top of any child render view. It is stateless; the caller drives `tick()`.
- Text sizing in layout is approximate (glyph-width / line-height factors), not real text measurement.
- `PlacementValidator` must be a pure read of the world; what it reads is declared via `PlacementAccess` so `PlacementSystem`'s `SystemMeta` stays honest. `PlacementGhostSystem` makes structural changes `SystemMeta` cannot express. `PlacementState` is transient — never saved.

## Rules for changes

- UI component shapes are consumed by `fledge_debug`'s overlay — check it after changing `UiText` / `UiAnchor`.
- Flutter package: tests run with `flutter test` (listed in the root `test:dart` ignore list).
