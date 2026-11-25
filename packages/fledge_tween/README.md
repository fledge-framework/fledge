# fledge_tween

Easing curves and value tweens for [Fledge](https://fledge-framework.dev) games.

[![pub package](https://img.shields.io/pub/v/fledge_tween.svg)](https://pub.dev/packages/fledge_tween)

## Installation

```yaml
dependencies:
  fledge_tween: ^0.7.0
```

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_tween/fledge_tween.dart';

class Position {
  double x = 0;
}

void main() {
  final position = Position();

  final app = App()
    ..addPlugin(WallTimePlugin()) // tweens advance by WallTime.delta
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
  // Tick the app each frame (from a Flutter ticker in a game).
}
```

`Curve`, `Curves` and `Tween` share names with Flutter's, and `lerpDouble` with `dart:ui`'s. In files that import both, hide one side (`import 'package:material_ui/material_ui.dart' hide Curve, Curves, Tween;`) or import `fledge_tween` with a prefix.

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs/rendering/tween) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
