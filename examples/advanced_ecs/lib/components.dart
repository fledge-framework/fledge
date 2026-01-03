import 'package:fledge_ecs/fledge_ecs.dart';

/// Position component - represents location in 2D space.
@component
class Position {
  double x;
  double y;

  Position(this.x, this.y);

  @override
  String toString() => 'Position(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})';
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

/// Spaceship component - a ship that can have turrets attached.
@component
class Spaceship {
  final String name;
  int shields;

  Spaceship(this.name, {this.shields = 100});
}

/// Turret component - weapon attached to a spaceship.
@component
class Turret {
  final String type;
  int ammo;

  Turret(this.type, {this.ammo = 50});
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
}

/// Score resource - tracks the player's score.
class Score {
  int value;
  Score(this.value);
}

/// Game time resource.
class GameTime {
  double elapsed;
  GameTime(this.elapsed);
}
