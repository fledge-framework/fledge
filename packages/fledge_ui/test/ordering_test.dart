import 'package:fledge_camera_2d/fledge_camera_2d.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_ui/fledge_ui.dart';
import 'package:flutter_test/flutter_test.dart';

(double, double) _tileToWorld(PlacementTile tile) =>
    (tile.x * 16.0, tile.y * 16.0);

Sprite? _spriteFor(World world, String key) => null;

const _ghost = PlacementGhostConfig(
  tileToWorld: _tileToWorld,
  ghostSpriteFor: _spriteFor,
);

void main() {
  // Every system's order must be declared, not inherited from
  // registration order.
  test('UiPlugin has no ordering ambiguities', () {
    final app = App()
      ..addPlugin(RenderPlugin())
      ..addPlugin(const UiPlugin());
    final issues = app.checkScheduleOrdering();
    expect(issues, isEmpty, reason: issues.map((i) => ' - $i').join('\n'));
  });

  // PlacementCorePlugin is opt-in; the ghost system is only registered
  // with a ghost config.
  for (final (label, ghost) in [
    ('without ghost', null),
    ('with ghost', _ghost),
  ]) {
    test('UiPlugin + PlacementCorePlugin ($label) has no ordering '
        'ambiguities', () {
      final app = App()
        ..addPlugin(RenderPlugin())
        ..addPlugin(const UiPlugin())
        ..addPlugin(PlacementCorePlugin(ghost: ghost));
      final issues = app.checkScheduleOrdering();
      expect(issues, isEmpty, reason: issues.map((i) => ' - $i').join('\n'));
    });
  }

  // Realistic composition, as in examples/drifter: render + camera + UI,
  // with transform propagation in preUpdate.
  for (final (label, placement) in [
    ('', null),
    (' + PlacementCorePlugin with ghost', PlacementCorePlugin(ghost: _ghost)),
  ]) {
    test('RenderPlugin + CameraPlugin + UiPlugin$label + '
        'TransformPropagateSystem has no ordering ambiguities', () {
      final app = App()
        ..addPlugin(const WallTimePlugin())
        ..addPlugin(RenderPlugin())
        ..addPlugin(const CameraPlugin())
        ..addPlugin(const UiPlugin());
      if (placement != null) app.addPlugin(placement);
      app.addSystem(TransformPropagateSystem(), schedule: Schedules.preUpdate);
      final issues = app.checkScheduleOrdering();
      expect(issues, isEmpty, reason: issues.map((i) => ' - $i').join('\n'));
    });
  }

  // Games that re-run propagation in postUpdate, registered after every
  // plugin, must not hit an ordering cycle with the camera or ghost.
  test('RenderPlugin + CameraPlugin + UiPlugin + PlacementCorePlugin with '
      'ghost + TransformPropagateSystem in postUpdate has no ordering '
      'ambiguities', () {
    final app = App()
      ..addPlugin(const WallTimePlugin())
      ..addPlugin(RenderPlugin())
      ..addPlugin(const CameraPlugin())
      ..addPlugin(const UiPlugin())
      ..addPlugin(PlacementCorePlugin(ghost: _ghost))
      ..addSystem(TransformPropagateSystem(), schedule: Schedules.postUpdate);
    final issues = app.checkScheduleOrdering();
    expect(issues, isEmpty, reason: issues.map((i) => ' - $i').join('\n'));
  });
}
