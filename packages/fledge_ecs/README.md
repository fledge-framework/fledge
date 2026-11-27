# fledge_ecs

A Bevy-inspired Entity Component System (ECS) for Dart and Flutter game development.

[![pub package](https://img.shields.io/pub/v/fledge_ecs.svg)](https://pub.dev/packages/fledge_ecs)

## Installation

```yaml
dependencies:
  fledge_ecs: ^0.7.1
```

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';

class Position {
  double x, y;
  Position(this.x, this.y);
}

class Velocity {
  double x, y;
  Velocity(this.x, this.y);
}

class MovementSystem extends System {
  @override
  SystemMeta get meta => SystemMeta(
    name: 'movement',
    reads: {ComponentId.of<Velocity>()},
    writes: {ComponentId.of<Position>()},
    resourceReads: {WallTime},
  );

  @override
  void run(World world) {
    final time = world.getResource<WallTime>()!;
    for (final (_, pos, vel) in world.query2<Position, Velocity>().iter()) {
      pos.x += vel.x * time.delta;
      pos.y += vel.y * time.delta;
    }
  }
}

void main() async {
  final app = App()
    ..addPlugin(WallTimePlugin())
    ..addSystem(MovementSystem());

  app.world.spawn()
    ..insert(Position(0, 0))
    ..insert(Velocity(10, 5));

  await app.run();
}
```

### Frame time in Flutter

`WallTime` times frames with a stopwatch read when each tick starts, which
wanders by a few milliseconds. When a Flutter ticker drives the app, hand it
the vsync timestamp instead, rounded to whole display refreshes, so movement
per frame stays even and scrolling doesn't judder:

```dart
final hz = PlatformDispatcher.instance.views.first.display.refreshRate;
app.world.getResource<WallTime>()!.useClock(
  () => SchedulerBinding.instance.currentSystemFrameTimeStamp,
  frameInterval: WallTime.frameIntervalFor(hz),
);
```

`frameIntervalFor` counts a rate just off a standard one as that rate (a 59.94 Hz display reports 59). The reported rate is only a first guess: `WallTime` measures the real interval from the vsync clock and follows it, so a wrong report or a move to another monitor doesn't matter. `delta` is always a whole number of refreshes: every frame on which the clock advanced counts at least one (an early frame is still shown for a refresh of its own), and a frame on which the clock didn't move adds no time.

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
