# fledge_ecs_generator

Code generator for the [Fledge](https://fledge-framework.dev) ECS framework. Generates component registration and system wrappers from annotations.

## Installation

Add to your `dev_dependencies`:

```yaml
dev_dependencies:
  fledge_ecs_generator: ^0.1.0
  build_runner: ^2.4.0
```

And add `fledge_ecs_annotations` to your regular dependencies:

```yaml
dependencies:
  fledge_ecs: ^0.1.0
  fledge_ecs_annotations: ^0.1.0
```

## Usage

### 1. Annotate Your Code

```dart
import 'package:fledge_ecs_annotations/fledge_ecs_annotations.dart';

@component
class Position {
  double x;
  double y;
  Position(this.x, this.y);
}

@system
void moveEntities(Query<(Position, Velocity)> query, Res<Time> time) {
  for (final (pos, vel) in query.iter()) {
    pos.x += vel.x * time.value.delta;
    pos.y += vel.y * time.value.delta;
  }
}
```

### 2. Run the Generator

```bash
dart run build_runner build
```

### 3. Use Generated Code

The generator creates registration code that you can use to set up your app:

```dart
import 'my_game.g.dart';

void main() {
  final app = App()
    ..addPlugin(GeneratedPlugin());
}
```

## Related Packages

- [fledge_ecs](https://pub.dev/packages/fledge_ecs) - Core ECS framework
- [fledge_ecs_annotations](https://pub.dev/packages/fledge_ecs_annotations) - Annotation definitions

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
