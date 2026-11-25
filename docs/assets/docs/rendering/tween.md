# Tweens

`fledge_tween` animates values over time: easing curves, a typed `Tween`,
and a `Tweener` component that a system advances every frame, handing each
sampled value to your callback.

```yaml
dependencies:
  fledge_tween: ^0.6.0
```

It depends on Flutter (for `Offset` and `Color` lerps), so it needs Flutter
3.50+ (Dart 3.14+); desktop first, web and mobile best-effort. Add
`WallTimePlugin` with the default wall-clock mode: without a `WallTime`
resource, tweens don't advance.

## Name clashes with Flutter

`fledge_tween` exports `Curve`, `Curves` and `Tween`, and its `lerpDouble`
shares a name with the one in `dart:ui`. In a file that also imports
Material (or Flutter's widgets or animation libraries) or `dart:ui`, hide one
side or use a prefix:

```dart
import 'dart:ui' hide lerpDouble;

import 'package:fledge_tween/fledge_tween.dart';
import 'package:material_ui/material_ui.dart' hide Curve, Curves, Tween;
```

```dart
import 'package:fledge_tween/fledge_tween.dart' as ft;
import 'package:material_ui/material_ui.dart';

final slide = ft.Tween<double>(
  from: 0,
  to: 1,
  duration: const Duration(milliseconds: 300),
  curve: ft.Curves.easeOutCubic,
  lerp: ft.lerpDouble,
);
```

## Quick start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_tween/fledge_tween.dart';

class Position {
  double x = 0;
}

void main() {
  final position = Position();

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
}
```

Each frame `TweenSystem` adds the frame time to the `Tweener`'s `elapsed`,
samples the tween and calls `onSample`. On the last frame it samples the
exact end value. Then, with the default `TweenLoopMode.once`, it calls
`onComplete` and removes the `Tweener` from the entity.

## Tween

`Tween<T>` is an immutable description: `from`, `to`, a `duration` (must be
positive), a `curve` (default `Curves.linear`) and a `lerp` function for `T`.
`sample(elapsed)` returns the value at a point in time, clamped to the ends;
`reversed()` swaps the ends.

The package ships lerps for `double` (`lerpDouble`), `int` (`lerpInt`,
rounded), `Offset` (`lerpOffset`) and `Color` (`lerpColor`). Anything else
takes a function of your own:

```dart
import 'package:fledge_tween/fledge_tween.dart';
import 'package:vector_math/vector_math.dart';

Vector2 lerpVector2(Vector2 a, Vector2 b, double t) => a + (b - a) * t;

final hop = Tween<Vector2>(
  from: Vector2.zero(),
  to: Vector2(0, -24),
  duration: const Duration(milliseconds: 200),
  curve: Curves.easeOutQuad,
  lerp: lerpVector2,
);
```

## Curves

A `Curve` is a `double Function(double t)` mapping 0..1 to an eased value.
`Curves` has `linear`; `easeIn`, `easeOut` and `easeInOut` variants of
`Quad`, `Cubic`, `Quart` and `Sine` (`Curves.easeInOutSine` and so on);
`bounceIn`, `bounceOut`, `elasticIn` and `elasticOut`. Any function with that
shape works as a curve.

## Tweener

```dart
import 'dart:ui' show Color;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_tween/fledge_tween.dart';

/// Pulses a sprite's tint between white and red forever.
void pulse(World world, Entity entity) {
  final sprite = world.get<Sprite>(entity)!;
  world.insert(
    entity,
    Tweener(
      tween: Tween<Color>(
        from: const Color(0xFFFFFFFF),
        to: const Color(0xFFFF4040),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutSine,
        lerp: lerpColor,
      ),
      onSample: (value) => sprite.color = value as Color,
      loop: TweenLoopMode.pingPong,
    ),
  );
}

/// Entities to despawn, drained by a system of your own.
class DespawnQueue {
  final entities = <Entity>[];
}

/// Fades a sprite out over half a second, then queues it for despawning.
void fadeOut(World world, Entity entity) {
  final sprite = world.get<Sprite>(entity)!;
  final start = sprite.color;
  world.insert(
    entity,
    Tweener(
      tween: Tween<double>(
        from: start.a,
        to: 0,
        duration: const Duration(milliseconds: 500),
        lerp: lerpDouble,
      ),
      onSample: (value) =>
          sprite.color = start.withValues(alpha: value as double),
      onComplete: () =>
          world.getResource<DespawnQueue>()!.entities.add(entity),
    ),
  );
}
```

| Field | Meaning |
|---|---|
| `tween` | The `Tween` to play. |
| `onSample` | Called every frame with the current value (typed `dynamic`; cast it). |
| `onComplete` | Called once at the end, only with `TweenLoopMode.once`. |
| `loop` | `once` (remove when done), `loop` (restart), `pingPong` (play back and forth). |
| `elapsed` | Time played so far; set it to start part-way through. |

A few things to know:

- An entity holds one `Tweener` (it's a component). The `Tweener` doesn't
  have to sit on the entity it animates, since `onSample` can write anything,
  so to run several tweens at once give each its own small entity.
- Inserting a new `Tweener` replaces the running one.
- `onSample` and `onComplete` run while `TweenSystem` is walking the
  `Tweener` query. Don't spawn, despawn or add and remove components there;
  record what should happen (as `fadeOut` does) and do it in a later system.
- `onSample` changes values in place. In-place writes don't trip `Changed<T>`
  filters; call `world.markChanged<T>(entity)` from the callback if a system
  depends on that (see [Change Detection](/docs/ecs/change-detection)).
- Use `Color.withValues(alpha: ...)`; `withOpacity` is deprecated.

## Wall clock or fixed step

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_tween/fledge_tween.dart';

final app = App()
  ..addPlugin(const TweenPlugin(schedule: TweenSchedule.fixed));
```

| `TweenPlugin(schedule:)` | `TweenSystem` runs in | Advances by |
|---|---|---|
| `TweenSchedule.wall` (default) | `Schedules.update` | `WallTime.delta` |
| `TweenSchedule.fixed` | `Schedules.fixedUpdate` | `FixedTimestep.stepDuration` per step |

Use the fixed step for tweens that drive simulation (a moving platform that
physics collides with), so they advance deterministically with it. Order
other systems against the tween with `TweenSystem.systemName`.

See the [API reference](https://pub.dev/documentation/fledge_tween/latest/)
for every member.
