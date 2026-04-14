import 'package:fledge_ecs/fledge_ecs.dart';

import 'config/save_config.dart';
import 'resources/save_manager.dart';
import 'traits/saveable.dart';

/// Plugin for save/load functionality.
///
/// Registers the [SaveManager] resource. Any resource that mixes in
/// [Saveable] and is inserted into the world is auto-discovered at save
/// time — no manual registration required.
///
/// ## Usage
///
/// ```dart
/// app.addPlugin(SavePlugin(
///   config: SaveConfig(
///     gameDirectory: 'MyGame',
///     formatVersion: 1,
///   ),
/// ));
///
/// // Saveable resources are auto-discovered from the world:
/// app.insertResource(Inventory());   // mixes in Saveable
/// app.insertResource(Progress());    // mixes in Saveable
///
/// // Manual registration is still supported for Saveable objects that
/// // aren't stored as world resources:
/// final savePlugin = SavePlugin();
/// savePlugin.registerSaveable(someOtherSaveableObject);
/// ```
class SavePlugin implements Plugin {
  /// Configuration for save behavior.
  final SaveConfig config;

  /// Registered saveable resources.
  final List<Saveable> _saveables = [];

  /// Creates a save plugin with optional configuration.
  SavePlugin({this.config = const SaveConfig.defaults()});

  /// The save manager resource.
  SaveManager? _saveManager;

  /// Get the save manager.
  SaveManager? get saveManager => _saveManager;

  /// Register a saveable resource.
  ///
  /// Call this after inserting saveable resources into the world.
  /// The save manager will include these resources when saving.
  void registerSaveable(Saveable saveable) {
    if (!_saveables.contains(saveable)) {
      _saveables.add(saveable);
    }
  }

  /// Unregister a saveable resource.
  void unregisterSaveable(Saveable saveable) {
    _saveables.remove(saveable);
  }

  /// Get all registered saveables.
  List<Saveable> get saveables => List.unmodifiable(_saveables);

  @override
  void build(App app) {
    // Create and insert save manager
    _saveManager = SaveManagerWithSaveables(
      config: config,
      getSaveables: () => _saveables,
    );
    app.insertResource(_saveManager!);
  }

  @override
  void cleanup() {
    _saveables.clear();
    _saveManager = null;
  }
}

/// SaveManager that merges auto-discovered [Saveable] resources in the
/// world with any explicitly registered via [SavePlugin.registerSaveable].
///
/// Auto-discovery handles the common case (a resource mixes in `Saveable`
/// and is inserted into the world). Manual registration is kept for
/// objects that aren't stored as world resources — e.g. a singleton owned
/// by the plugin itself.
class SaveManagerWithSaveables extends SaveManager {
  final List<Saveable> Function() _getSaveables;

  SaveManagerWithSaveables({
    required super.config,
    required List<Saveable> Function() getSaveables,
  }) : _getSaveables = getSaveables;

  @override
  Iterable<Saveable> getSaveableResources(World world) {
    final seen = <Saveable>{};
    final out = <Saveable>[];
    for (final s in world.resourcesOfType<Saveable>()) {
      if (seen.add(s)) out.add(s);
    }
    for (final s in _getSaveables()) {
      if (seen.add(s)) out.add(s);
    }
    return out;
  }
}
