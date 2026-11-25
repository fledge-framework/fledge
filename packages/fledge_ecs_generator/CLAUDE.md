# fledge_ecs_generator

## Purpose
build_runner code generator that processes `fledge_ecs_annotations` to produce component and system boilerplate.

## Status: Functional

## Stats
- Source: 4 files, ~465 LOC
- Tests: 1 file (`test/query_marker_inference_test.dart`)
- TODOs in code: 0

## What Works
- Component code generation from `@component` annotations
- System code generation from `@system` annotations
- Integration with `build_runner` / `build_runner_core`

## Gaps
- **[P2]** Only one test, and it reads generated output from `examples/basic_ecs/lib/query_marker_fixtures.g.dart` — needs `melos run build_runner` first; no `build_test`-driven unit tests yet

## Action Items
1. Add unit tests for component and system generators using `build_test` (already a dev dependency)

## Architecture Notes
- **Entry point**: `lib/fledge_ecs_generator.dart` (barrel export)
- **Generators** (`lib/src/component_generator.dart`, `lib/src/system_generator.dart`): One for components, one for systems. Each implements `GeneratorForAnnotation<T>` from `source_gen`.
- **Build entry point**: `lib/builder.dart` exports `fledgeEcsBuilder()` (PartBuilder using `.g.dart` suffix)
- `ComponentGenerator` generates a `componentId` static getter extension
- `SystemGenerator` (top-level functions only) emits `<PascalName>Wrapper implements System` with `SystemMeta(name: '<functionName>', …)`. Infers access from parameter types: `Query1..4` → reads, `QueryMut1..4` → writes, `Res`/`ResOption` → resourceReads, `ResMut` → resourceWrites, `EventReader`/`EventWriter`/`EventReadWriter` → eventReads/eventWrites. Mixed read/write on one query → hand-write a class-based `System`.
- Ignores `SystemAnnotation.stage`; schedule placement is the caller's `app.addSystem(..., schedule:)`
- Depends only on `fledge_ecs_annotations` (not `fledge_ecs`) — matches types by name
- Invoked via `melos run build_runner` or `dart run build_runner build` in consuming packages
