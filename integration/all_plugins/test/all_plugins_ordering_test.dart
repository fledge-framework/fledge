// Composes every Fledge plugin in one App and asserts the combined schedule
// has no registration-order-only ambiguities.
//
// Per-package `test/ordering_test.dart` files can only compose a package with
// its own dependencies. Conflicts between packages that don't depend on each
// other (e.g. window init vs tilemap spawn in `Schedules.first`) only show up
// here. They are resolved by `FirstSets` phases, not cross-package
// references.
//
// Never ticks the App, so no native window/audio calls happen on CI.
//
// When adding a plugin package to the workspace, add its plugin(s) here.
import 'package:fledge_assets/fledge_assets.dart';
import 'package:fledge_audio/fledge_audio.dart';
import 'package:fledge_calendar/fledge_calendar.dart';
import 'package:fledge_camera_2d/fledge_camera_2d.dart';
import 'package:fledge_debug/fledge_debug.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_input/fledge_input.dart';
import 'package:fledge_lighting_2d/fledge_lighting_2d.dart';
import 'package:fledge_net/fledge_net.dart';
import 'package:fledge_particles/fledge_particles.dart';
// fledge_tiled re-exports physics today, but that re-export is slated for
// removal; import it explicitly so this test survives.
// ignore: unnecessary_import
import 'package:fledge_physics/fledge_physics.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_save/fledge_save.dart';
import 'package:fledge_tiled/fledge_tiled.dart';
import 'package:fledge_tween/fledge_tween.dart';
import 'package:fledge_ui/fledge_ui.dart';
import 'package:fledge_window/fledge_window.dart';
import 'package:fledge_yarn/fledge_yarn.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plugin groups; each inner list is added in order and kept adjacent
/// when the outer list is reversed (YarnPlugin must precede
/// DialogueCorePlugin).
List<List<Plugin>> rest(PhysicsMode mode) => [
  [const WindowPlugin()],
  [
    InputPlugin.simple(
      context: InputContext(name: 'g', map: InputMap.builder().build()),
    ),
  ],
  [const AudioPlugin()],
  [PhysicsPlugin(config: PhysicsConfig(mode: mode))],
  [TiledPlugin()],
  [const UiPlugin()],
  [PlacementCorePlugin()],
  [const LightingPlugin()],
  [const ParticlePlugin()],
  [
    TweenPlugin(
      schedule: mode == PhysicsMode.fixed
          ? TweenSchedule.fixed
          : TweenSchedule.wall,
    ),
  ],
  [const CalendarPlugin()],
  [SavePlugin()],
  [YarnPlugin(), DialogueCorePlugin()],
  [NetworkPlugin()],
  [const DebugPlugin()],
];

void main() {
  for (final mode in PhysicsMode.values) {
    for (final reversed in [false, true]) {
      test('all plugins, $mode, ${reversed ? 'reversed' : 'forward'}', () {
        final app = App()
          ..addPlugin(const WallTimePlugin())
          ..addPlugin(AssetPlugin())
          ..addPlugin(RenderPlugin())
          ..addPlugin(const CameraPlugin())
          ..addSystem(
            TransformPropagateSystem(),
            schedule: Schedules.preUpdate,
          );
        final plugins = rest(mode);
        for (final group in reversed ? plugins.reversed : plugins) {
          for (final p in group) {
            app.addPlugin(p);
          }
        }
        final issues = app.checkScheduleOrdering();
        expect(issues, isEmpty, reason: issues.map((i) => ' - $i').join('\n'));
      });
    }
  }
}
