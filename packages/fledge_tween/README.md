# fledge_tween

Easing curves and value tweens for [Fledge](https://fledge-framework.dev) games.

[![pub package](https://img.shields.io/pub/v/fledge_tween.svg)](https://pub.dev/packages/fledge_tween)

## Installation

```yaml
dependencies:
  fledge_tween: ^0.2.0
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

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs/plugins/tween) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
