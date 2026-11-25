# fledge_ecs_annotations

## Purpose
Dart annotations for ECS code generation (`@component`, `@system`, `@resource`, `@event`).

## Status: Complete

## Stats
- Source: 1 file, ~160 LOC
- Tests: None (annotation-only package, no logic to test)
- TODOs in code: 0

## What Works
- `@component` annotation for generating component boilerplate
- `@system` annotation (`SystemAnnotation`) for generating system wrappers
- `@resource` annotation for resource code generation
- `@event` annotation for event type generation

## Gaps
- **[P2]** `SystemAnnotation.stage` still takes the legacy `CoreStage` enum (first/preUpdate/update/postUpdate/last, defined here), and the generator ignores it — schedule placement happens at `app.addSystem(..., schedule: Schedules.foo)`. No `@reflectable` annotation exists (reserved for `fledge_debug`).

## Action Items
1. Decide whether to drop `SystemAnnotation.stage`/`CoreStage` or replace with a schedule-name field (coordinate with `fledge_ecs_generator`)

## Architecture Notes
- **Entry point**: `lib/fledge_ecs_annotations.dart` (barrel export)
- All annotations are defined directly in the barrel file (no `lib/src/`)
- Pure data — no logic, no dependencies (not even `fledge_ecs` or `meta`)
- Consumed by `fledge_ecs_generator` at build time via `build_runner`
