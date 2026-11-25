import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_window/fledge_window.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const windowChannel = MethodChannel('window_manager');
  const screenChannel = MethodChannel('screen_retriever');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<String> calls;
  late Set<String> failing;
  late World world;
  late WindowState state;

  setUp(() {
    calls = [];
    failing = {};
    messenger.setMockMethodCallHandler(windowChannel, (call) async {
      calls.add(call.method);
      if (failing.contains(call.method)) {
        throw PlatformException(code: 'denied', message: 'nope');
      }
      return null;
    });
    messenger.setMockMethodCallHandler(screenChannel, (call) async => null);

    world = World()
      ..events.register<SetWindowModeRequest>()
      ..events.register<SetWindowSizeRequest>()
      ..events.register<SetWindowPositionRequest>()
      ..events.register<WindowModeChanged>()
      ..events.register<WindowResized>()
      ..events.register<WindowMoved>()
      ..events.register<WindowOperationFailed>();
    state = WindowState.initial(
      const WindowConfig(
        mode: WindowMode.windowed,
        windowedSize: Size(800, 600),
      ),
    );
    world
      ..insertResource(state)
      ..insertResource(
        DisplayInfo.empty()..updateDisplays(const [
          Display(
            index: 0,
            name: 'Test',
            size: Size(1920, 1080),
            bounds: Rect.fromLTWH(0, 0, 1920, 1080),
            scaleFactor: 1,
            refreshRate: Display.unknownRefreshRate,
            isPrimary: true,
          ),
        ], 0),
      );
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(windowChannel, null);
    messenger.setMockMethodCallHandler(screenChannel, null);
  });

  /// Makes the events sent this frame readable, like `App.tick` does.
  void nextFrame() => world.updateEvents();

  List<T> sent<T>() => world.eventReader<T>().read().toList();

  test('a frame with no requests runs synchronously and calls nothing', () {
    final System system = WindowEventSystem();
    final result = system.run(world);
    expect(result, isNot(isA<Future<void>>()));
    expect(calls, isEmpty);
  });

  test('a frame with requests still returns synchronously', () {
    final System system = WindowEventSystem();
    world.setWindowSize(const Size(1024, 768));
    nextFrame();
    expect(system.run(world), isNot(isA<Future<void>>()));
  });

  test(
    'a resize is applied on the frame after the native call returns',
    () async {
      final system = WindowEventSystem();
      world.setWindowSize(const Size(1024, 768));
      nextFrame();

      system.run(world);
      // The native call has started but nothing is applied yet.
      expect(state.size, const Size(800, 600));

      await pumpEventQueue();
      expect(calls, contains('setBounds'));
      expect(state.size, const Size(800, 600));

      system.run(world);
      expect(state.size, const Size(1024, 768));
      expect(state.savedWindowedSize, const Size(1024, 768));
      nextFrame();
      final resized = sent<WindowResized>().single;
      expect(resized.previousSize, const Size(800, 600));
      expect(resized.newSize, const Size(1024, 768));
    },
  );

  test(
    'a failed native call sends WindowOperationFailed and keeps state',
    () async {
      final system = WindowEventSystem();
      failing.add('setFullScreen');
      world.setWindowMode(WindowMode.fullscreen);
      nextFrame();

      system.run(world);
      await pumpEventQueue();
      system.run(world);

      expect(state.mode, WindowMode.windowed);
      expect(state.size, const Size(800, 600));
      expect(state.savedWindowedSize, const Size(800, 600));
      nextFrame();
      expect(sent<WindowModeChanged>(), isEmpty);
      final failure = sent<WindowOperationFailed>().single;
      expect(failure.operation, 'setMode');
      expect(failure.attemptedMode, WindowMode.fullscreen);
    },
  );

  test(
    'a mode change saves the windowed bounds and sends WindowModeChanged',
    () async {
      final system = WindowEventSystem();
      world.setWindowMode(WindowMode.fullscreen);
      nextFrame();

      system.run(world);
      await pumpEventQueue();
      system.run(world);

      expect(state.mode, WindowMode.fullscreen);
      expect(state.size, const Size(1920, 1080));
      expect(state.savedWindowedSize, const Size(800, 600));
      nextFrame();
      final changed = sent<WindowModeChanged>().single;
      expect(changed.previousMode, WindowMode.windowed);
      expect(changed.newMode, WindowMode.fullscreen);
    },
  );

  test('queued requests run one at a time against the updated state', () async {
    final system = WindowEventSystem();
    // Same frame: go fullscreen, then try to resize. The resize is planned
    // after fullscreen applies, so it is dropped (windowed mode only).
    world
      ..setWindowMode(WindowMode.fullscreen)
      ..setWindowSize(const Size(1024, 768));
    nextFrame();

    system.run(world);
    await pumpEventQueue();
    system.run(world);
    await pumpEventQueue();
    system.run(world);

    expect(state.mode, WindowMode.fullscreen);
    expect(state.size, const Size(1920, 1080));
    expect(calls, isNot(contains('setBounds')));
  });

  test('WindowInitSystem returns synchronously after its first run', () async {
    world.insertResource(WindowOsEvents());
    final System system = WindowInitSystem(const WindowConfig());
    final first = system.run(world);
    expect(first, isA<Future<void>>());
    await first;
    expect(system.run(world), isNot(isA<Future<void>>()));
  });
}
