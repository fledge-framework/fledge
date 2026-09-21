# fledge_ecs_generator

Code generator for the [Fledge](https://fledge-framework.dev) ECS framework. Generates component registration and system wrappers from annotations.

[![pub package](https://img.shields.io/pub/v/fledge_ecs_generator.svg)](https://pub.dev/packages/fledge_ecs_generator)

## Installation

```yaml
dev_dependencies:
  fledge_ecs_generator: ^0.2.1
  build_runner: ^2.4.0

dependencies:
  fledge_ecs: ^0.2.1
  fledge_ecs_annotations: ^0.2.1
```

## Quick Start

```dart
import 'package:fledge_ecs_annotations/fledge_ecs_annotations.dart';

@component
class Position {
  double x;
  double y;
  Position(this.x, this.y);
}

@system
void moveEntities(Query<(Position, Velocity)> query, Res<WallTime> time) {
  for (final (pos, vel) in query.iter()) {
    pos.x += vel.x * time.value.delta;
    pos.y += vel.y * time.value.delta;
  }
}
```

Run the generator:

```bash
dart run build_runner build
```

Then import the generated code:

```dart
import 'my_game.g.dart';

void main() {
  final app = App()..addPlugin(GeneratedPlugin());
}
```

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
