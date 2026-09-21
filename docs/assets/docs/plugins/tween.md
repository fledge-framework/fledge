# Tween

The `fledge_tween` package provides easing curves and value tweens for Fledge — a small, opinionated toolkit for interpolating any value over time inside the ECS.

## Installation

```yaml
dependencies:
  fledge_tween: ^0.1.0
```

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_tween/fledge_tween.dart';

Future<void> main() async {
  final position = Position(0, 0);

  final app = App()
    ..addPlugin(WallTimePlugin())
    ..addPlugin(const TweenPlugin());

  app.world.spawn().insert(Tweener(
    tween: Tween<double>(
      from: 0,
      to: 100,
      duration: const Duration(seconds: 1),
      curve: Curves.easeOutCubic,
      lerp: lerpDouble,
    ),
    onSample: (value) => position.x = value as double,
  ));

  await app.run();
}
```

## Core concepts

### Tween&lt;T&gt;

A pure value class that describes an interpolation from `from` to `to` over `duration`. `Tween<T>` holds **no timing state** — it's just a description. Sampling requires calling `sample(elapsed)` with an elapsed duration, or attaching the tween to a `Tweener` component that owns the elapsed state.

```dart
final t = Tween<double>(
  from: 0,
  to: 100,
  duration: const Duration(seconds: 1),
  curve: Curves.easeOutCubic,
  lerp: lerpDouble,
);

t.sample(Duration.zero);              // 0
t.sample(const Duration(seconds: 1)); // 100
t.sample(const Duration(seconds: 2)); // 100 (clamped)
```

### Curve

```dart
typedef Curve = double Function(double t);
```

A curve maps `t ∈ [0, 1]` to an eased value in the same range. `Curves` is a static collection of Penner-style easings:

| Family | Curves |
|--------|--------|
| Linear | `linear` |
| Quadratic | `easeInQuad`, `easeOutQuad`, `easeInOutQuad` |
| Cubic | `easeInCubic`, `easeOutCubic`, `easeInOutCubic` |
| Quartic | `easeInQuart`, `easeOutQuart`, `easeInOutQuart` |
| Sine | `easeInSine`, `easeOutSine`, `easeInOutSine` |
| Impact | `bounceOut`, `elasticOut` (and mirrors) |

Custom curves are just functions — a cubic bezier or a spring is a one-liner:

```dart
Curve myCurve = (t) => math.pow(t, 3).toDouble();
```

### lerp helpers

`fledge_tween` ships lerp helpers for the common types:

| Helper | Signature |
|--------|-----------|
| `lerpDouble` | `(double, double, double) → double` |
| `lerpInt` | `(int, int, double) → int` |
| `lerpOffset` | `(Offset, Offset, double) → Offset` |
| `lerpColor` | `(Color, Color, double) → Color` |

For game-specific types, supply your own lerp:

```dart
Tween<Vector3>(
  from: Vector3.zero,
  to: Vector3(10, 20, 30),
  duration: const Duration(seconds: 1),
  lerp: (a, b, t) => a + (b - a) * t,
);
```

### Tweener component

`Tweener` is the ECS component that runs an active tween. It's **not** generic — the `Tween<T>` value type is erased so a single `TweenSystem` query iterates every tween in the world regardless of the type being interpolated.

```dart
world.spawn().insert(Tweener(
  tween: someTween,
  onSample: (value) => transform.x = value as double,
  onComplete: () => print('done'),
  loop: TweenLoopMode.once,
));
```

The trade-off is a `dynamic` `onSample`. In practice the closure knows the concrete type and casts:

```dart
onSample: (value) => transform.x = value as double,
```

If `Tweener` were generic on `T`, a `Tweener<double>` and a `Tweener<Color>` would land in different archetypes and each would need its own query.

### Loop modes

`TweenLoopMode` controls what happens when `elapsed` reaches `duration`:

| Mode | Effect |
|------|--------|
| `once` | `onComplete` fires and the `Tweener` component is removed. |
| `loop` | `elapsed` resets to zero and playback repeats. `onComplete` is *not* called. |
| `pingPong` | `from` and `to` swap, `elapsed` resets to zero. `onComplete` is *not* called. |

## TweenPlugin — wall-time vs fixed-timestep

`TweenPlugin` runs `TweenSystem` in one of two schedules:

```dart
// Default — variable frame delta, smooth visuals.
App()..addPlugin(const TweenPlugin());

// Fixed timestep — deterministic; use for physics-driving or
// replay-critical tweens.
App()..addPlugin(const TweenPlugin(schedule: TweenSchedule.fixed));
```

Wall-time is the right default for menu fades, camera moves, and UI transitions. Fixed-timestep is the right choice when a tween drives networked-replicated values, physics, or anything that needs to reproduce identically across runs.

Both cases require `WallTimePlugin` (or an equivalent `WallTime` resource) — that's the delta source `TweenSystem` reads.

## Common patterns

### Fading a UI element

```dart
world.spawn().insert(Tweener(
  tween: Tween<double>(
    from: 1.0,
    to: 0.0,
    duration: const Duration(milliseconds: 400),
    curve: Curves.easeInQuad,
    lerp: lerpDouble,
  ),
  onSample: (v) => uiText.color = uiText.color.withOpacity(v as double),
));
```

### Bouncing camera zoom

```dart
world.spawn().insert(Tweener(
  tween: Tween<double>(
    from: 1.0,
    to: 1.15,
    duration: const Duration(milliseconds: 250),
    curve: Curves.bounceOut,
    lerp: lerpDouble,
  ),
  onSample: (v) {
    final projection = camera2d.projection as OrthographicProjection;
    projection.viewportHeight = baseHeight * (v as double);
  },
));
```

### Color pulse

```dart
world.spawn().insert(Tweener(
  tween: Tween<Color>(
    from: const Color(0xFFFFFFFF),
    to: const Color(0xFFFF3030),
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOutSine,
    lerp: lerpColor,
  ),
  loop: TweenLoopMode.pingPong,
  onSample: (v) => sprite.color = v as Color,
));
```

## Systems reference

| System | Schedule | Description |
|--------|----------|-------------|
| `TweenSystem` | `update` (wall) or `fixedUpdate` (fixed) | Advances every `Tweener`, calls its `onSample`, and applies loop / removal on completion. |

## See also

- [Camera (2D)](/docs/plugins/camera_2d) — shake and transitions pair well with tweened camera moves.
- [UI](/docs/plugins/ui) — tween HUD entities' colors and offsets.
- [Plugins Overview](/docs/plugins/overview)
