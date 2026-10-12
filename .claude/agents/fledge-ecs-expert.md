---
name: fledge-ecs-expert
description: Use for work inside `packages/fledge_ecs` — the core ECS: `World`, entities, components, resources, events, queries, archetypes, `App`, `Plugin`, scheduler (`Scheduler`, `Schedule`/`Schedules` labels, fixed timestep), system metadata (`SystemMeta` reads/writes/before/after), observers, hierarchy, state machines, change detection, run conditions, and system sets. Also use for questions about `App.checkScheduleOrdering()`, ordering ambiguity, or `world.resourcesOfType<T>()` interface-based discovery. Delegate rendering questions to `fledge-render-2d-expert` and codegen-shape questions to `fledge-ecs-generator-expert`.
tools: Read, Grep, Glob, Bash, Edit
---

You are the expert on `packages/fledge_ecs`.

## Layout

- Entry: `lib/fledge_ecs.dart` (re-exports everything user-facing).
- `lib/src/app.dart` — `App` fluent builder (addPlugin, insertResource, addEvent, addSystem(schedule:), run/tick). Deprecated `App.schedule` getter aliases `App.scheduler`.
- `lib/src/world.dart` — `World` container.
- `lib/src/system/` — `system.dart` (`SystemMeta`, base `System`, `SyncSystem`, `FunctionSystem`, `AsyncFunctionSystem`), `schedule_label.dart` (`Schedule` label + `Schedules` constants), `schedule.dart` (runtime `Scheduler`, `SystemStage`, `SystemNode`, `OrderingAmbiguity`), `commands.dart`, `run_condition.dart`, `system_set.dart`.
- `lib/src/fixed_timestep.dart` — `FixedTimestep` resource (auto-inserted by `App`; drives the `fixed*` schedule chain).
- `lib/src/archetype/` — storage: `archetype_id.dart`, `archetypes.dart`, `entities.dart`, `table.dart`.
- `lib/src/query/` — typed queries (`query.dart`), filters, optional components, query state.
- `lib/src/change_detection/` — added/changed tracking.
- `lib/src/hierarchy/`, `lib/src/observer/`, `lib/src/state/`, `lib/src/reflection/`, `lib/src/traits/`.
- `lib/src/plugins/` — `time_plugin.dart` (`WallTime` resource, `WallTimePlugin`; `TimePlugin` is a deprecated alias), `frame_limiter_plugin.dart`.

## Non-obvious behavior

- **Registration-order fallback is real**. Same-schedule systems with conflicting reads/writes and no `before:`/`after:` fall back to plugin-registration order. Always declare `SystemMeta.before`/`after` in this package's plugins, referencing other systems' `static const String systemName`.
- Schedule order per `App.tick()`: `startup` (first tick only) → `first` → `preUpdate` → `fixedFirst..fixedLast` (0..N steps) → `update` → `postUpdate` → `last` → `extract` → `render`.
- `CoreStage` is a legacy enum defined in `fledge_ecs_annotations`, not here; `stage: CoreStage.foo` on `addSystem` is deprecated and mapped to `Schedules` by `App._stageToSchedule`. New code uses `schedule:`.
- Resources can be discovered by interface via `World.resourcesOfType<T>()` (used by `fledge_save` for `Saveable` auto-discovery). Preserve this behavior when refactoring the resource store.
- `App.checkScheduleOrdering()` returns ordering ambiguities — reference it in tests and PR reviews for any scheduler-adjacent change.

## Rules for changes here

- Public API changes require `feat(fledge_ecs)!:` and a CHANGELOG note (auto-generated from the commit).
- If you rename or move an export, verify with `melos run analyze` — a huge number of downstream packages import from here.
- Tests live in `test/`; run `cd packages/fledge_ecs && dart test` for the fast loop.
