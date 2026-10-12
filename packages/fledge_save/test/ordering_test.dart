import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_save/fledge_save.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Every system's order must be declared, not inherited from
  // registration order. SavePlugin currently registers only the
  // SaveManager resource; this guards any systems added later.
  test('SavePlugin has no ordering ambiguities', () {
    final app = App()..addPlugin(SavePlugin());
    final issues = app.checkScheduleOrdering();
    expect(issues, isEmpty, reason: issues.map((i) => ' - $i').join('\n'));
  });
}
