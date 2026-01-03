// Example usage of fledge_ecs_generator
//
// 1. Add annotations to your code:
//
// ```dart
// import 'package:fledge_ecs_annotations/fledge_ecs_annotations.dart';
//
// part 'my_game.g.dart';
//
// @component
// class Position {
//   double x, y;
//   Position(this.x, this.y);
// }
//
// @system
// void moveEntities(Query<(Position, Velocity)> query) {
//   for (final (pos, vel) in query.iter()) {
//     pos.x += vel.x;
//   }
// }
// ```
//
// 2. Run the generator:
//
// ```bash
// dart run build_runner build
// ```
//
// 3. Use the generated plugin:
//
// ```dart
// import 'my_game.g.dart';
//
// void main() {
//   final app = App()
//     ..addPlugin(GeneratedPlugin());
// }
// ```

void main() {
  print('fledge_ecs_generator is a build_runner generator.');
  print('See the package README for usage instructions.');
}
