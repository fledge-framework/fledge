import 'package:fledge_ecs/fledge_ecs.dart';

part 'components.g.dart';

/// Position component - represents location in 2D space.
@component
class Position {
  double x;
  double y;

  Position(this.x, this.y);

  @override
  String toString() => 'Position($x, $y)';
}

/// Velocity component - represents movement speed and direction.
@component
class Velocity {
  double dx;
  double dy;

  Velocity(this.dx, this.dy);

  @override
  String toString() => 'Velocity($dx, $dy)';
}

/// Player marker component - tags an entity as the player.
@component
class Player {
  final String name;

  Player(this.name);
}

/// Enemy marker component - tags an entity as an enemy.
@component
class Enemy {
  final int difficulty;

  Enemy({this.difficulty = 1});
}

/// Health component - represents entity health points.
@component
class Health {
  int current;
  final int max;

  Health(this.max) : current = max;

  bool get isDead => current <= 0;

  void damage(int amount) {
    current = (current - amount).clamp(0, max);
  }

  void heal(int amount) {
    current = (current + amount).clamp(0, max);
  }
}
