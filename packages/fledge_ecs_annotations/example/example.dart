import 'package:fledge_ecs_annotations/fledge_ecs_annotations.dart';

// Mark a class as a component for code generation
@component
class Position {
  double x;
  double y;
  Position(this.x, this.y);
}

@component
class Velocity {
  double x;
  double y;
  Velocity(this.x, this.y);
}

// Mark a function as a system for code generation
// The generator will create a System class wrapper
@system
void moveEntities(Query<(Position, Velocity)> query, Res<Time> time) {
  for (final (pos, vel) in query.iter()) {
    pos.x += vel.x * time.value.delta;
    pos.y += vel.y * time.value.delta;
  }
}

// Note: Run `dart run build_runner build` to generate the .g.dart files

// Placeholder types for the example to compile
class Query<T> {
  Iterable<T> iter() => [];
}

class Res<T> {
  T get value => throw UnimplementedError();
}

class Time {
  double get delta => 0.016;
}

void main() {
  // This example shows annotation usage.
  // Run build_runner to generate the actual code.
  print('See fledge_ecs_generator for code generation.');
}
