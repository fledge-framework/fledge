# Changelog

## [0.2.2] - 2026-09-21



## [0.2.1] - 2026-09-20

### Added

- `example/example.dart` demonstrating the package's core API (pana requirement).

### Changed

- SDK floor bumped to Dart `>=3.11.0` (was 3.6). Matches the workspace-wide floor.


## [0.2.0] - 2026-09-20

### Added

- Initial release.
- Ref-counted `Handle<T>` + per-type `Assets<T>` storage.
- `Loader<T>` interface with pluggable per-type loaders.
- Optional native hot reload backed by `watcher`.


## [0.1.0] - 2026-09-20

### Features

- **fledge_assets:** Initial release. `Handle<T>` / `HandleId`, per-type
  `Assets<T>` resource with ref-counted entries, `Loader<T>` interface,
  an `AssetPlugin` that gates optional native hot reload, and a
  `HotReloadPollSystem` that drains file-change events into
  `Assets<T>.reload`. Downstream packages (`fledge_render_2d`,
  `fledge_audio`, `fledge_tiled`) migrate their in-tree asset registries
  onto this in the same release.
