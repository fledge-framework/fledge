import 'package:drifter_example/game_app.dart';
import 'package:flutter_test/flutter_test.dart';

/// Catches the class of bug where two systems in the same stage both
/// write the same component (or read/write combination) and their order
/// depends on registration order alone. In Drifter this bit us when
/// `InputMovementSystem` was in `CoreStage.update` next to
/// `CollisionResolutionSystem` — the scheduler let physics clamp
/// last-frame velocity, then input overwrote it with a wall-ward value,
/// and the player walked straight through walls.
void main() {
  test('Drifter schedule has no ordering ambiguities', () {
    final app = buildApp();
    final issues = app.checkScheduleOrdering();

    expect(
      issues,
      isEmpty,
      reason: 'unexpected schedule ambiguities:\n'
          '${issues.map((i) => ' - $i').join('\n')}',
    );
  });
}
