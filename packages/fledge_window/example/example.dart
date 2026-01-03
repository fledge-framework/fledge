// ignore_for_file: avoid_print
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_window/fledge_window.dart';

void main() async {
  // Start in borderless fullscreen
  final app = App()
    ..addPlugin(TimePlugin())
    ..addPlugin(WindowPlugin.borderless(title: 'My Game'));

  // Or other modes:
  // WindowPlugin.fullscreen(title: 'My Game')
  // WindowPlugin.windowed(title: 'My Game', size: Size(1280, 720))

  await app.tick();

  // Toggle window modes at runtime:
  // app.world.toggleFullscreen();
  // app.world.toggleBorderless();
  // app.world.cycleWindowMode();
  // app.world.setWindowMode(WindowMode.windowed);

  // Query window state:
  final state = app.world.windowState;
  if (state != null) {
    print('Window mode: ${state.mode}');
    print('Window size: ${state.size}');
  }

  // Listen for window events in a system:
  // for (final event in world.eventReader<WindowModeChanged>().read()) {
  //   print('Mode: ${event.previousMode} -> ${event.newMode}');
  // }
  //
  // for (final event in world.eventReader<WindowFocusChanged>().read()) {
  //   if (!event.isFocused) {
  //     // Pause game
  //   }
  // }

  print('Window plugin configured');
}
