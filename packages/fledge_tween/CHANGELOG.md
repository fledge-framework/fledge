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

- SDK floor bumped to Dart `>=3.11.0` / Flutter `>=3.41.0` (was 3.6 / 3.38). Matches the workspace-wide floor.


## [0.2.0] - 2026-09-20

### Added

- Initial release.
- Easing curves and `Tween<T>` primitive.
- `TweenPlugin` supporting the wall or fixed schedule.


## [0.1.0]

### Features

- Initial release of `fledge_tween`.
- `Curve` typedef and `Curves` collection of standard easing functions
  (linear, quad/cubic/quart in/out/in-out, `bounceOut`, `elasticOut`).
- `Tween<T>` value class for interpolating between two values with a
  configurable duration, curve, and lerp function.
- `Tweener` component + `TweenSystem` that advances active tweens each
  frame and invokes a per-entity sample callback.
- `TweenLoopMode` (once / loop / pingPong) with `onComplete` fired once
  when a `once` tween finishes.
- `TweenPlugin` with a `TweenSchedule` option to run the system in either
  `Schedules.update` (wall-time; default) or `Schedules.fixedUpdate`.
- Type-specific lerp helpers: `lerpDouble`, `lerpInt`, `lerpOffset`,
  `lerpColor`.
