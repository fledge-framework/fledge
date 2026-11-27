# fledge_ecs_annotations

Annotations for the [Fledge](https://fledge-framework.dev) ECS framework. Used with `fledge_ecs_generator` for code generation.

[![pub package](https://img.shields.io/pub/v/fledge_ecs_annotations.svg)](https://pub.dev/packages/fledge_ecs_annotations)

## Installation

You usually don't need this package directly: `fledge_ecs` re-exports it.
Add it only if you import `package:fledge_ecs_annotations` yourself.

```yaml
dependencies:
  fledge_ecs_annotations: ^0.7.1
```

## Annotations

| Annotation | Effect with `fledge_ecs_generator` |
|---|---|
| `@system` | On a top-level function: generates a `<Name>Wrapper` system class whose `SystemMeta` comes from the parameter types (`QueryN` reads, `QueryMutN` writes, `Res`/`ResMut`/`ResOption`, event readers/writers, `Commands`) |
| `@component` | On a class: generates an extension with a static `componentId` (optional; any class is a component) |
| `@resource`, `@event` | Generate nothing; any class can be a resource or an event |

`SystemAnnotation.stage` and `CoreStage` are deprecated and ignored: choose
the schedule with `app.addSystem(MyFunctionWrapper(), schedule: Schedules.update)`.

```dart
import 'package:fledge_ecs/fledge_ecs.dart';

part 'game.g.dart';

@system
void movement(QueryMut2<Position, Velocity> query, Res<WallTime> time) {
  for (final (_, pos, vel) in query.iter()) {
    pos.x += vel.dx * time.value.delta;
    pos.y += vel.dy * time.value.delta;
  }
}
```

## Documentation

See [Code Generation](https://fledge-framework.dev/docs/app/codegen) on the Fledge documentation site.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
