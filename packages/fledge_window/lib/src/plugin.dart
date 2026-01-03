import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart';

import 'events/window_events.dart';
import 'resources/display_info.dart';
import 'resources/window_state.dart';
import 'systems/display_sync_system.dart';
import 'systems/window_event_system.dart';
import 'systems/window_init_system.dart';
import 'window_config.dart';

/// Plugin that adds window management to a Fledge app.
///
/// Provides fullscreen, borderless, and windowed modes with runtime switching.
///
/// ## Quick Start
///
/// ```dart
/// // Fullscreen game
/// await App()
///   .addPlugin(WindowPlugin.fullscreen(title: 'My Game'))
///   .run();
///
/// // Borderless windowed
/// await App()
///   .addPlugin(WindowPlugin.borderless(title: 'My Game'))
///   .run();
///
/// // Custom windowed
/// await App()
///   .addPlugin(WindowPlugin(config: WindowConfig(
///     mode: WindowMode.windowed,
///     title: 'My Game',
///     windowedSize: Size(1920, 1080),
///   )))
///   .run();
/// ```
///
/// ## Changing Window Mode at Runtime
///
/// ```dart
/// // Toggle fullscreen with F11
/// if (actions.justPressed(toggleFullscreen)) {
///   world.toggleFullscreen();
/// }
///
/// // Or set a specific mode
/// world.setWindowMode(WindowMode.borderless);
/// ```
///
/// ## Listening to Window Events
///
/// ```dart
/// for (final event in world.readEvents<WindowModeChanged>()) {
///   print('Mode: ${event.previousMode} -> ${event.newMode}');
/// }
/// ```
///
/// ## Querying Window State
///
/// ```dart
/// final state = world.windowState;
/// print('Mode: ${state?.mode}');
/// print('Size: ${state?.size}');
/// print('Display: ${world.displayInfo?.primary.name}');
/// ```
class WindowPlugin implements Plugin {
  /// Window configuration.
  final WindowConfig config;

  /// Creates a window plugin with custom configuration.
  const WindowPlugin({this.config = const WindowConfig()});

  /// Creates a fullscreen window plugin.
  ///
  /// This is equivalent to:
  /// ```dart
  /// WindowPlugin(config: WindowConfig.fullscreen(title: title))
  /// ```
  const WindowPlugin.fullscreen({String title = 'Fledge Game'})
      : config = const WindowConfig.fullscreen();

  /// Creates a borderless windowed plugin.
  ///
  /// This is equivalent to:
  /// ```dart
  /// WindowPlugin(config: WindowConfig.borderless(title: title))
  /// ```
  const WindowPlugin.borderless({String title = 'Fledge Game'})
      : config = const WindowConfig.borderless();

  /// Creates a windowed plugin with optional size.
  factory WindowPlugin.windowed({
    String title = 'Fledge Game',
    Size? size,
    Size? minSize,
    Size? maxSize,
  }) {
    return WindowPlugin(
      config: WindowConfig.windowed(
        title: title,
        size: size,
        minSize: minSize,
        maxSize: maxSize,
      ),
    );
  }

  @override
  void build(App app) {
    // Register events
    app
        .addEvent<WindowModeChanged>()
        .addEvent<WindowResized>()
        .addEvent<WindowFocusChanged>()
        .addEvent<WindowMoved>()
        .addEvent<SetWindowModeRequest>()
        .addEvent<SetWindowSizeRequest>()
        .addEvent<SetWindowPositionRequest>();

    // Insert resources
    app
        .insertResource(WindowState.initial(config))
        .insertResource(DisplayInfo.empty());

    // Add systems
    // Init runs first and only once
    app.addSystem(WindowInitSystem(config), stage: CoreStage.first);

    // Display sync runs periodically
    app.addSystem(DisplaySyncSystem(), stage: CoreStage.first);

    // Event handler processes mode/size change requests
    app.addSystem(WindowEventSystem(), stage: CoreStage.first);
  }

  @override
  void cleanup() {
    // Resources are garbage collected with the world
  }
}
