import 'package:fledge_audio/fledge_audio.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Every system's order must be declared, not inherited from
  // registration order. Default config enables spatial audio and
  // pause-on-focus-loss, so every optional system is registered.
  for (final (label, config) in [
    ('default config', const AudioConfig()),
    ('non-spatial', const AudioConfig.nonSpatial()),
  ]) {
    test('AudioPlugin ($label) has no ordering ambiguities', () {
      final app = App()..addPlugin(AudioPlugin(config: config));
      final issues = app.checkScheduleOrdering();
      expect(issues, isEmpty, reason: issues.map((i) => ' - $i').join('\n'));
    });
  }
}
