## 0.2.3

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

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
