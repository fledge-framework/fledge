import 'package:fledge_assets/fledge_assets.dart';
import 'package:fledge_camera_2d/fledge_camera_2d.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_tiled/fledge_tiled.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Every system's order must be declared, not inherited from
  // registration order. TiledPlugin is composed with the plugins it
  // depends on (RenderPlugin must come first for its extractor), in
  // both physics modes.
  for (final (label, physics) in [
    ('variable physics', const PhysicsConfig()),
    ('fixed physics', const PhysicsConfig(mode: PhysicsMode.fixed)),
  ]) {
    test('TiledPlugin ($label) has no ordering ambiguities', () {
      final app = App()
        ..addPlugin(WallTimePlugin())
        ..addPlugin(AssetPlugin(enableHotReload: true))
        ..addPlugin(RenderPlugin())
        ..addPlugin(const CameraPlugin())
        ..addPlugin(PhysicsPlugin(config: physics))
        ..addPlugin(TiledPlugin());
      addTearDown(() => app.world.getResource<HotReloadWatcher>()?.dispose());
      final issues = app.checkScheduleOrdering();
      expect(issues, isEmpty, reason: issues.map((i) => ' - $i').join('\n'));
    });
  }

  test('TiledPlugin alone has no ordering ambiguities', () {
    final app = App()..addPlugin(TiledPlugin());
    final issues = app.checkScheduleOrdering();
    expect(issues, isEmpty, reason: issues.map((i) => ' - $i').join('\n'));
  });

  test('TilemapSpawnSystem joins FirstSets.content and stays exclusive', () {
    final meta = TilemapSpawnSystem().meta;
    expect(meta.sets, [FirstSets.content]);
    expect(meta.exclusive, isTrue);
    expect(meta.after, [HotReloadPollSystem.systemName]);
  });
}
