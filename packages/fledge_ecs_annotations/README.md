# fledge_ecs_annotations

Annotations for the [Fledge](https://fledge-framework.dev) ECS framework. Used with `fledge_ecs_generator` for code generation.

## Installation

```yaml
dependencies:
  fledge_ecs_annotations: ^0.1.0
```

## Usage

This package provides annotations used by the Fledge code generator to create boilerplate code for your ECS components and systems.

### Available Annotations

```dart
import 'package:fledge_ecs_annotations/fledge_ecs_annotations.dart';

// Mark a class as a component
@component
class Position {
  double x;
  double y;
}

// Mark a function as a system
@system
void moveEntities(Query<(Position, Velocity)> query, Res<Time> time) {
  for (final (pos, vel) in query.iter()) {
    pos.x += vel.x * time.value.delta;
    pos.y += vel.y * time.value.delta;
  }
}
```

## Related Packages

- [fledge_ecs](https://pub.dev/packages/fledge_ecs) - Core ECS framework
- [fledge_ecs_generator](https://pub.dev/packages/fledge_ecs_generator) - Code generator

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
