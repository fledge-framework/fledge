import 'package:fledge_ecs/fledge_ecs.dart';

import 'hot_reload.dart';

/// Plugin that gates optional native hot reload for asset stores.
///
/// The plugin does **not** insert any `Assets<T>` resources itself —
/// each downstream plugin (e.g. `RenderPlugin`, `AudioPlugin`,
/// `TiledPlugin`) owns the concrete type it needs and inserts the
/// per-type store when it builds. `AssetPlugin` only exists to (a)
/// register [HotReloadWatcher] as a resource so downstream code can
/// call `.watch(...)` on it and (b) install [HotReloadPollSystem] in
/// `Schedules.first` so queued reloads run early each tick.
///
/// ## Usage
///
/// ```dart
/// App()
///   .addPlugin(AssetPlugin(enableHotReload: true))
///   .addPlugin(RenderPlugin())
///   .addPlugin(AudioPlugin())
///   .run();
/// ```
///
/// Hot reload is a native-only convenience: on web the watcher's
/// `watch(...)` calls become no-ops (the underlying `package:watcher`
/// implementation is not available), which matches the framework's
/// desktop-primary stance.
class AssetPlugin implements Plugin {
  /// Whether to install [HotReloadWatcher] and [HotReloadPollSystem].
  ///
  /// Default false — production builds should leave it off; games
  /// enable it in dev builds.
  final bool enableHotReload;

  App? _app;

  AssetPlugin({this.enableHotReload = false});

  @override
  void build(App app) {
    _app = app;
    if (enableHotReload) {
      final watcher = HotReloadWatcher();
      app.insertResource(watcher);
      app.addSystem(HotReloadPollSystem(watcher), schedule: Schedules.first);
    }
  }

  @override
  void cleanup() {
    if (enableHotReload) {
      final watcher = _app?.world.getResource<HotReloadWatcher>();
      watcher?.dispose();
      _app?.world.removeResource<HotReloadWatcher>();
    }
    _app = null;
  }
}
