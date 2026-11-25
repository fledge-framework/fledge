# fledge_ecs

## Purpose
Core ECS framework: World, Entity, Component, System, Scheduler/Schedules, Resources, and Events.

## Status: Excellent

## Stats
- Source: 38 files, ~7,440 LOC
- Tests: 27 files, ~6,370 LOC
- TODOs in code: 0

## What Works
- World creation and entity lifecycle (spawn, despawn, hierarchy)
- Component storage via archetype tables with cache-efficient iteration
- Typed queries (query1 through queryN) with filters (With, Without)
- System scheduling with automatic parallel execution based on read/write declarations
- Named schedules (`Schedules.*`): startup, first, preUpdate, fixed-timestep chain (fixedFirst..fixedLast), update, postUpdate, last, extract, render
- Fixed-timestep loop driven by the `FixedTimestep` resource (default 60 Hz, 5-step catch-up cap; auto-inserted by `App`)
- Global resources (insertResource, getResource, removeResource)
- Double-buffered event queues for inter-system communication
- Entity hierarchy (parent/child relationships)
- Observers for reactive component lifecycle hooks
- State machines for game state management
- Reflection support for serialization
- Built-in plugins: `WallTimePlugin` (`WallTime` resource) and `FrameLimiterPlugin`

## Gaps
None identified.

## Action Items
No action items — this package is complete and well-tested.

## Architecture Notes
- **Entry point**: `lib/fledge_ecs.dart` (barrel export)
- **App** (`lib/src/app.dart`): Builder with fluent API for configuring world, plugins, resources, events, systems, and state machines.
- **World** (`lib/src/world.dart`): Central container. All ECS operations flow through World.
- **Entity** (`lib/src/entity.dart`): Generational index (id + generation) for stale-reference detection.
- **Archetype storage** (`lib/src/archetype/`): Entities grouped by component composition. `Table` uses column-oriented layout (one list per component type). Archetype transitions cached as edges for O(1) add/remove.
- **Query** (`lib/src/query/`): Cached `QueryState` tracks matching archetype indices. Filters: `With`, `Without`, `Added`, `Changed`. State invalidated lazily when new archetypes appear.
- **Schedules** (`lib/src/system/schedule_label.dart`): `Schedule` is a value-type label; `Schedules` holds the standard ones. Register with `app.addSystem(system, schedule: Schedules.update)` (default is `update`). `stage: CoreStage.foo` is deprecated but still accepted.
- **Scheduler** (`lib/src/system/schedule.dart`): Runtime container (renamed from `Schedule`; deprecated `App.schedule` getter aliases `App.scheduler`). `SystemMeta` declares reads/writes/resourceReads/resourceWrites/before/after. Within a schedule, non-conflicting systems run as concurrent Futures. Explicit ordering adds dependencies on top of the conflict-based graph; `before:`/`after:` match system *names* (class-based systems expose `static const String systemName` for this), and a name shared by several systems fans out to all of them. `App.checkScheduleOrdering()` (delegates to `Scheduler.checkOrderingAmbiguities()`) walks every schedule for pairs whose order is determined only by registration order — use in tests or debug-mode boot paths to catch the "insertion-order accident" class of bug (e.g. an input system running after physics resolution so the player walks through walls). Returns `List<OrderingAmbiguity>` with human-readable reasons and suggested fixes.
- **FirstSets** (`lib/src/system/standard_sets.dart`): standard phases of `Schedules.first` — `frameStart` → `platform` → `input` → `content` — chained by the default `Scheduler()` constructor (not `Scheduler.empty()`); the chain survives `clear()` / `resetToSessionCheckpoint`. Plugin systems in `first` join a phase via `SystemMeta(sets: [FirstSets.x])`; `WallTimeUpdateSystem` and `FrameStartSystem` are in `frameStart`.
- **ComponentId** (`lib/src/component.dart`): Interned integer IDs for component types. `toString()` / `debugName` render the original `Type` name (`Velocity`, not `ComponentId(3)`) so scheduler diagnostics and stack traces stay readable.
- **Change detection** (`lib/src/change_detection/`): Global `Tick` increments once per frame. `ComponentTicks` tracks added/modified ticks per instance. Query filters compare ticks.
- **Events** (`lib/src/event.dart`): Double-buffered — systems read previous frame's events, write to current frame's buffer. `updateEvents()` swaps buffers each tick.
- **Resources** (`lib/src/resource.dart`): Type-keyed singletons on World. `Resources.whereType<T>()` / `World.resourcesOfType<T>()` enumerate every stored resource that satisfies an interface or mixin — used by `fledge_save` for auto-discovery of `Saveable`s.
- **FixedTimestep** (`lib/src/fixed_timestep.dart`): Accumulator resource; `App.tick()` runs the fixed chain 0..`maxCatchupSteps` times between `preUpdate` and `update`. Override via `insertResource(FixedTimestep(stepDuration: …, maxCatchupSteps: …))` before `run()`.
- **State machines** (`lib/src/state/`): States stored as `State<T>` resources. `addSystemInState()` wraps with `InState` condition. Transitions applied after tick.
- **Hierarchy** (`lib/src/hierarchy/`): Parent/child entity relationships.
- **Observers** (`lib/src/observer/`): Reactive component lifecycle callbacks.
