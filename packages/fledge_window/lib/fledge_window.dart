/// Window management plugin for the Fledge ECS game framework.
///
/// Provides fullscreen, borderless, and windowed modes with runtime switching.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:fledge_ecs/fledge_ecs.dart';
/// import 'package:fledge_window/fledge_window.dart';
///
/// void main() async {
///   // Fullscreen game
///   await App()
///     .addPlugin(WindowPlugin.fullscreen(title: 'My Game'))
///     .addPlugin(TimePlugin())
///     .run();
/// }
/// ```
///
/// ## Window Modes
///
/// Three modes are supported:
/// - **Fullscreen**: True exclusive fullscreen
/// - **Borderless**: Frameless window matching display size
/// - **Windowed**: Standard window with title bar
///
/// ## Runtime Mode Switching
///
/// ```dart
/// // Toggle with F11
/// if (actions.justPressed(toggleFullscreen)) {
///   world.toggleFullscreen();
/// }
///
/// // Set specific mode
/// world.setWindowMode(WindowMode.borderless);
///
/// // Cycle through modes
/// world.cycleWindowMode();
/// ```
///
/// ## Listening to Events
///
/// ```dart
/// for (final event in world.eventReader<WindowModeChanged>().read()) {
///   print('Mode: ${event.previousMode} -> ${event.newMode}');
/// }
///
/// for (final event in world.eventReader<WindowResized>().read()) {
///   // Update camera viewport
/// }
///
/// for (final event in world.eventReader<WindowFocusChanged>().read()) {
///   if (!event.isFocused) {
///     // Pause game
///   }
/// }
/// ```
///
/// ## Querying State
///
/// ```dart
/// final state = world.windowState;
/// print('Mode: ${state?.mode}');
/// print('Size: ${state?.size}');
///
/// final info = world.displayInfo;
/// print('Primary: ${info?.primary.name}');
/// print('Resolution: ${info?.primary.size}');
/// ```
library fledge_window;

// Plugin
export 'src/plugin.dart';

// Config & Mode
export 'src/window_config.dart';
export 'src/window_mode.dart';

// Resources
export 'src/resources/window_state.dart';
export 'src/resources/display_info.dart';

// Events
export 'src/events/window_events.dart';

// Commands extension
export 'src/commands/window_commands.dart';

// Systems (for advanced use)
export 'src/systems/window_init_system.dart';
export 'src/systems/window_event_system.dart';
export 'src/systems/display_sync_system.dart';
