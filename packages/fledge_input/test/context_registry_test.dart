import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_input/fledge_input.dart';
import 'package:flutter_test/flutter_test.dart';

enum _State { menu, playing }

InputContext _ctx(
  String name, {
  int priority = 0,
  CursorMode cursor = CursorMode.visible,
}) => InputContext(
  name: name,
  map: InputMap.builder().build(),
  priority: priority,
  cursorMode: cursor,
);

void main() {
  group('pop', () {
    test('popping the last pushed context restores the default', () {
      final registry = InputContextRegistry()
        ..register(_ctx('gameplay'))
        ..register(_ctx('pause'))
        ..setDefault('gameplay');
      registry.push('pause');
      expect(registry.activeContextName, 'pause');
      registry.pop();
      expect(registry.activeContextName, 'gameplay');
    });

    test('popping restores the current state context', () {
      final registry = InputContextRegistry()
        ..registerForState(_ctx('menu'), _State.menu)
        ..registerForState(_ctx('gameplay'), _State.playing)
        ..register(_ctx('pause'))
        ..setDefault('menu');
      registry.push('pause');
      // The state changes while something is pushed: the push stays on top.
      registry.updateFromState(_State.playing);
      expect(registry.activeContextName, 'pause');
      registry.pop();
      expect(registry.activeContextName, 'gameplay');
    });

    test('clearManualStack restores the last setActive', () {
      final registry = InputContextRegistry()
        ..register(_ctx('a'))
        ..register(_ctx('b'))
        ..register(_ctx('c'))
        ..setActive('a');
      registry
        ..push('b')
        ..push('c')
        ..clearManualStack();
      expect(registry.activeContextName, 'a');
    });
  });

  group('priority', () {
    test('a lower-priority push does not take over', () {
      final registry = InputContextRegistry()
        ..register(_ctx('cutscene', priority: 10))
        ..register(_ctx('pause'))
        ..setDefault('cutscene');
      registry.push('pause');
      expect(registry.activeContextName, 'cutscene');
    });

    test('the highest-priority pushed context wins, ties go to the newest', () {
      final registry = InputContextRegistry()
        ..register(_ctx('base'))
        ..register(_ctx('high', priority: 5))
        ..register(_ctx('low'))
        ..register(_ctx('high2', priority: 5))
        ..setDefault('base');
      registry
        ..push('high')
        ..push('low');
      expect(registry.activeContextName, 'high');
      registry.push('high2');
      expect(registry.activeContextName, 'high2');
      registry.pop();
      expect(registry.activeContextName, 'high');
    });
  });

  test('listeners hear each change of active context', () {
    final heard = <String?>[];
    final registry = InputContextRegistry()
      ..register(_ctx('a'))
      ..register(_ctx('b'))
      ..setDefault('a')
      ..addListener((c) => heard.add(c?.name));
    registry
      ..push('b')
      ..push('b')
      ..pop()
      ..pop();
    expect(heard, ['b', 'a']);
  });

  group('InputPlugin', () {
    test('the cursor follows the active context without a widget', () {
      final app = App()
        ..addPlugin(
          InputPlugin(
            contexts: [
              _ctx('gameplay', cursor: CursorMode.locked),
              _ctx('menu'),
            ],
            defaultContext: 'gameplay',
          ),
        );
      final cursor = app.world.getResource<CursorState>()!;
      final registry = app.world.getResource<InputContextRegistry>()!;
      expect(cursor.mode, CursorMode.locked);

      final modes = <CursorMode>[];
      cursor.onModeChanged = modes.add;
      registry.push('menu');
      expect(cursor.mode, CursorMode.visible);
      registry.pop();
      expect(cursor.mode, CursorMode.locked);
      expect(modes, [CursorMode.visible, CursorMode.locked]);
    });

    test('enableGamepad is published as InputSettings', () {
      final app = App()..addPlugin(InputPlugin(enableGamepad: false));
      expect(app.world.getResource<InputSettings>()!.enableGamepad, isFalse);
    });
  });
}
