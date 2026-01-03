// ignore_for_file: avoid_print
import 'package:fledge_ecs/fledge_ecs.dart';

// Components are plain Dart classes
class Position {
  double x, y;
  Position(this.x, this.y);
}

class Velocity {
  double x, y;
  Velocity(this.x, this.y);
}

// Systems operate on component queries
class MovementSystem extends System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'movement',
        writes: {ComponentId.of<Position>()},
        reads: {ComponentId.of<Velocity>()},
      );

  @override
  Future<void> run(World world) async {
    for (final (_, pos, vel) in world.query2<Position, Velocity>().iter()) {
      pos.x += vel.x;
      pos.y += vel.y;
    }
  }
}

void main() async {
  // Create the app
  final app = App()
    ..addPlugin(TimePlugin())
    ..addSystem(MovementSystem());

  // Spawn an entity
  app.world.spawn()
    ..insert(Position(0, 0))
    ..insert(Velocity(1, 0.5));

  // Run a few ticks
  for (var i = 0; i < 3; i++) {
    await app.tick();
    final (_, pos) = app.world.query1<Position>().iter().first;
    print('Position: (${pos.x}, ${pos.y})');
  }
}
