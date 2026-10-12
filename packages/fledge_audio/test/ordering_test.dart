import 'package:fledge_assets/fledge_assets.dart' show Assets;
import 'package:fledge_audio/fledge_audio.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart' show Transform2D;
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

  test('first-schedule audio systems join FirstSets.platform', () {
    final metas = [
      AudioInitSystem(const AudioConfig()).meta,
      AudioEventSystem().meta,
      AudioFocusSystem().meta,
    ];
    for (final meta in metas) {
      expect(meta.sets, [FirstSets.platform], reason: meta.name);
    }
  });

  test('AudioInitSystem declares its access instead of being exclusive', () {
    final meta = AudioInitSystem(const AudioConfig()).meta;
    expect(meta.exclusive, isFalse);
    expect(
      meta.resourceWrites,
      containsAll(<Type>[Assets<AudioClip>, AudioState]),
    );
  });

  test(
    'spatial audio runs in last, after update-schedule transform writers',
    () {
      final app = App()
        ..addPlugin(const AudioPlugin())
        ..addSystem(
          FunctionSystem(
            'moveThings',
            writes: {ComponentId.of<Transform2D>()},
            run: (_) {},
          ),
          schedule: Schedules.update,
        );
      // SpatialAudioSystem reads Transform2D. In `update` it would be
      // unordered against the game's mover; in `last` it is not.
      final issues = app.checkScheduleOrdering();
      expect(issues, isEmpty, reason: issues.map((i) => ' - $i').join('\n'));
    },
  );
}
