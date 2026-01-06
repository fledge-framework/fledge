import 'package:fledge_ecs/fledge_ecs.dart';

import 'config/save_config.dart';
import 'resources/save_manager.dart';
import 'traits/saveable.dart';

/// Plugin for save/load functionality.
///
/// Registers the [SaveManager] resource and provides methods to
/// register saveable resources.
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
/// // Register saveable resources
/// final savePlugin = app.getPlugin<SavePlugin>();
/// savePlugin.registerSaveable(world.getResource<Inventory>()!);
/// savePlugin.registerSaveable(world.getResource<Progress>()!);
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

/// SaveManager that uses plugin-registered saveables.
class SaveManagerWithSaveables extends SaveManager {
  final List<Saveable> Function() _getSaveables;

  SaveManagerWithSaveables({
    required super.config,
    required List<Saveable> Function() getSaveables,
  }) : _getSaveables = getSaveables;

  @override
  Iterable<Saveable> getSaveableResources(World world) {
    return _getSaveables();
  }
}
