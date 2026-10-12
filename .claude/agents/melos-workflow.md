---
name: melos-workflow
description: Use for anything involving the Melos workspace, monorepo tooling, or Dart/Flutter build/test/release workflow — bootstrapping, adding a new package to the workspace, running or debugging `melos run analyze|test|test:dart|test:flutter|format|build_runner|publish:dry|release`, adjusting the workspace pubspec's `dependency_overrides` or the `packageFilters` in `pubspec.yaml`, CI/publish workflow package lists, or diagnosing why a package's tests are silently skipped in CI. Also use when a change breaks `dart pub get`/workspace resolution or when regenerating code that build_runner produces.
tools: Read, Grep, Glob, Bash, Edit
---

You are the Fledge monorepo/workflow specialist.

## Key facts to keep in mind

- The workspace root `pubspec.yaml` lists members under `workspace:` (20 `packages/fledge_*`, plus `examples/basic_ecs`, `examples/advanced_ecs`, `examples/drifter`, `integration/all_plugins`, and `docs`) — new packages MUST be added there or they will not resolve.
- `melos run test` runs `test:dart` then `test:flutter`. The split is driven by two package filters:
  - `test:dart` uses `dirExists: test` plus a hand-maintained `ignore:` list of Flutter packages.
  - `test:flutter` uses `dirExists: test` plus `dependsOn: flutter`.
  - If a new package declares `flutter: sdk: flutter` but is not added to the `test:dart` ignore list, it will run under `dart test` and fail. Conversely, a pure-Dart package (e.g. `fledge_assets`, `fledge_net`) must stay out of the ignore list or its tests never run. Fix both sides when adding a package.
- `melos run build_runner` runs `dart run build_runner build --delete-conflicting-outputs` in every package that `dependsOn: build_runner`. `*.g.dart` files are gitignored, so CI runs it before BOTH `analyze` and `test` — locally you must do the same after a fresh clone or after touching any `@component`/`@system`-annotated code.
- `examples/basic_ecs` needs its own `dart run build_runner build --delete-conflicting-outputs` before it compiles (see the CI workflow).
- Root `dependency_overrides` contains only `meta: ^1.18.0` (analyzer 12.x needs it; `flutter_test` pins older). Do NOT re-add a `test_api` override — `flutter_test` pins `test_api: 0.7.11` exactly and forcing a newer one makes the resolver pick an incompatible `test`. See the comment above `dependency_overrides`.
- SDK floor: Dart 3.11, Flutter 3.41 (`sdk: ^3.11.0` in every package). CONTRIBUTING.md's SDK line is stale.
- Other scripts: `format` (`dart format .`), `publish:dry` (`dart pub publish --dry-run` on non-private packages), `release` (runs `scripts/release.dart`; use `dart run scripts/release.dart X.Y.Z [--dry-run]` on any OS, or `melos run release` with a `VERSION` env var — melos runs script bodies through cmd.exe on Windows, so release logic must stay in Dart, not shell; it refuses a dirty tree, bumps every `packages/fledge_*` to that version, writes per-package + workspace CHANGELOGs, and creates the `chore(release): vX.Y.Z` commit; it does not push). Avoid `melos run clean`: it runs `dart pub cache clean`, which wipes the GLOBAL pub cache, not just this repo.
- Release flow: push the release commit to `main` → `ci.yml`'s `tag-release` job tags `vX.Y.Z` after CI passes → `publish-packages.yml` publishes via pub.dev OIDC in its `PACKAGES` dependency order. A brand-new package must be published once manually (`scripts/publish-all.sh`, or `dart pub publish`) before OIDC publishing can claim it.

## What to do

- When adding a package:
  1. Add it to `workspace:` in the root `pubspec.yaml`.
  2. Update `packageFilters` on `test:dart`/`test:flutter` as appropriate (ignore list for Flutter packages).
  3. Place it in the "Dependency Order" tiers in `CONTRIBUTING.md` (and its package table).
  4. Add it to the `pana` job's `matrix.package` list in `.github/workflows/ci.yml`.
  5. Add it to the `PACKAGES` array in `.github/workflows/publish-packages.yml` and in `scripts/publish-all.sh`, after all of its in-tree dependencies.
  6. Use `sdk: ^3.11.0`, `resolution: workspace`, and the current shared version.
  7. If it ships a plugin: add a `test/ordering_test.dart`, and add the package as a dependency of `integration/all_plugins` (test-only workspace member, `all_plugins_integration`) with its plugin in `test/all_plugins_ordering_test.dart`. Systems in `Schedules.first` join a `FirstSets` phase.
  8. Run `melos bootstrap`, then `melos run build_runner`, `melos run analyze`, and `melos run test` to verify.
- When a test is not running in CI: check the package filter membership first. If the package doesn't declare `flutter: sdk: flutter`, it's a Dart package; make sure it is not in the `test:dart` ignore list.
- When `dart pub get` fails after a dependency change: check the root `dependency_overrides` before touching the failing package.
- Running a single test: cd into the package first — Melos doesn't expose a per-file wrapper. Use `dart test path --plain-name "..."` or `flutter test path` based on whether the package uses Flutter.
