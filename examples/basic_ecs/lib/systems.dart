import 'package:fledge_ecs/fledge_ecs.dart';

import 'components.dart';

part 'systems.g.dart';

/// Movement system - updates positions based on velocities.
@system
void movementSystem(World world) {
  for (final (_, pos, vel) in world.query2<Position, Velocity>().iter()) {
    pos.x += vel.dx;
    pos.y += vel.dy;
  }
}

/// Print system - prints all entity positions (for debugging).
@system
void printPositionsSystem(World world) {
  print('--- Entity Positions ---');
  for (final (entity, pos) in world.query1<Position>().iter()) {
    final player = world.get<Player>(entity);
    final enemy = world.get<Enemy>(entity);

    String label;
    if (player != null) {
      label = 'Player(${player.name})';
    } else if (enemy != null) {
      label = 'Enemy';
    } else {
      label = 'Entity';
    }

    print('$label: $pos');
  }
}
