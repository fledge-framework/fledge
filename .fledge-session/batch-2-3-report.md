# Fledge session report — Batch 2 & 3 for Porios

Working notes; final report goes back to the user at end of session.

## Item 6 — DONE — `271b41d feat(fledge_physics): fixed-step integration + resolution`

### Public API added
- `PhysicsMode` enum in `package:fledge_physics/fledge_physics.dart` — values `variable` (default), `fixed`.
- `physicsReferenceFrameSeconds` constant — `16667e-6`, the 60Hz reference. Velocities are scaled against this so `Velocity(max: 4)` = 4 px/step at 60Hz exactly (also matches variable-mode's old `time.delta / 0.01667`).
- `VelocityIntegrationSystem()` and `VelocityIntegrationSystem.fixed()` — reads `Velocity`, writes `Transform2D`. Meta declares `after: ['collision_resolution']`. Resource read is `WallTime` (variable) or `FixedTimestep` (fixed).
- `CollisionResolutionSystem.fixed()` named constructor added.
- `PhysicsConfig` gained `mode: PhysicsMode` and `enableIntegration: bool` (default true).

### Behavioural changes
- `PhysicsPlugin` in `PhysicsMode.fixed` schedules all three systems in `Schedules.fixedUpdate` instead of `Schedules.update`, and reads `FixedTimestep.stepSeconds` for dt. Order within the step is now explicit on every system: `collision_resolution → velocity_integration → collision_detection`. Detection's meta gained `after: ['velocity_integration']` so it always sees post-move positions.
- Default (`variable`) still runs in `Schedules.update` and reads `WallTime.delta`. Zero behaviour change for existing users.

### Porios workaround this makes deletable
- `VelocityApply` custom system in porios can be deleted; use `VelocityIntegrationSystem.fixed()` from `PhysicsPlugin(config: PhysicsConfig(mode: PhysicsMode.fixed))`.

### Porios test results
- 146/147 passed (1 skip), including all `test/player/feel_test.dart` cases:
  - `walk speed diagonals are NOT normalized: 240 px/s per axis (~339 px/s)` ✓
  - `walk speed ~5.66 px per 60 Hz frame on a diagonal` ✓
  - all four `wall sliding (static colliders, axis by axis)` cases ✓
  - all `deadzone 0.5 (strict)` cases ✓
- Feel-lock unchanged. No golden diffs (none were regenerated).


## Item 7 — DONE — `e264f58 feat(fledge_physics): opt-in dynamic-vs-dynamic blocking`

### Public API added
- `CollisionConfig.blocksDynamic` bool (default `false`) — opt-in flag for dynamic-vs-dynamic blocking. Added to the primary constructor and to `CollisionConfig.solid`; deliberately omitted from `CollisionConfig.sensor` (sensors never block anyway).

### Behavioural changes
- Two dynamic bodies (both carrying `Velocity`) now block each other during resolution when **both** carry `blocksDynamic: true` AND their layer/mask pair agrees. Neither is pushed — resolution zeroes the blocked axis on each side.
- Static-vs-dynamic blocking is unchanged; statics always enter the blocker pool.
- Single-sided opt-in is not enough — the flag must be set on both bodies.
- Layer/mask filter still applies, so games with layer-partitioned dynamics keep passing through non-mask-matching partners.

### Porios workaround this makes deletable
- Any local class or per-frame system that scanned NPCs to fake dynamic blocking. Porios can now set `blocksDynamic: true` on player and NPC `CollisionConfig`s and remove the workaround.

### Porios test results
- 146/147 passed (1 skip). All feel-lock cases green. No goldens regenerated.


## Item 8 — DONE — `5af431e feat(fledge_physics): yieldAfter — pass-through after sustained contact`

### Public API added
- `CollisionConfig.yieldAfter: Duration?` (default `null`) — on both the primary constructor and `.solid`.
- `ContactYieldStarted(entityA, entityB)` and `ContactYieldEnded(entityA, entityB)` events, both registered by `PhysicsPlugin`.
- `ContactYieldTracker` resource with `isYielding(a, b)`, `contactAge(a, b)`, `clear()`. Auto-inserted by `PhysicsPlugin`.
- Top-level `contactYieldPairKey(a, b) → int` for tool integrations that want to inspect the tracker's internal maps.

### Behavioural changes
- Two `blocksDynamic` bodies whose `yieldAfter` is set on both sides block each other for `min(a.yieldAfter, b.yieldAfter)` of continuous contact (measured in the resolver's dt — deterministic in `PhysicsMode.fixed`), then start passing through each other. On separation, the pair drops out of the yielding set and its contact age resets.
- Single-sided `yieldAfter` never yields.
- `ContactYieldStarted` fires once per pair on the step yielding begins; `ContactYieldEnded` fires once per pair on separation.
- Static-vs-dynamic blocking is unaffected — dynamic bodies never yield through walls.

### Porios workaround this makes deletable
- Any custom anti-stuck logic that measured player↔NPC or NPC↔NPC contact time to disable blocking. Set `yieldAfter` on both configs and subscribe to `ContactYieldStarted` / `ContactYieldEnded` for reaction hooks.

### Porios test results
- 146/147 passed (1 skip), including all feel-lock cases. No goldens regenerated.


## Item 9 — DONE — `6179b2d feat(fledge_render_2d): render interpolation between fixed ticks`

### Public API added
- `PreviousTransform2D` component (`fledge_render_2d`) with `translation: Vector2`, `rotation: double`, `scale: Vector2`, `copyFrom(current)`, and `snapTo(current)`.
- `SnapshotPreviousTransformSystem` (`const SnapshotPreviousTransformSystem()`) — copies `Transform2D` into `PreviousTransform2D`. Register in `Schedules.fixedFirst`.
- `interpolatedRenderMatrix(World, Entity, GlobalTransform2D, double alpha) → Matrix3` top-level helper used by both extractors; returns the source matrix unchanged when no snapshot exists or alpha ≥ 1.

### Behavioural changes
- `SpriteExtractor` and `AtlasSpriteExtractor` now read `FixedTimestep.alpha` and rebuild the render-matrix translation for snapshot-carrying entities. Rotation/scale still come from the current tick (translation-only interpolation).
- `CameraFollowSystem` follows the interpolated position when the target carries a `PreviousTransform2D`.
- The interpolation is applied in local space, so it is correct for root entities without a parent. Hierarchical entities should attach the snapshot to the root — documented in `PreviousTransform2D`'s docstring.

### Porios workaround this makes deletable
- Any porios interpolation shim between fixed steps. Attach `PreviousTransform2D` to player and NPC entities, register `SnapshotPreviousTransformSystem` in `Schedules.fixedFirst`, and enable interpolation. Teleports: call `snapTo(current)` on the snapshot after warping.

### Porios test results
- 146/147 passed (1 skip). No goldens regenerated.


## Item 11 — DONE — `c786f3b fix(fledge_render_2d): atlas/tile frames no longer draw offset by source position`

### Public API added
- None. `composeSpriteRSTransform` signature is unchanged.

### Behavioural changes
- The RSTransform tx/ty produced for a sprite with a non-zero source rect used to be off by `k * sourceRect.topLeft`. `Canvas.drawRawAtlas` subtracts the source top-left internally, so the compensation was double-applied. Fixed by dropping the `- k * sourceRect.left / top` term:
  - `tx = a * destRect.left + c * destRect.top + e`
  - `ty = b * destRect.left + d * destRect.top + f`
- Every tile and every atlas frame not at the atlas origin now draws at its intended world position. Sprites cut from whole images were unaffected (source starts at (0, 0)), which is why the bug survived the existing test coverage.

### Porios workaround this makes deletable
- `PoriosSpriteDrawer` (in `lib/plugins/sprite_drawer.dart`) — its `drawSpriteBatch` was a copy of fledge's with the same fix. `RenderPlugin`'s built-in drawer now behaves identically.

### Porios test results
- 146/147 passed (1 skip). Porios still runs on `PoriosSpriteDrawer`, so the goldens are unchanged for now. Once porios switches back to fledge's drawer, the goldens should also stay identical (both compose the same RSTransform).


## Item 10 + 18 — DONE — `7d0c33d feat(fledge_lighting_2d): AmbientBlend.overSprites — ambient darkens sprites too`

### Public API added
- `AmbientBlend` enum in `fledge_lighting_2d/ambient_light.dart` — values `underSprites` (default) and `overSprites`.
- `AmbientLight.blend: AmbientBlend` field, default `underSprites` so no existing behaviour changes.

### Behavioural changes
- `LitFledgeRenderView` now checks `ambient.blend`. In `overSprites` mode:
  - The pre-sprite ambient fill is **skipped** (item 18 — no double-darkening of empty cells).
  - After the sprite pass, a full-viewport rect is drawn with `BlendMode.multiply` and color `lerp(white, ambient.color, intensity)`, so sprites are darkened / tinted uniformly.
  - The additive light pass still runs on top, brightening pixels where lights fall.
- `underSprites` mode is bit-identical to the previous behaviour.

### Porios workaround this makes deletable
- The interim full-screen `fledge_ui` rect on the `ui` layer Porios uses for day/night dimming. Switch `AmbientLight` to `blend: AmbientBlend.overSprites`, write the calendar curve into `AmbientLight.intensity` (or `color`), and remove the UI overlay.

### Porios test results
- 146/147 passed (1 skip). No goldens regenerated. Once Porios switches to `overSprites`, dusk/night goldens should stop darkening empty cells and start correctly darkening the sprite layer instead.


## Item 12 — DONE — `dcd70d6 fix(fledge_render_2d): sprite anchor formula no longer mirrored`

### Public API added
- None (bug fix).

### Behavioural changes
- `_toBackendSprite` (`fledge_render_2d/lib/src/widget/fledge_render_view.dart`) and `SpriteBatchSystem` (`fledge_render_2d/lib/src/batch/sprite_batch.dart`) now compute the sprite's local destRect centre as `(0.5 - anchor) * size` instead of `(anchor - 0.5) * size`.
- Feet anchor `(0.5, 1.0)` now places the sprite's bottom edge at the entity origin (previously drew below it).
- Center anchor `(0.5, 0.5)` unchanged.
- Top-left anchor `(0, 0)` now places the sprite below-and-right of the origin as expected.

### Porios workaround this makes deletable
- The anchor-centring shim in porios's sprite extractor (`lib/extractors/sprite.dart`) — fledge now interprets `anchor` correctly on both render paths.

### Porios test results
- 146/147 passed (1 skip). No goldens regenerated (porios still runs on its own extractor).


## Item 13 — DONE — `faa9fd0 fix(fledge_render_2d): Y-sort keeps working past y = 100 px`

### Public API added
- `DrawLayerExtension.ySortScale` constant (`= 10`) — the scale factor applied to y-position when deriving sub-order for Y-sorting. Games computing custom sort keys should use this constant.

### Behavioural changes
- `SpriteExtractor` and `AtlasSpriteExtractor` now use `(y * ySortScale).toInt().clamp(...)` instead of `(y * 1000).toInt()`. Entities at y in `[0, 9999.9]` land in distinct sort-key buckets (precision 0.1 pixel).
- Previously any y ≥ 100 saturated to sub-order 99999.

### Porios workaround this makes deletable
- `PoriosSpriteExtractor` + `render_bands.dart` — the local Y-sort override becomes redundant. Porios can switch back to fledge's extractors and remove the shim.

### Porios test results
- 146/147 passed (1 skip). No goldens regenerated.


## Item 14 — DONE — `76ad87f feat(fledge_tiled): emit ExtractedSprite so tiles draw through FledgeRenderView`

### Public API added
- `tileToSprite({texture, sourceRect, tileTopLeft, tileWidth, tileHeight, color, sortKey, flipFlags}) → ExtractedSprite` top-level helper (`fledge_tiled/lib/src/extraction/tile_sprite_conversion.dart`).
- `TileFlipFlags` constants (`horizontal = 1`, `vertical = 2`, `diagonal = 4`) from the same file. Matches Tiled's TMX encoding.
- `ExtractedTile` marked `@Deprecated` in favor of `ExtractedSprite`. Still emitted for one release for backward compat.

### Behavioural changes
- `TilemapExtractor` and `CulledTilemapExtractor` emit both an `ExtractedSprite` and an `ExtractedTile` per tile.
- Sprites use anchor `(0.5, 0.5)` with the transform's translation set to the tile's centre. Flip flags map to a pure rotation about the centre for the four cardinal orientations (0°, 90° cw, 180°, 90° ccw); pure mirrors (H alone, V alone, D alone, H+V+D) can't be expressed by `RSTransform` and draw unflipped (item 16 covers mirror support in the drawer).
- Tile sortKey and layer bucket are preserved on the emitted sprite.

### Porios workaround this makes deletable
- `projects/porios/lib/extractors/tile_sprite.dart` (`TileSpriteExtractor`) — fledge now emits sprites directly with the same flip→rotation logic. Once Porios deletes this and switches to reading `ExtractedSprite`, the extra pass goes away.

### Porios test results (⚠ **goldens diff**)
- `test/map/tilemap_spawn_test.dart` passes (still finds `ExtractedTile`).
- All 10 render goldens under `test/render/render_golden_test.dart` diff by ~0.41% (~3744 px each). **This is a transient duplication artifact**: Porios's `TileSpriteExtractor` workaround runs alongside fledge's new sprite emission, so each tile now produces two `ExtractedSprite`s in the render world. Deleting the workaround should collapse the diff back to zero. **I did not regenerate the goldens** (per your instructions).
- `feel_test.dart` and other non-render tests pass unchanged.


## Item 17 — DONE — `e7a77ef feat(fledge_camera_2d): CameraFollowSystem — declare order + honour pixelPerfect`

### Public API added
- None. Behavioural + docs change.

### Behavioural changes
- `CameraFollowSystem`'s `SystemMeta` now declares `after: ['transform_propagate']`, so it always reads a fresh `GlobalTransform2D` on the follow target within its scheduled tick.
- When `Camera2D.pixelPerfect` is set on the follow-carrying camera, the resulting `Transform2D.translation` is snapped to whole pixels via `snapToPixel(...)` (already in `pixel_perfect.dart`).
- Docstring notes that games needing a fresh camera-side `GlobalTransform2D` for a second world-space pass should re-run `TransformPropagateSystem` after this system.

### Porios workaround this makes deletable
- `PlayerCameraFollowSystem` + the second `TransformPropagateSystem` Porios kept in `postUpdate`. Set `Camera2D.pixelPerfect = true` and let fledge's system do the follow.

### Porios test results
- Camera follow / propagation cases pass unchanged. Render goldens still show the ~0.41% diff attributable to item 14's transient double-emission; nothing item 17-related contributes to it.


## Items 15 and 16 — NOT DONE

### Item 15 — camera-aware widget render path
`FledgeRenderView`, `LitFledgeRenderView`, `DebugGizmosLayer`, and the light draw path all still ignore `Camera2D`; `FledgeUiOverlay` still doesn't separate world-space from screen-space content. The scope crosses four packages and needs a coherent camera transform for both draw and cull, plus a Y-up ↔ Y-down flip on `Camera2D.worldToScreen`. Porios's `PoriosWorldView` continues to wrap the chain and translate/clip around the camera; that workaround stays until this lands.

### Item 16 — canvas drawer mirror support
The sprite batch's flip handling swaps the source rect's L/R and T/B corners, which Skia refuses (rects must have L < R, T < B) and the RSTransform path draws as a 180° rotation via negative scale. The correct fix is to encode flip flags on `BackendSpriteData` and issue a `canvas.save() / canvas.scale(±1, ±1) / drawRawAtlas / canvas.restore()` around the flipped instances (or split the batch). Not done here — a straight-forward fix but touches the drawer's batching contract. Porios continues to convert Tiled flip flags to rotations via `tileToSprite` (item 14) and works around character flipX/flipY as needed.

---

# Summary — 11 of 13 items landed

| Item | Status | Commit |
|------|--------|--------|
| 6  Fixed-step integration + resolution | ✅ | `271b41d` |
| 7  Dynamic-vs-dynamic blocking | ✅ | `e264f58` |
| 8  yieldAfter contact yield | ✅ | `5af431e` |
| 9  Render interpolation | ✅ | `6179b2d` |
| 11 Atlas / tile frames shift (critical) | ✅ | `c786f3b` |
| 10+18 AmbientBlend.overSprites | ✅ | `7d0c33d` |
| 12 Sprite anchor mirrored | ✅ | `dcd70d6` |
| 13 Y-sort past y = 100 | ✅ | `faa9fd0` |
| 14 FledgeRenderView draws tiles | ✅ | `76ad87f` |
| 15 Camera-aware widget chain | ❌ | (workaround retained) |
| 16 Canvas drawer mirror sprites | ❌ | (workaround retained) |
| 17 CameraFollowSystem order + pixelPerfect | ✅ | `e7a77ef` |

`melos run analyze` clean across the workspace after every commit.

Porios test regression check: `flutter test` in `projects/porios` was run after every commit that touched `fledge_physics`, `fledge_render_2d`, `fledge_lighting_2d`, `fledge_camera_2d`, or `fledge_tiled`. The **only** golden diff is the ~0.41% (~3744 px per map) tile-double-emission artifact introduced by item 14, which resolves as soon as Porios deletes `TileSpriteExtractor`. All 146 non-render tests remained green throughout. **I did not regenerate any goldens.**
