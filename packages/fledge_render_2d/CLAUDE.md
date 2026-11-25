# fledge_render_2d

## Purpose
2D render infrastructure (two-world extraction, render graph, backends) plus 2D components and systems: Transform2D, Sprite, Animation, Material, TextureAtlas, SpriteBatch, and screen transitions. Absorbed the former `fledge_render` package.

## Status: Good

## Stats
- Source: 44 files, ~5,750 LOC
- Tests: 17 files (incl. `test/render/`), ~4,060 LOC
- TODOs in code: 0

## What Works
- Transform2D with position, rotation, scale, and parent-relative transforms
- Fixed-step render interpolation via opt-in `PreviousTransform2D`
- Sprite rendering with texture regions, anchors, flip, layers (`DrawLayer`)
- Sprite animation with frame sequences and playback control
- Material system for shader parameters
- TextureAtlas layouts and lookup
- SpriteBatch for efficient batched draw calls
- Canvas and GPU backends (`RenderBackend.canvas` / `.gpu`)
- Fade transitions (`TransitionState`, `TransitionFadeSystem`, `TransitionCompleted` event)

## Gaps
- **[P2]** Camera viewport math lives in `fledge_camera_2d` (`Camera2D` is no longer in this package); only `ActiveCameraView` / `CameraView` data types remain here

## Action Items
1. Add tests for Transform2D hierarchy (parent-child transform composition)

## Architecture Notes
- **Entry point**: `lib/fledge_render_2d.dart` (barrel export)
- **Two-world model**: `RenderWorld` (`lib/src/render/world/render_world.dart`) is cleared and rebuilt each frame by `RenderExtractionSystem`, which runs every `Extractor` registered on the `Extractors` resource (`lib/src/render/extract/extract.dart`). Never keep game state in the render world.
- **RenderPlugin** (`lib/src/render/plugin/render_plugin.dart`): Inserts `Extractors`, `RenderWorld`, `RenderBackendResource`, `Assets<Texture>`, and a `SpriteDrawer` matched to the backend (`CanvasSpriteDrawer` / `GpuSpriteDrawer`, `lib/src/backend/`); registers the `TransitionCompleted` event; adds `RenderExtractionSystem` (name `'renderExtraction'`) to `Schedules.extract`. It does **not** register transform/animation/transition systems — games add those.
- **Transform2D** (`lib/src/transform/transform2d.dart`): Local position, rotation, scale. Converts to Matrix3 via `toMatrix()`.
- **GlobalTransform2D** (`lib/src/transform/global_transform.dart`): World-space Matrix3, read-only. Computed by `TransformPropagateSystem` (`propagate.dart`) — two-pass: roots copy local→global, then children multiply parent.global × child.local.
- **PreviousTransform2D** (`lib/src/transform/previous_transform.dart`): Snapshot written by `SnapshotPreviousTransformSystem` (register in `Schedules.fixedFirst`); `SpriteExtractor` lerps translation using `FixedTimestep.alpha`.
- **Sprite** (`lib/src/sprite/sprite.dart`): Textured quad (`TextureHandle`) with sourceRect, color, flip, anchor (0-1 normalized). Also defines `Visibility`. `SpriteBundle` bundles the common components.
- **TextureAtlas** (`lib/src/atlas/texture_atlas.dart`): Layouts via `GridAtlasLayout` or `RectAtlasLayout` (`atlas_layout.dart`). `AtlasSprite` references atlas by mutable index — `AnimateSystem` swaps frames by updating index.
- **Animation** (`lib/src/animation/`): `AnimationClip` (frame sequence with looping), `AnimationPlayer` (playback state machine with play/pause/resume/stop). `AnimateSystem` updates player by deltaTime, syncs AtlasSprite index and Sprite sourceRect; `AnimateSystemWithResource` reads an `AnimationTime` resource instead.
- **SpriteBatch** (`lib/src/batch/sprite_batch.dart`): `SpriteBatchSystem` (a `RenderSystem`) collects `ExtractedSprite`s, sorts with `ExtractedSprite.sortByDrawOrder` (`sortKey`, then `preciseSubOrder`, stable), merges only **contiguous** same-texture runs into a `SpriteBatch` (so a texture can appear in several batches; `SpriteBatches.all` is in draw order), computes dest rects. Same strategy as `renderSpritesToDrawer`. Tests: `test/sprite_batch_order_test.dart`.
- **Material2D** (`lib/src/material/material2d.dart`): Abstract base with `BlendMode`, `ShaderHandle`, and typed `UniformValue` subclasses; `ShaderMaterial`, `SpriteMaterial`, `ColorMaterial` concrete types.
- **Extraction** (`lib/src/sprite/extracted_sprite.dart`): `SpriteExtractor` copies Sprite + GlobalTransform2D → immutable `ExtractedSprite` (pre-computed sort key, flip flags). Checks Visibility component.
- **Flip** (`lib/src/backend/canvas_render_context.dart`): `flipX`/`flipY` mirror in sprite-local space (about the anchor, along the sprite's own axes) before the entity transform: `world = transform * diag(±1, ±1) * local`. Flipped sprites always take the per-sprite affine path (`_drawAffineSprite`). Pixel tests: `test/sprite_flip_local_test.dart`.
- **Render graph / stages** (`lib/src/render/graph/`, `lib/src/render/stages/`): `RenderGraph` of `RenderNode`s (e.g. `SpriteRenderNode`), `RenderSchedule` + `RenderStage` for render-world systems; `RenderLayer` variants in `lib/src/render/layer/`.
- **Widget** (`lib/src/widget/fledge_render_view.dart`): `FledgeRenderView` draws the render world; uses `ActiveCameraView` (`lib/src/render/camera_view.dart`) when set, else world = screen.
- **System names**: use the constants in `before:` / `after:` — `TransformPropagateSystem.systemName` (`'transform_propagate'`), `SnapshotPreviousTransformSystem.systemName` (`'snapshot_previous_transform'`), `AnimateSystem.systemName` (`'animate'`), `AnimateSystemWithResource.systemName` (`'animate_with_resource'`), `TransitionFadeSystem.systemName` (`'TransitionFadeSystem'`).
- **Facing** (`lib/src/character/facing.dart`): continuous facing angle for N-view sprites alongside the 4-way `Orientation`; `facingViewIndex(angle, n)` — view 0 = +x, clockwise on screen (same as `Transform2D.rotation`). State only; no system reads it here.
- **Key pattern**: Atlas → AnimationPlayer → AtlasSprite.index → Sprite.sourceRect — decoupled so each piece is independently swappable.
- **Tests**: Flutter package — run with `flutter test`.
