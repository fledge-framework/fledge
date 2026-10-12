import 'package:fledge_assets/fledge_assets.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:test/test.dart';

void main() {
  // Every system's order must be declared, not inherited from
  // registration order. Hot reload on registers HotReloadPollSystem in
  // Schedules.first, alongside WallTimePlugin's update system.
  for (final hotReload in [false, true]) {
    test('AssetPlugin (hot reload ${hotReload ? 'on' : 'off'}) has no '
        'ordering ambiguities', () {
      final app = App()
        ..addPlugin(const WallTimePlugin())
        ..addPlugin(AssetPlugin(enableHotReload: hotReload));
      addTearDown(() => app.world.getResource<HotReloadWatcher>()?.dispose());
      final issues = app.checkScheduleOrdering();
      expect(issues, isEmpty, reason: issues.map((i) => ' - $i').join('\n'));
    });
  }

  test('HotReloadPollSystem joins FirstSets.content', () {
    final watcher = HotReloadWatcher();
    addTearDown(watcher.dispose);
    expect(HotReloadPollSystem(watcher).meta.sets, [FirstSets.content]);
  });
}
