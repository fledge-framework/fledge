import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_yarn/fledge_yarn.dart';
import 'package:flutter_test/flutter_test.dart';

class _GameEvent {}

class _GameResource {}

void main() {
  // Every system's order must be declared, not inherited from
  // registration order. DialogueCorePlugin's options change which
  // schedule its systems land in and what they declare, so each
  // branch is checked.
  test('YarnPlugin has no ordering ambiguities', () {
    final app = App()..addPlugin(YarnPlugin());
    final issues = app.checkScheduleOrdering();
    expect(issues, isEmpty, reason: issues.map((i) => ' - $i').join('\n'));
  });

  for (final (label, build) in <(String, DialogueCorePlugin Function())>[
    ('default config', DialogueCorePlugin.new),
    (
      'fixedUpdate schedule',
      () => DialogueCorePlugin(schedule: Schedules.fixedUpdate),
    ),
    (
      'preUpdate schedule',
      () => DialogueCorePlugin(schedule: Schedules.preUpdate),
    ),
    (
      'command access',
      () => DialogueCorePlugin(
        commandAccess: const DialogueCommandAccess(
          resourceWrites: {_GameResource},
          eventWrites: {_GameEvent},
        ),
      ),
    ),
    (
      'custom time source',
      () => DialogueCorePlugin(
        timeSource: DialogueTimeSource(
          resource: _GameResource,
          delta: (_) => 0,
        ),
      ),
    ),
  ]) {
    test('YarnPlugin + DialogueCorePlugin ($label) has no ordering '
        'ambiguities', () {
      final app = App()
        ..addPlugin(YarnPlugin())
        ..addPlugin(build());
      final issues = app.checkScheduleOrdering();
      expect(issues, isEmpty, reason: issues.map((i) => ' - $i').join('\n'));
    });
  }
}
