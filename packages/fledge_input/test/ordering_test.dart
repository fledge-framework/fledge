import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_input/fledge_input.dart';
import 'package:flutter_test/flutter_test.dart';

enum _Mode { menu, playing }

void main() {
  InputContext context(String name) =>
      InputContext(name: name, map: InputMap.builder().build());

  test('InputPlugin.simple has no ordering ambiguities', () {
    final app = App()..addPlugin(InputPlugin.simple(context: context('a')));
    final issues = app.checkScheduleOrdering();
    expect(issues, isEmpty, reason: issues.map((i) => ' - $i').join('\n'));
  });

  test('InputPlugin with state bindings has no ordering ambiguities', () {
    final app = App()
      ..addState<_Mode>(_Mode.menu)
      ..addPlugin(
        InputPlugin<_Mode>(
          contexts: [context('menu'), context('gameplay')],
          stateBindings: {_Mode.menu: 'menu', _Mode.playing: 'gameplay'},
          defaultContext: 'menu',
        ),
      );
    final issues = app.checkScheduleOrdering();
    expect(issues, isEmpty, reason: issues.map((i) => ' - $i').join('\n'));
  });

  test('first-schedule input systems join FirstSets.input', () {
    final metas = [
      InputPollingSystem().meta,
      ContextUpdateSystem<_Mode>().meta,
      ActionResolutionSystem().meta,
    ];
    for (final meta in metas) {
      expect(meta.sets, [FirstSets.input], reason: meta.name);
    }
    // The frame-end system lives in Schedules.last and joins no phase.
    expect(InputFrameEndSystem().meta.sets, isEmpty);
  });
}
