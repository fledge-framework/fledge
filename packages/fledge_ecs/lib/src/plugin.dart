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
///       .addSystem(gravitySystem, stage: CoreStage.update)
///       .addSystem(collisionSystem, stage: CoreStage.postUpdate);
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
///     TimePlugin(),
///     InputPlugin(),
///     RenderPlugin(),
///   ];
/// }
/// ```
abstract class PluginGroup implements Plugin {
  /// The plugins in this group.
  List<Plugin> get plugins;

  @override
  void build(App app) {
    for (final plugin in plugins) {
      app.addPlugin(plugin);
    }
  }

  @override
  void cleanup() {
    for (final plugin in plugins) {
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
