import 'package:fledge_ecs/fledge_ecs.dart';

// Components are plain Dart classes.
class Position {
  double x, y;
  Position(this.x, this.y);
}

class Velocity {
  double dx, dy;
  Velocity(this.dx, this.dy);
}

// Systems declare what they touch, so the scheduler can order them.
class MovementSystem extends System {
  static const String systemName = 'movement';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    writes: {ComponentId.of<Position>()},
    reads: {ComponentId.of<Velocity>()},
    resourceReads: {WallTime},
  );

  @override
  void run(World world) {
    final dt = world.getResource<WallTime>()!.delta;
    for (final (_, pos, vel) in world.query2<Position, Velocity>().iter()) {
      pos.x += vel.dx * dt;
      pos.y += vel.dy * dt;
    }
  }
}

Future<void> main() async {
  final app = App()
    ..addPlugin(const WallTimePlugin())
    ..addSystem(MovementSystem(), schedule: Schedules.update);

  app.world.spawnWith([Position(0, 0), Velocity(60, 30)]);

  await app.tick(); // one frame; app.run() loops until stopped
}
