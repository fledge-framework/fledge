import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

void main() {
  // Every system's order must be declared, not inherited from
  // registration order. NetworkPlugin currently registers only
  // resources; covering every mode guards systems added later.
  for (final mode in NetworkMode.values) {
    test('NetworkPlugin (${mode.name}) has no ordering ambiguities', () {
      final app = App()
        ..addPlugin(NetworkPlugin(config: NetworkConfig(mode: mode)));
      final issues = app.checkScheduleOrdering();
      expect(issues, isEmpty, reason: issues.map((i) => ' - $i').join('\n'));
    });
  }
}
