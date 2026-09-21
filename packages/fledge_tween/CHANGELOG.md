# Changelog

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
