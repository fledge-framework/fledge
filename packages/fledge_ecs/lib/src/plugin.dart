import 'app.dart';

/// Base interface for plugins.
///
/// Plugins are modular units of functionality that can be added to an [App].
/// They encapsulate related systems, resources, and events.
///
/// ## Example
///
/// ```dart
/// class PhysicsPlugin implements Plugin {
///   @override
///   void build(App app) {
///     app
///       .insertResource(PhysicsConfig())
///       .addEvent<CollisionEvent>()
///       .addSystem(gravitySystem, schedule: Schedules.update)
///       .addSystem(collisionSystem, schedule: Schedules.postUpdate);
///   }
/// }
///
/// // Usage
/// App()
///   .addPlugin(PhysicsPlugin())
///   .run();
/// ```
abstract class Plugin {
  /// Configures the app with this plugin's functionality.
  ///
  /// Called once when the plugin is added via [App.addPlugin].
  void build(App app);

  /// Optional cleanup when the app is disposed.
  ///
  /// Called once, when [App.run] ends, on [App.dispose], or when
  /// [App.resetToSessionCheckpoint] removes a game-level plugin.
  void cleanup() {}
}

/// A plugin that groups other plugins.
///
/// Useful for creating plugin bundles or organizing related functionality.
///
/// ```dart
/// class DefaultPlugins extends PluginGroup {
///   @override
///   List<Plugin> get plugins => [
///     WallTimePlugin(),
///     InputPlugin(),
///     RenderPlugin(),
///   ];
/// }
/// ```
///
/// The group is the one entry in the app's plugin list: [build] builds each
/// child (in order) and [cleanup] cleans each child up (in reverse order),
/// once each. [plugins] is read once, on the first [build], so a getter
/// that creates fresh instances is fine: the same instances are rebuilt by
/// [App.resetToSessionCheckpoint] and cleaned up later.
abstract class PluginGroup implements Plugin {
  /// The plugins in this group.
  List<Plugin> get plugins;

  /// The children [build] built, kept so [cleanup] reaches the same
  /// instances.
  List<Plugin>? _built;

  @override
  void build(App app) {
    final children = _built ??= List.of(plugins);
    for (final plugin in children) {
      plugin.build(app);
    }
  }

  @override
  void cleanup() {
    final children = _built ?? plugins;
    _built = null;
    for (final plugin in children.reversed) {
      plugin.cleanup();
    }
  }
}

/// A simple plugin created from a function.
///
/// ```dart
/// final myPlugin = FunctionPlugin((app) {
///   app.insertResource(MyResource());
/// });
/// ```
class FunctionPlugin implements Plugin {
  final void Function(App app) _build;
  final void Function()? _cleanup;

  FunctionPlugin(this._build, {void Function()? cleanup}) : _cleanup = cleanup;

  @override
  void build(App app) => _build(app);

  @override
  void cleanup() => _cleanup?.call();
}
