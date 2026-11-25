import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_window/fledge_window.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late World world;
  late WindowOsEvents os;
  late WindowState state;
  final system = WindowOsEventSystem();

  setUp(() {
    world = World()
      ..events.register<WindowFocusChanged>()
      ..events.register<WindowResized>()
      ..events.register<WindowMoved>();
    os = WindowOsEvents();
    state = WindowState.initial(const WindowConfig());
    world
      ..insertResource(os)
      ..insertResource(state);
  });

  List<T> sent<T>() {
    world.updateEvents(); // make this frame's events readable
    return world.eventReader<T>().read().toList();
  }

  test('focus changes update state and send WindowFocusChanged', () {
    os.focusChanged(true);
    system.run(world);
    expect(state.isFocused, isTrue);
    expect(sent<WindowFocusChanged>().single.isFocused, isTrue);

    os.focusChanged(false);
    system.run(world);
    expect(state.isFocused, isFalse);
    expect(sent<WindowFocusChanged>().single.isFocused, isFalse);
  });

  test('user resize and move send events with the previous values', () {
    final before = state.size;
    os
      ..resized(const Size(1000, 600))
      ..moved(const Offset(40, 50));
    system.run(world);

    final resized = sent<WindowResized>().single;
    expect(resized.previousSize, before);
    expect(resized.newSize, const Size(1000, 600));
    expect(state.size, const Size(1000, 600));
    expect(state.position, const Offset(40, 50));
  });

  test('an OS echo of the current state sends nothing', () {
    os
      ..resized(state.size)
      ..moved(state.position)
      ..focusChanged(state.isFocused);
    system.run(world);
    world.updateEvents();
    expect(world.eventReader<WindowResized>().read(), isEmpty);
    expect(world.eventReader<WindowMoved>().read(), isEmpty);
    expect(world.eventReader<WindowFocusChanged>().read(), isEmpty);
  });

  test('several callbacks in one frame coalesce to the latest', () {
    os
      ..resized(const Size(800, 600))
      ..resized(const Size(900, 700))
      ..minimizedChanged(true);
    system.run(world);
    expect(sent<WindowResized>().single.newSize, const Size(900, 700));
    expect(state.isMinimized, isTrue);
    expect(os.hasPending, isFalse);
  });
}
