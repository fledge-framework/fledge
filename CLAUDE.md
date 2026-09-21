# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository layout

Fledge is a Bevy-inspired ECS game framework for Dart/Flutter, organized as a Melos-managed workspace (`pubspec.yaml` declares the workspace members). Packages live under `packages/`, sample apps under `examples/`, and the marketing/docs Flutter web app under `docs/`.

Package tiers (see `CONTRIBUTING.md` for exact dependency order):
- **Core**: `fledge_ecs`, `fledge_ecs_annotations`, `fledge_ecs_generator`
- **Render**: `fledge_render_2d` (2D infra + components; `fledge_render` is a deprecated re-export shim to be deleted in a future release)
- **Plugins**: `fledge_audio`, `fledge_input`, `fledge_window`, `fledge_tiled`, `fledge_physics`, `fledge_yarn`, `fledge_save`, `fledge_calendar` (`fledge_time` is a deprecated re-export shim), `fledge_net`

## Commands

All routine tasks go through Melos from the repo root:

```bash
dart pub global activate melos      # one-time
melos bootstrap                     # install all package deps

melos run analyze                   # dart analyze across all packages
melos run test                      # runs test:dart then test:flutter
melos run test:dart                 # pure-Dart packages only
melos run test:flutter              # packages with `flutter: sdk: flutter`
melos run format                    # dart format .
melos run build_runner              # regenerate code (packages that dependsOn build_runner)
```

Running a single test — Melos doesn't have a per-file wrapper, cd into the package:

```bash
cd packages/fledge_ecs && dart test test/query_test.dart --plain-name "matches archetype"
cd packages/fledge_render_2d && flutter test test/sprite_test.dart
```

The workspace pubspec categorises which packages need `dart test` vs `flutter test` — packages that depend on `flutter` are excluded from `test:dart` and picked up by `test:flutter` via `dependsOn: flutter`. If you add a new package, update those `ignore`/`dependsOn` filters or the CI will silently skip its tests.

## Code generation

`fledge_ecs_annotations` provides `@component` / `@system` etc., and `fledge_ecs_generator` produces the wrapper classes. CI runs `melos run build_runner` before analyze — do the same locally after touching any annotated class, or `dart analyze` will fail against stale generated code. The `basic_ecs` example also needs `dart run build_runner build --delete-conflicting-outputs` before it will compile.

## Architecture

### Two-world model (main → render)
`fledge_render_2d` uses Bevy's two-world split: the main `World` holds game state; a separate `RenderWorld` is **cleared and rebuilt each frame** from extractors (resources on the main world) before render systems run. Never store game logic in the render world, and never assume render-world entities persist across frames — only resources do. Entry point: `packages/fledge_render_2d/lib/src/render/world/render_world.dart` and `.../render/extract/extract.dart`.

### Scheduler and schedules
Systems live in named schedules identified by the `Schedule` value type. Standard schedules are in `Schedules` (`packages/fledge_ecs/lib/src/system/schedule_label.dart`). `App.tick()` runs them in this order:

1. **`startup`** — runs once, on the first tick.
2. **`first`** — frame-start bookkeeping (input polling, wall-time update).
3. **`preUpdate`** — input-driven writes (movement intent, AI steering).
4. **Fixed-timestep chain** — `fixedFirst → fixedPreUpdate → fixedUpdate → fixedPostUpdate → fixedLast`, dispatched 0..N times per frame via a `FixedTimestep` resource (default 60 Hz, 5-step catchup cap). Physics and any deterministic sim belong here.
5. **`update`** — core game logic that doesn't require a fixed step.
6. **`postUpdate`** — reactions to `update`.
7. **`last`** — cleanup.
8. **`extract`** — `RenderExtractionSystem` copies from main world to `RenderWorld`.
9. **`render`** — render systems on the render world.

Within a schedule, the scheduler parallelizes non-conflicting systems and serialises conflicting ones from each system's `SystemMeta` (`reads`, `writes`, `resourceReads`, `resourceWrites`).

Deprecated: `stage: CoreStage.foo` on `App.addSystem` still works for one release; new code passes `schedule: Schedules.foo`. The runtime container was renamed from `Schedule` to `Scheduler`; a deprecated `App.schedule` getter aliases `App.scheduler`.

**Important footgun**: when two systems in the same schedule conflict but neither declares `before:`/`after:`, ordering falls back to **registration order** — which changes silently based on when plugins are added. Always declare `before:`/`after:` explicitly for cross-conflict systems, and run `App.checkScheduleOrdering()` (e.g. in a test) to surface ambiguities.

### Codegen: Query vs QueryMut
`@system`-annotated functions signal component intent through the parameter type: `Query1..4<T>` = reads, `QueryMut1..4<T>` = writes. The generator emits the correct `reads:`/`writes:` sets in `SystemMeta`. Mixed reads/writes on a single query → hand-write a class-based `System` subclass. The `@reflectable` annotation is not implemented (reserved for `fledge_debug`).

### App lifecycle
`App` (`packages/fledge_ecs/lib/src/app.dart`) is the fluent builder: `addPlugin`, `insertResource`, `addEvent`, `addSystem(system, schedule:)`, `run()`/`tick()`. `App` auto-inserts a default `FixedTimestep()` resource; override via `insertResource(FixedTimestep(stepDuration: …, maxCatchupSteps: …))` before `run()`. Plugins call `app.addSystem(...)` inside `build(App)` — plugin order still matters for the registration-order fallback above.

### Documentation vs this file
User-facing docs live in `docs/assets/docs/{section}/{page}.md` and are wired into `docs/lib/app/router.dart`. Do **not** move user docs into `CLAUDE.md`, and do not add package README content here — the READMEs are the source of truth for public API examples.

## Conventions

- **Commits**: Conventional Commits with the package name as scope, e.g. `feat(fledge_ecs): ...`, `fix(fledge_input): ...`, `chore(*): ...` for multi-package. Breaking changes use `!`, e.g. `feat(fledge_ecs)!: rename Query.iter`. Package changelogs are generated from these — a wrong scope means the change lands in the wrong CHANGELOG.
- **SDK floor**: Dart 3.11, Flutter 3.41. Bumped from Dart 3.6 in v0.2 because `flutter_soloud 4.x+` (used by `fledge_audio`) requires it, and the future `tiled 0.12` migration also depends on it. All workspace packages use `sdk: ^3.11.0` uniformly.
- **Dependency overrides**: The root pubspec overrides only `meta` (`^1.18.0`) — required for `analyzer 12.x` compatibility with `flutter_test`. Do NOT re-add a `test_api` override: the resolver picks a coherent `test` + `test_api` pair automatically once `flutter_test`'s exact pin (`test_api: 0.7.11`) is left alone. See the comment above `dependency_overrides` in `pubspec.yaml`.
- **Examples that CI builds**: `examples/basic_ecs` (compiled to exe, needs build_runner first), `examples/advanced_ecs` (compiled to exe), `examples/drifter` (native `flutter build linux|macos|windows` per matrix runner). Breaking any of them breaks CI.
- **CI platform matrix**: `analyze`, `test`, and `build-examples` jobs run on `ubuntu-latest`, `windows-latest`, and `macos-latest`. `pana` and `build-docs` stay Linux-only. When adding a plugin, verify it works on all three desktop OSes — that's the platform stance (desktop-primary, web/mobile best-effort).
