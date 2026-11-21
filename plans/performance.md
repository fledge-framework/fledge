# Performance plan (2026-11-15)

The follow-up to the 2026-11-15 performance review of Fledge and Tharsis Plateau: the six biggest remaining costs, each with its evidence, design, steps and how it's accepted. **This file is the source of truth while the work is under way**: read it first when resuming (after a compaction, in a new session), work the first unchecked step, and update the status here after every step, before moving on.

## How to resume

1. Read **Status** below; the first unchecked step is next. Steps are small enough to finish and verify one at a time.
2. Before an item's first change, take a **before** measurement; after its last, an **after** one (see Measuring). Write both into the item's Results.
3. Run the checks for what you touched (see Checks) before ticking a step.
4. Nothing is committed unless the user asks. Framework changes are committed in this repo (`feat(fledge_ecs): ...`, Conventional Commits scoped by package); game changes in `projects/tharsis-plateau` (its own repo).
5. A step that turns out wrong or riskier than planned: stop, write what was learned under the item, and ask the user rather than pushing through.

## Status

- [x] **1. Scheduler overhead** (fledge_ecs)
  - [x] 1.0 Per-system timer (`Scheduler.systemTimer`, `SystemTiming`) and the profiler (`projects/tharsis-plateau/game/tool/profile_test.dart`) — done in the review
  - [x] 1.1 Sequential stage executor over a precomputed order
  - [x] 1.2 `System.run` returns `FutureOr<void>`; sync systems return without a Future; the stage awaits only a Future
  - [x] 1.3 Framework systems made synchronous (no `async` without an `await`)
  - [x] 1.4 Game systems made synchronous (Tharsis)
  - [x] 1.5 Measure, record, update docs (README/docs page for `System`, CLAUDE.md note on async systems)
- [x] **2. Transform propagation** (fledge_render_2d)
  - [x] 2.1 Roots-only traversal, once per entity, in place (no matrix allocation)
  - [x] 2.2 Skip unchanged subtrees (local snapshot compare + parent version)
  - [x] 2.3 Measure, record
- [x] **3. Query cost** (fledge_ecs)
  - [x] 3.1 Cache `QueryState` per (types, filter) on the `World`, so the archetype match is reused
  - [x] 3.2 Table-direct iteration when no structural change can happen mid-iteration; snapshot only otherwise
  - [x] 3.3 Cheap per-entity path (no change-filter iterators when there are none, no `tableMatches` for cached archetypes)
  - [x] 3.4 Measure, record
- [x] **4. Game screen rebuilds every frame** (Tharsis `ui/`)
  - [x] 4.1 `GameScreen` rebuilds only when its own state changes; HUD and overlays listen to a per-frame notifier
  - [x] 4.2 HUD rebuilds only when what it shows changes (a cheap signature), and computes placement validity and the facing grid once per frame, shared with the machine visuals
  - [x] 4.3 Measure (widget build counts and times), record
- [x] **5. Colonist pathfinding bursts and collision scans** (Tharsis `colony/`, `farm/`, `player/`)
  - [x] 5.1 Per-map static wall index built at load (spatial buckets); `solidsIn` and `MapNav.fits` query it instead of copying and scanning every wall
  - [x] 5.2 Path cache by (map, start cell, goal) for schedule legs; a per-step path budget with a queue
  - [x] 5.3 Build every `MapNav` at load, not on the first step that needs it
  - [x] 5.4 Stuck colonists back off (no re-path every 31 steps forever)
  - [x] 5.5 Measure (worst fixed step around schedule changes), record
- [ ] **6. Sub-pixel scrolling's per-frame offscreen image** (fledge_render_2d)
  - [ ] 6.1 Measure on a real GPU (the user runs the game; F3 panel / F4 capture), with and without `subpixelScroll`
  - [ ] 6.2 Decide with the user, from 6.1, among the options below; implement
  - [ ] 6.3 Measure, record
- [x] **7. Static scenery: per-frame cost of the whole loaded world** (fledge_render_2d, fledge_tiled, Tharsis)
- [x] **8. Prediction obstacles rebuilt every replayed step** (Tharsis `player/`)
- [x] **9. Tilemap extraction** (fledge_tiled)
- [x] **10. Render-world sprite list** (fledge_render_2d, fledge_tiled, fledge_particles, fledge_debug)

Work order: 1 → 2 → 3 → 5 → 4 → 6. (1-3 are framework and benefit everything; 5 removes the worst spikes; 4 is UI; 6 needs the user at a real machine.)

## Measuring

The profiler: `cd projects/tharsis-plateau/game && PERF_OUT=<file> flutter test tool/profile_test.dart`. It builds the full game headless with its art, and runs five scenarios (plot, town at noon, town at 16:30, a dust storm, the lander arrival) for 300-420 frames each, reporting per scenario: tick percentiles, the scheduler's own overhead (tick minus the systems' own synchronous time), per-stage and per-system time, and per-extractor time. Numbers are debug-mode (JIT) and vary run to run by ~10%: compare runs on the same machine, take two runs when a change is small, and ignore the first scenario's extraction (no view laid out yet, so nothing is culled). Keep reports in the session scratchpad; copy the summary lines into the item's Results.

Baseline (after the review's fixes, 2026-11-15; town at 16:30): tick p50 3.4 ms, p95 4.5 ms; scheduler overhead 1.4 ms per frame; `transform_propagate` 0.62 ms; `renderExtraction` 0.8-0.95 ms; colonist move mean 0.1 ms, worst step 2.5 ms.

## Checks

**Run tests safely** (after the 2026-11-15 incident, see item 5): never run two `flutter test` invocations at once; run the smallest relevant file first, alone (`--concurrency=1`); run the full game suite with `--concurrency=4`, once; for anything that might misbehave, run under the watchdog script (a PowerShell wrapper that kills the run if any `dart`/`dartaotruntime`/`flutter_tester` process passes a memory cap or the time limit; recreate it if the scratchpad is gone). A healthy compile of a game test peaks around 0.7 GB; the full suite takes about a minute.

- fledge_ecs: `cd packages/fledge_ecs && dart test` (465 tests at the start). If `dart test` fails to build its runner over `meta`/`analyzer`, see the `meta` override note in the root CLAUDE.md.
- Any framework package touched: its tests (`flutter test` for packages that depend on Flutter, else `dart test`), `flutter analyze` / `dart analyze`, `dart format`.
- Every plugin together: `cd integration/all_plugins && flutter test` (checks `checkScheduleOrdering()`).
- The game: `cd projects/tharsis-plateau/game && flutter analyze && flutter test` (527 tests at the start), and the profiler for the measurement.
- Examples CI builds: `examples/basic_ecs` (needs build_runner first), `examples/advanced_ecs`, `examples/drifter` must still compile after API changes (item 1.2 especially): `melos run analyze` covers them.

---

## 1. Scheduler overhead

**Evidence.** About 1.4 ms of a 3.4 ms frame is the scheduler itself, not the systems: tick time minus the sum of every system's synchronous time. `SystemStage.run` (`packages/fledge_ecs/lib/src/system/schedule.dart`) is a Future-based "parallel" executor in a single isolate: every round rescans all systems (`node.dependencies.every(completed.contains)`, O(n²) per stage), wraps every `system.run(world)` in `.then(...)` (a microtask even when the system finished synchronously), and awaits `Future.any(running.values)` (a new completer and a listener on every running future) per completion. It runs for 9 per-frame schedules and the 5 fixed ones up to 5 times a frame. Dart runs one isolate, so this parallelism buys nothing.

**Design.**
- **1.1 Sequential executor.** Each stage keeps a precomputed execution order, recomputed whenever its graph is (when systems are added or sets configured; `_commit`/graph build in `schedule.dart`). The order is a topological order of the existing dependency edges (explicit `before`/`after`, set edges and the registration-order fallback for conflicting pairs, exactly the edges the current executor waits on), ties broken by registration index: Kahn's algorithm with the lowest-index ready system first. `run` walks it: `if (!system.shouldRun(world)) continue; final r = system.run(world); if (r is Future) await r;`. The timer path wraps the same call. Behaviour that must hold: every dependency still runs first; systems that don't conflict keep registration order (the current executor starts ready systems in registration order); `shouldRun` false skips; a deadlock (cycle) still throws (cycles are already rejected at `addSystem`).
- **1.2 `FutureOr<void>`.** `System.run` returns `FutureOr<void>`. Existing implementations returning `Future<void>` remain valid overrides (covariant return), so this isn't breaking for implementers; callers that use the result directly (`.then`, `await` on a `Future`-typed variable) must handle `FutureOr`: search the workspace and the games for `.run(world).then`, `run(world)` call sites, and `propagateTransforms`-style helpers. `SyncSystem` and `FunctionSystem` return without a Future. Note: an `async` method always returns a Future that completes later, so awaiting it still costs a microtask; that's what 1.3-1.4 remove.
- **1.3 Framework systems.** In every package, systems declared `Future<void> run(World world) async` whose body has no `await` become synchronous: `void run(World world)` (both `void` and `FutureOr<void>` are top types, so a `void` override of a `FutureOr<void>` method should be accepted: confirm with the analyzer in 1.2 and record the chosen form in the fledge_ecs README). Systems that genuinely await stay async. The generator (`fledge_ecs_generator`) emits sync `run` for sync `@system` functions: check `system_generator.dart` and its golden tests.
- **1.4 Game systems.** The same in Tharsis (`game/lib/src/**`): mechanical, file by file, tests after each batch. Systems that await (asset loads, etc.) stay async; per CLAUDE.md, systems inside a tick must never await platform calls anyway.

**Acceptance.** Scheduler overhead (profiler) down by at least half (target < 0.5 ms in the town scenario); all fledge_ecs, integration and game tests pass; `checkScheduleOrdering()` still empty in every app; examples still analyze.

**Risks.** A system that relied on interleaving with another awaiting one (none should; awaiting inside a tick is already forbidden by the frame-jank rule). Order changes among non-conflicting systems are harmless by definition, but a test that encoded an accidental order could fail: read it before changing it. The `SystemTiming.totalMicros` meaning simplifies (no interleaving).

**Results.**
- Before (town 16:30): tick p50 3388 us, p95 4463 us; scheduler overhead 1421 us.
- After 1.1 (sequential executor; order = dependency waves in registration order, the order the old executor ran synchronous systems in): tick p50 2211 us, p95 2950 us; overhead 478 us. All fledge_ecs (465), integration (12) and game (527) tests pass. The acceptance target (< 0.5 ms) is met; 1.2-1.4 remove the microtask per `async` system that's left.
- 1.2-1.3: `System.run` is `FutureOr<void>`; fledge_ecs re-exports `FutureOr` (from `dart:async`), so every Fledge user has it. **Convention: a synchronous system declares `void run(World world)`** (a `void` override of `FutureOr<void>` is accepted; a `FutureOr<void>` body can't `return;` early, which systems do everywhere). Consequence: code that runs a synchronous system directly can't `await` it (`use_of_void_result`); tests across the packages, Tharsis and rafting's `fledge_sprite_sheets` dropped those `await`s. The generator emits `void run`. 67 framework systems and 4 example systems made synchronous by a script (`async` with no `await`, or returning `Future.value()`); 6 that really await stay async. Timing change: systems now run back to back with no event-loop turn between them, so a Future that completes during a tick (e.g. fledge_audio's engine start) is seen from the next frame, not later in the same one; fledge_audio's tests run one frame in set-up for that. Everything passes: all framework packages' tests, integration, examples, Tharsis (527). Pre-existing, unrelated: rafting's `fledge_net_2d` uses a removed `ReplicationRegistry.positionOf` setter; Material deprecation infos in rafting and pearly-gates.
- 1.4: 55 Tharsis systems (52 by the script, 2 expression-bodied by hand, 3 in `fledge_cutscene`) made `void run`; game tests dropped their `await`s (and `tester.runAsync(() => X().run(world))` became a plain call).
- 1.5 After (town 16:30): tick p50 2121 us, p95 3010 us; scheduler overhead 327 us (from 1421 us, -77%; the rest is the tick's own bookkeeping and the profiler's per-system stopwatches). Docs: the System API page and the systems guide teach `void run` for synchronous systems and when async is acceptable; every "systems run in parallel" claim (API pages, guides, getting started, README, root CLAUDE.md) now says what conflicts actually buy: a fixed order for conflicting pairs, checked by `checkScheduleOrdering()`. 97 doc snippets converted. Docs app tests pass. **Item 1 done.**

## 2. Transform propagation

**Evidence.** `transform_propagate` costs ~0.62 ms every frame for ~3,200 entities, most of them static props. `packages/fledge_render_2d/lib/src/transform/propagate.dart`: pass 1 computes every root's `toMatrix()` (a new `Matrix3`); pass 2 iterates every entity with `Children` (roots and inner nodes alike) and recurses into grandchildren, so a node at depth d is recomputed up to d times; every child allocates `parentGlobal.matrix * childLocal.toMatrix()` (two matrices) plus 3-4 `world.get` lookups.

**Design.**
- **2.1** Iterate roots only (`Transform2D` without `Parent`), recurse once through `Children`. Write into the existing `GlobalTransform2D.matrix` in place: compute the local matrix into a scratch `Matrix3` (`Transform2D` gets a `writeMatrix(Matrix3 out)` that sets storage directly, no allocation), and the child's global with `out.setFrom(parent); out.multiply(local)` or a direct 2D affine multiply on storage. Insert `GlobalTransform2D` only when missing (as now).
- **2.2** Skip unchanged work: `GlobalTransform2D` keeps a snapshot of the local values it was computed from (translation x/y, rotation, scale x/y; `Transform2D` is mutated in place, so compare values rather than rely on change detection, which doesn't track in-place mutation) and a `version` int bumped whenever its matrix changes. A node recomputes when its local values differ from the snapshot or its parent's version differs from the one it last saw; otherwise its subtree is visited only to check children (or skipped entirely if a subtree flag says nothing below changed: keep it simple first: compare per node, which is already far cheaper than a matrix multiply).
- Keep `propagateTransforms(world)` working (it calls `run`; with item 1's `FutureOr` it's synchronous).
- Separately noted, not part of this item: Tharsis registers the system in `Schedules.preUpdate`, before the fixed step moves things, so globals are a frame stale for anything not interpolated. Check with the user before moving it.

**Acceptance.** `transform_propagate` < 0.2 ms in the town scenario; fledge_render_2d tests (hierarchy, transforms, interpolation) pass; a new test: a deep hierarchy computes each node once and matches the previous results; a moved parent updates its children; an unchanged world allocates nothing per frame (count recomputes).

**Risks.** Code that writes `GlobalTransform2D.matrix` directly (the lander, cameras) between propagations: the snapshot compare would think nothing changed and keep the written value until the local changes; that's the current behaviour for one frame anyway, but check every writer (`grep -rn "GlobalTransform2D" ... matrix.set`).

**Results.**
- Before (town 16:30): 617 us.
- 2.1-2.2 (roots only, in place, skip unchanged: `GlobalTransform2D` keeps `version`, the local values it was computed from (`sourceX`...), the parent's version and identity (`sourceParent`, so re-parenting is caught); roots queried with their global and children together, no per-entity `world.get`): 457 us. The matrix work is gone; what's left is query iteration, ~0.15 us per entity for ~3,000 entities. **The < 0.2 ms target now depends on item 3**: re-measure 2.3 after it. 2.3 (after item 3): **196 us**, target met. **Item 2 done.** New tests (`fledge_render_2d/test/propagate_test.dart`): deep hierarchy computed once and matching the old products, unchanged world recomputes nothing, moved parent carries children, re-parenting, hand-set root. Semantic change: a global matrix written by hand on an entity that has a `Transform2D` is no longer overwritten every frame while the local is unchanged (every current writer writes the local's own matrix, so none is affected).

## 3. Query cost

**Evidence.** Every `world.queryN<...>()` builds a fresh `QueryState` (`packages/fledge_ecs/lib/src/query/query.dart`, `QueryState.ofN`), so the archetype match cache always misses (`updateCache` scans every archetype and allocates the required-component set). Every `iter()` snapshots all matching entities into a new `List<Entity>` (`snapshotEntities`), then per entity does a location lookup, a liveness check, `tableMatches` over the required/excluded sets, `passesChangeFilters` (iterators even when empty), a column map lookup per component and a record allocation. Systems query every frame, many of them several times.

**Design.**
- **3.1** A cache on `World`: `Map<Object, QueryState>` keyed by a record of the component types and the filter (filters are mostly `const`, compare by `==`/identity; give filter classes `==`/`hashCode` if needed). `queryN` takes the cached state. `QueryState.updateCache` already skips work when the archetype count hasn't changed: make sure it keys on a generation counter that bumps when an archetype is created.
- **3.2** Iteration: when the query can't be invalidated mid-iteration, walk the matching tables directly: for each matching archetype, fetch the needed columns once, loop rows, yield `(entity, c1, c2)`. Structural changes during iteration (spawn/despawn/insert/remove inside a `for` over a query) are what the snapshot protects against today and are common in game code (e.g. despawning while iterating). Plan: keep correctness by detecting a structural change (a world `structureVersion` bumped by every move/spawn/despawn) during table iteration and, when it changes, finishing from a snapshot of the remaining entities (taken lazily at that moment), re-checking each as today. Most iterations never change structure and pay nothing.
- **3.3** Per-entity path: skip `passesChangeFilters` when the state has none; skip `tableMatches` when iterating a table known to match.
- Change detection (`Added`/`Changed`): the review found it ineffective (states are recreated with `lastSeenTick = 0`, nothing updates last-seen ticks, in-place mutation isn't tracked). With cached states this would start "working" in a half-correct way: decide explicitly. Plan: keep current semantics (states cached per call site don't carry per-system last-seen ticks; document `Added`/`Changed` as not supported yet), and note it in the item's Results for the user.

**Acceptance.** Allocation per query iteration ~constant (no per-entity snapshot in the common case); fledge_ecs query tests (including `archetype_mutation_iter_test.dart`, which covers mutation during iteration) pass; frame time and the systems' own time drop measurably in the profiler (expect most systems' time to fall; record the top systems before/after).

**Risks.** Mutation during iteration (covered by tests; add cases for despawning the current entity, inserting a component that moves it, spawning matching entities mid-loop). Memory growth of the cache (bounded by the number of distinct query shapes).

**Results.**
- Before (town 16:30): tick p50 2039 us, p95 2829 us; `transform_propagate` 457 us; `tharsis_daylight` 48 us.
- Design as built (3.2 differs from the plan): walking tables directly with a lazy snapshot can't keep the old semantics (a despawn in a not-yet-visited table already changed the "remaining" set), so the snapshot of matching entities stays, but entry `i` is read straight from the next row of the next matching table (columns fetched once per table, no location lookup, no match check) while `Table.structureVersion` (a static counter bumped by every table add/remove/clear, in any world) hasn't moved since the snapshot; after a structural change the rest take the old per-entity path. Change filters are checked only when the query has some. 3.1: `World` caches a `QueryState` per shape (types + filter; `With`/`Without`/`And`/`NoFilter` got value equality), except queries with `Added`/`Changed` (fresh state each time, as before). Archetypes are never removed (`clear` only empties tables), so the count check stays valid.
- After: tick p50 **1080 us**, p95 1809 us (-47%); `transform_propagate` 196 us; `tharsis_daylight` 13 us; scheduler overhead 245 us. New tests: a mid-loop despawn across two tables never pairs an entity with another's component, none visited twice; a two-component query stays row-consistent across a structural change. All framework, integration and game tests pass. **Item 3 done.**

## 4. Game screen rebuilds every frame (Tharsis)

**Evidence.** `GameScreen._frame` calls `setState(() {})` every frame (`game/lib/src/ui/game_screen.dart`), rebuilding the `LayoutBuilder`, `InputWidget`, the render view and the whole `Hud` 60+ times a second. `Hud.build` (`ui/hud.dart`) calls `localPlayer()` several times, and while a machine is held calls `canPlaceMachine` (which collects ~900 walls, clutter and bodies) every build; `_facingHint` computes the grid even when nothing's faced. The machine visuals compute the same placement validity again (`presentation/machine_visuals.dart`). In co-op the world runs behind menus, so open screens (backpack, research, shop) rebuild every frame too.

**Design.**
- **4.1** A `ValueNotifier<int>` frame counter (or a `ChangeNotifier`) ticked by `_frame`; the render view repaints from it (it may already repaint itself: check `FledgeRenderView`), the HUD and the open screen are `ListenableBuilder`s on it; `GameScreen.setState` only when the phase or a dialog changes.
- **4.2** The HUD computes a cheap signature of what it shows (time string, oxygen bucket, credits, hotbar contents and selection, hint text, quest markers...) and rebuilds its subtree only when it changes. Placement validity and the facing grid are computed once per frame in one place (a small resource filled by a presentation system, read by both the HUD and the machine visuals).
- Keep: gameplay state lives in resources; widgets only read.

**Acceptance.** HUD builds per second drop from ~60 to the rate its contents change (count with a debug counter in a widget test); no visible change in behaviour; game tests pass (there are HUD/overlay widget tests).

**Results.**
- 4.1: `FledgeRenderView` takes a `repaint` listenable (fledge_render_2d; test: a tick marks the view for paint without a rebuild). `GameScreen` keeps a `_frames` notifier bumped each frame (and at the end of `_tick`); the render view repaints from it and the overlays (HUD, screens, dialogue, cutscene overlay, perf panel, net status) sit in one `ListenableBuilder` on it, so the `LayoutBuilder`, `InputWidget`, `UiSounds` and the render view no longer rebuild every frame; `setState` runs only when the phase changes. Overlays still refresh every frame, as before (co-op screens show friends' changes live).
- 4.2: `MachineFacts` (local resource, `presentation/machine_visuals.dart`): the grid and the held machine's placement check, worked out once per frame by `MachineVisualSystem`; the HUD reads them instead of recomputing (`canPlaceMachine` collected ~900 walls, clutter and bodies every build while a machine was held; `gridNow` ran 2-3 times a frame). **Not done, deliberately:** a change-signature to skip HUD rebuilds: with the expensive work shared the HUD is a small widget tree, and a signature would have to cover a dozen fields (clock, storm, credits, oxygen, pickups, hint, every hotbar slot), where one missed field means a stale HUD.
- 4.3: the game screen has no automated widget test (it writes saves to the user's documents), so there's no build-count measurement; the user should check menus, HUD, counters, dialogue and co-op screens in play. 530 game tests pass. **Item 4 done.**

## 5. Colonist pathfinding bursts and collision scans (Tharsis)

**Evidence.** The profiler shows `tharsis_colonist_move` at ~0.1 ms mean but up to 2.5 ms in one fixed step. Several colonists re-path in the same step at schedule boundaries (7:00, 12:00, 13:00, 19:30), after every scene (`endScene` clears every colonist's goal), and after sleep. Each path is A* on the town's 240×208 grid, then `keepToSide`/`simplifyPath` sample the line every ~2 world units and call `fits()`, which scans every wall on the map (~436 in town). Every fixed step, `solidsIn()` (`farm/collision.dart`) copies ~1,000 rectangles (all maps' walls, machines, clutter footprints, computed fresh) and the movers scan them linearly: colonists, players, scripted walkers, and on clients each predicted and replayed step.

**Design.**
- **5.1** A static wall index per map, built when the maps load (walls never change): uniform buckets (64 px) of the map's wall rectangles. `solidsNear(map, rect)` returns the few candidates; machines and clutter (plot only) are added from their own (already versioned) data. `MapNav.fits` uses the same index. `stepCharacter` and the movement systems take the index instead of a list.
- **5.2** Paths: cache by (map, start cell, goal) for legs between named spots and exits (schedules repeat every sol; invalidate when the map's walls change, which is never at runtime today, or when the nav is rebuilt). A per-step budget (e.g. 2 path searches per fixed step) with a FIFO queue; a colonist without a path yet waits where it is (or keeps walking its previous leg) for a step or two.
- **5.3** Build the nav for every map at load, not lazily on the first step that needs one (the first town path pays for building the 50k-cell grid today).
- **5.4** Stuck colonists: exponential backoff on re-path (31 steps, then 62, 124...) and, after a few tries, snap to the next waypoint; log once (it means a mis-authored spot or wall).
- Multiplayer: all of this is authority-side simulation (colonists are host-driven); clients predict only their own player, which uses the wall index too.

**Acceptance.** Worst colonist step < 0.5 ms around schedule changes (profiler; add a scenario that crosses 12:00 and ends a scene); movement tests (`colonist_test.dart`, `town_test.dart`, co-op tests) pass; paths unchanged for the same inputs (compare a sample of legs before/after the index).

**Results.**
- 5.1 built: `farm/collision.dart` has `Obstacles` (one question, `hits(body, [where])`; `except(rect)` for a body already inside one; `Obstacles.none`, `Obstacles.of(list)`), `RectIndex` (rectangles bucketed on a 64 px grid) and `Solids` (every map's walls through `Collision.wallIndex`, rebuilt only when walls are added; machines; clutter looked up by the tiles under the body). `solidsIn` returns `Obstacles`; `Character.step(solids:)` takes `Obstacles`; the scripted walk uses `except`; terraforming asks `hits`; `MapNav.fits` uses its own `RectIndex`. New `test/obstacles_test.dart`: the index agrees with a plain scan on 5,000 random bodies (walls of any size, one map-wide).
- **Incident (2026-11-15):** right after 5.1 a test run exhausted the user's memory (the Dart frontend server grew past 12 GB). Cause, found by bisecting under a watchdog: a `sed` that inserted the `RectIndex` import into `colony/nav.dart` also turned the next line into `import '..//player/player.dart';`. A double slash makes a different library URI for the same file, so the compiler loads the game's whole import cycle again under that path, and again, without end. Fixed (the import is correct again); the full suite is back to ~60 s and ~0.7 GB peak; 529 tests pass. Lesson in **Checks** above; edit imports with Edit or a script that checks the result, never a blind `sed`.
- 5.2-5.4 built: `MapNav.path` caches ways by (start cell, exact target) (bounded at 512, callers get a copy); `ColonistMoveSystem` looks for at most `pathBudget` (1) new way per fixed step, others stand a step; `ColonyNav.buildAll` builds every map's nav when the colonists first spawn; stuck colonists back off (`giveUp << retries`, capped at 16x). In fledge_physics, `Pathfinder` reuses its whole-grid working arrays between searches (generation stamps, no allocation or fill per search; test: back-to-back searches on different grids match fresh ones).
- 5.5 measured (new profiler scenario: crossing 12:00 with every colonist's goal reset, as after a scene): colonist move mean 75 -> ~25 us per step; worst step in ordinary play 0.1-0.4 ms (from up to 2.5 ms); **worst burst step 1.9 ms**, which is a single cross-town search the first time a leg is walked in a session (cached after). Target (< 0.5 ms) not met for that first search. Options to decide with the user: (a) warm the cache at spawn by walking every colonist's schedule legs once (moves the cost to load); (b) time-slice A* across steps; (c) accept (debug-mode 1.9 ms is roughly 0.5-1 ms in release, once per leg per session). All 529 game tests pass.
- **Decided with the user: (a), done gradually.** `ColonyNav.queueRoutes` lists every leg of every colonist's day when they first spawn (from each stop's spot to the next, door by door, from the arrival points inside doors, exactly as the move system walks them); `ColonyNav.warmOne` looks one up in each fixed step whose path budget nobody used, so all ~100-150 legs are remembered within a few seconds and schedule changes find their ways ready (test in `colonist_test.dart`). Also, `endScene` no longer clears every colonist's way, only those the scene walked (`ScriptedWalk`); held colonists already drop theirs while held, and personal scenes use stand-ins, so the old reset sent the whole town re-pathing after every cutscene.
- After (debug JIT): worst colonist step at noon 284 us, 16:30 159 us, storm 315 us (from up to 2.5 ms); mean ~23 us. The profiler's worst-case scenario (every colonist re-pathing from wherever they stand, which no longer happens after scenes) still has 1.5 ms steps: one search from an arbitrary position, once per step. 530 game tests pass. **Item 5 done.**

## 6. Sub-pixel scrolling's offscreen image

**Evidence.** With `ActiveCameraView.subpixelScroll` (Tharsis turns it on), `paintActiveCamera` (`packages/fledge_render_2d/lib/src/render/camera_view.dart`) records the frame into a `PictureRecorder`, rasterises it with `picture.toImageSync(width, height)` at viewport size × device pixel ratio every frame, then draws that image at the fractional offset. That's a new render target and an extra full-screen pass per frame, on top of the lighting's full-screen layer. It exists so pixel art scrolls smoothly without each sprite snapping on its own (shimmer). Headless tests can't measure GPU cost.

**Options** (decide after 6.1's measurement):
- (a) Draw directly (no offscreen) when the fractional part of the offset is ~0, or whenever the camera hasn't moved since the last frame.
- (b) Draw the picture (not an image) under a fractional translate with the world snapped to whole pixels inside it: no render target, but whether the GPU then filters smoothly depends on the backend (Impeller), so verify visually.
- (c) Keep the offscreen but reuse it while nothing changed (a static scene) and fall back to (a) while still.
- (d) Leave as is if 6.1 shows it's cheap on target hardware.

**Steps.** 6.1: the user runs the game (`flutter run -d windows --profile`) with the F3 panel, in town, still and walking, once with `subpixelScroll` on and once off (a temporary toggle; add a debug key if needed), and reports raster times / frame pacing (or an F4 capture). 6.2: choose with the user and implement. 6.3: measure again the same way.

**Results.**

---

## 7. Static scenery (2026-11-19)

**Evidence.** Every map loads at boot into one world (about 6,600 entities, 4,600 sprites). `transform_propagate` still visited every entity to confirm nothing moved, and `SpriteExtractor` walked every sprite to cull it: the top two costs in every scenario, growing with each map. No change detection to lean on (item 3).

**Design as built.** `StaticTransform` (fledge_render_2d): an entity whose transform and place in the hierarchy never change (a root takes its subtree). Propagation computes a static root and subtree once, marks them `TransformFrozen`, bumps `StaticTransforms.generation`, and never visits them again (the other root passes exclude `StaticTransform`); a debug-only check every 120 runs fails if a frozen entity's local changed. `SpriteExtractor` walks `Without<TransformFrozen>` as before, and frozen sprites through a 256 px grid rebuilt when the generation changes (visiting only buckets near the view, checking liveness and the marker; the per-sprite logic shared). fledge_tiled: `TilemapSpawnConfig.staticTransforms`. Tharsis marks every map, prop and clutter drop shadows, prop and door lights, farm tile sprites, terraform loam, machines and their shadows, and clutter sprites (their hit shake now nudges the sprite's anchor, not the transform).

**Results** (`game/tool/profile_test.dart`, headless debug, 1080p view):
- `transform_propagate`: 460-535 us -> **25-37 us** (about -93%).
- `SpriteExtractor`: town 365-393 -> 170-194 us, frontier 361 -> 79 us, plot 408 -> 227 us, storm 432 -> 264 us (what's left is moving sprites: characters, storm motes, rime).
- Tick p50: town 16:30 1714 -> 1043 us, frontier 1613 -> 880 us, plot 1910 -> 1245 us.
- `extract.renderExtraction` as a whole fell about 25% (735 -> 529 us town); most of what's left is `TilemapExtractor` (~300 us for ~960 visible tiles), which already culls to the view and wasn't part of this item.
- Tests: `fledge_render_2d/test/static_transform_test.dart`, a fledge_tiled opt-in case, `game/test/clutter_shake_test.dart`.

## 8. Prediction obstacles (2026-11-19)

**Evidence.** `stepCharacter` called `solidsIn(world)` for every predicted step; a client's reconciliation replays 6-12 steps at 100-200 ms round trips.

**Design as built.** `_solidsFor` (Tharsis `player/player.dart`): an `Expando` on the world keeps the last replay batch's obstacles; reused while replaying the same entity at a later tick (the replay loop steps one entity through consecutive ticks over a world that doesn't change), built afresh on a normal step and at each batch's start. Test: `player_test.dart` (a wall added mid-batch is unseen by the rest of the batch, seen by the next normal step).

## 9. Tilemap extraction (2026-11-19)

**Evidence.** After item 7, `TilemapExtractor` was the largest extractor (~300 us town, ~960 visible tiles). Per frame it visited every layer of every loaded map (~130), allocating a corner list each, and built every visible tile's `ExtractedSprite` afresh (trig, a `Matrix3`, two `Vector2`s, the sprite) before adding it to the render world.

**Design as built.** Each tile's sprite is built once and kept in the layer's index (nothing downstream changes an extracted sprite: verified, the only matrix write is interpolation's own copy); kept sprites are dropped when the map's transform (identity, version and matrix, so hand-set transforms count), the layer's colour, offset or parallax change; animated tiles are built every frame. A finite map without parallax or rotation whose area (padded by its layers' offsets) misses the view is skipped before its layers. The view's corners are inlined (no list per layer).

**Results** (profile, headless debug): `TilemapExtractor` town 304 -> 228 us, plot 272 -> 194 us, frontier 232 -> 160 us; town 16:30 tick p50 1043 -> 961 us. Tests: `fledge_tiled/test/tile_culling_test.dart` (the same sprite drawn every frame and equal to a fresh build; moved map and faded layer rebuild; a far map draws nothing).

**What's left.** Most of the remaining cost was `RenderWorld.add`, one entity per visible tile: item 10.

## 10. Render-world sprite list (2026-11-19)

**Evidence.** After item 9, most of `TilemapExtractor` (and a share of `SpriteExtractor`) was `RenderWorld.add`: an entity spawned per visible tile and sprite every frame, only to be queried once and sorted. Nothing used the render-world entity ids.

**Design as built.** `RenderWorld.addSprite` appends to a plain list (cleared with the world); `extractedSprites` yields the list, then any `ExtractedSprite` entities added the old way (still drawn); `extractedSpriteCount`. Readers (`SpriteBatchNode`, `renderSpritesToDrawer`, the debug panel) use `extractedSprites`; writers (`SpriteExtractor`, `AtlasSpriteExtractor`, `TilemapExtractor`, `ParticleExtractor`, and `ComponentExtractor` when it makes a sprite) use `addSprite`. Lights and UI stay entities. Draw order is unchanged (`sortByDrawOrder` after collection; ties keep insertion order). 11 test files moved to `extractedSprites`; new `fledge_render_2d/test/render_world_sprites_test.dart`. The Tharsis profiler counts listed sprites too.

**Results** (profile, headless debug):
- `TilemapExtractor`: town 228 -> **25 us**, plot 194 -> 25 us, frontier 160 -> 17 us.
- `SpriteExtractor`: town 176 -> 136 us, plot 208 -> 151 us.
- `extract.renderExtraction`: town 459 -> **211 us**, frontier 337 -> 129 us, plot 468 -> 234 us.
- Tick p50: town 16:30 961 -> **727 us**, frontier 809 -> 596 us, plot 1173 -> 915 us.

Since item 7 began (all of 7, 9, 10): town 16:30 tick p50 1714 -> 727 us (-58%), frontier 1613 -> 596 us (-63%).

## Not in scope here (reported by the review, to verify separately)

Verified 2026-11-17 (review round):
- **Farm tile sprites:** not a leak. A tile that's no longer worked hides its sprites, and they're reused when it's worked again. The count is bounded by the plot's tiles.
- **`PuppetPaths.paths`:** pruned. An entity with no walk order drops its cached path in `puppetStep`.
- **Clutter sprites on a client:** they were recreated on every chunk sync, because the match was by object. They now match by kind and sprite.
- **Ground items on clients:** they now ease toward the host's latest snapshot instead of jumping, and snap past 96 px.
- **Fixed-step events:** not a bug in Tharsis. No fixed-schedule system reads events, and the readers run once per frame.
- **Tiled flips:** fixed in `fledge_tiled`. All eight orientations draw as Tiled shows them, with mirrors through `ExtractedSprite.flipX`.

The original list:

Bugs reported by the review's code reading and not yet verified: farm tile sprites never despawned when a tile is unworked (`presentation/farm_visuals.dart`); `PuppetPaths.paths` never pruned (`colony/scenes.dart`); clutter sprites recreated on every client chunk sync (`presentation/clutter_visuals.dart`, `farm/clutter.dart`); ground items jump instead of interpolating on clients (`farm/ground_items.dart`); fixed-step event delivery (an event seen N times when N fixed steps run, or never at 0; `fledge_ecs/lib/src/event.dart`). Verified latent framework bug: single-axis or diagonal-only tile flips draw unflipped (`fledge_tiled/lib/src/extraction/tile_sprite_conversion.dart`); no Tharsis map uses flip flags.
