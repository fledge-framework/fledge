import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_window/fledge_window.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Every system's order must be declared, not inherited from
  // registration order. All window modes register the same systems;
  // WallTimePlugin is included because games pair them and both
  // register in `Schedules.first`.
  for (final (label, plugin) in [
    ('default config', const WindowPlugin()),
    ('fullscreen', WindowPlugin.fullscreen()),
    ('borderless', WindowPlugin.borderless()),
  ]) {
    test('WindowPlugin ($label) has no ordering ambiguities', () {
      final app = App()
        ..addPlugin(const WallTimePlugin())
        ..addPlugin(plugin);
      final issues = app.checkScheduleOrdering();
      expect(issues, isEmpty, reason: issues.map((i) => ' - $i').join('\n'));
    });
  }

  test('window systems join FirstSets.platform', () {
    final metas = [
      WindowInitSystem(const WindowConfig()).meta,
      DisplaySyncSystem().meta,
      WindowEventSystem().meta,
    ];
    for (final meta in metas) {
      expect(meta.sets, [FirstSets.platform], reason: meta.name);
    }
  });

  test('WindowInitSystem declares its access instead of being exclusive', () {
    final meta = WindowInitSystem(const WindowConfig()).meta;
    expect(meta.exclusive, isFalse);
    expect(meta.resourceWrites, {DisplayInfo, WindowState});
    expect(meta.eventWrites, {WindowOperationFailed});
    expect(meta.after, isNot(contains(WallTimeUpdateSystem.systemName)));
  });
}
