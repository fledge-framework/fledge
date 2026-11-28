# fledge_ecs_generator

Code generator for the [Fledge](https://fledge-framework.dev) ECS framework. Generates component registration and system wrappers from annotations.

[![pub package](https://img.shields.io/pub/v/fledge_ecs_generator.svg)](https://pub.dev/packages/fledge_ecs_generator)

## Installation

```yaml
dependencies:
  fledge_ecs: ^0.7.2

dev_dependencies:
  build_runner: ^2.10.4
  fledge_ecs_generator: ^0.7.2
```

`fledge_ecs` re-exports the annotations from `fledge_ecs_annotations`.

## Quick Start

Write a system as a top-level function. Its parameter types declare what it
reads and writes:

```dart
// lib/movement.dart
import 'package:fledge_ecs/fledge_ecs.dart';

part 'movement.g.dart';

class Position {
  double x, y;
  Position(this.x, this.y);
}

class Velocity {
  double dx, dy;
  Velocity(this.dx, this.dy);
}

@system
void movement(QueryMut2<Position, Velocity> query, Res<WallTime> time) {
  for (final (_, pos, vel) in query.iter()) {
    pos.x += vel.dx * time.value.delta;
    pos.y += vel.dy * time.value.delta;
  }
}
```

Generate `movement.g.dart` (a part of `movement.dart`; never import it):

```bash
dart run build_runner build
```

Register the generated `MovementWrapper`, choosing its schedule:

```dart
final app = App()
  ..addPlugin(WallTimePlugin())
  ..addSystem(MovementWrapper(), schedule: Schedules.update);
```

The wrapper's `SystemMeta` declares `writes: {Position, Velocity}` and
`resourceReads: {WallTime}`, and it has a `static const String systemName`
for other systems' `before:`/`after:`.

| Parameter | Declares |
|---|---|
| `Query1..4<...>` | reads |
| `QueryMut1..4<...>` | writes |
| `Res<T>` / `ResOption<T>` / `ResMut<T>` | resource read / read / write |
| `EventReader<T>` / `EventWriter<T>` / `EventReadWriter<T>` | event read / write / both |
| `Commands` | nothing; applied after the function returns |
| `World` | nothing (build warning) |

`async` functions are awaited. The annotation can't set a schedule,
`before:`/`after:` or filters: pass the schedule to `addSystem`, put the
wrapper in a system set for ordering, or hand-write a `System` class.

## Documentation

See [Code Generation](https://fledge-framework.dev/docs/app/codegen) on the Fledge documentation site for the details and limits.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
