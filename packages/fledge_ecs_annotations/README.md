# fledge_ecs_annotations

Annotations for the [Fledge](https://fledge-framework.dev) ECS framework. Used with `fledge_ecs_generator` for code generation.

[![pub package](https://img.shields.io/pub/v/fledge_ecs_annotations.svg)](https://pub.dev/packages/fledge_ecs_annotations)

## Installation

```yaml
dependencies:
  fledge_ecs_annotations: ^0.2.1
```

## Quick Start

```dart
import 'package:fledge_ecs_annotations/fledge_ecs_annotations.dart';

@component
class Position {
  double x;
  double y;
}

@system
void moveEntities(Query<(Position, Velocity)> query, Res<WallTime> time) {
  for (final (pos, vel) in query.iter()) {
    pos.x += vel.x * time.value.delta;
    pos.y += vel.y * time.value.delta;
  }
}
```

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
