/// Save/load system for Fledge games.
///
/// Provides a generic save system that aggregates state from multiple
/// resources and handles file I/O with version migration support.
///
/// ## Quick Start
///
/// 1. Add the plugin to your app:
/// ```dart
/// app.addPlugin(SavePlugin(
///   config: SaveConfig(
///     gameDirectory: 'MyGame',
///     formatVersion: 1,
///   ),
/// ));
/// ```
///
/// 2. Make resources saveable by implementing [Saveable]:
/// ```dart
/// class Inventory with Saveable {
///   final List<Item> items = [];
///
///   @override
///   String get saveKey => 'inventory';
///
///   @override
///   Map<String, dynamic> toSaveJson() => {
///     'items': items.map((i) => i.toJson()).toList(),
///   };
///
///   @override
///   void loadFromSaveJson(Map<String, dynamic> json) {
///     items.clear();
///     final itemsJson = json['items'] as List<dynamic>? ?? [];
///     items.addAll(itemsJson.map((j) => Item.fromJson(j)));
///   }
/// }
/// ```
///
/// 3. Register saveables with the plugin:
/// ```dart
/// final savePlugin = app.getPlugin<SavePlugin>();
/// savePlugin.registerSaveable(world.getResource<Inventory>()!);
/// ```
///
/// 4. Request saves from ECS systems:
/// ```dart
/// final saveManager = world.getResource<SaveManager>();
/// saveManager?.requestSave(metadata: {'playerX': x, 'playerY': y});
/// ```
///
/// 5. Handle save requests in Flutter:
/// ```dart
/// if (saveManager.saveRequested) {
///   final metadata = saveManager.pendingMetadata;
///   saveManager.clearSaveRequest();
///   await saveManager.save(world, metadata: metadata);
/// }
/// ```
///
/// ## Save File Structure
///
/// Saves are stored as JSON in the app documents directory:
/// ```
/// Documents/
///   MyGame/
///     save.json        # Default slot
///     slot1.json       # Named slot
///     slot2.json
/// ```
///
/// Each save contains:
/// ```json
/// {
///   "version": 1,
///   "timestamp": "2024-01-15T10:30:00.000Z",
///   "metadata": { "playerX": 100, "playerY": 200 },
///   "resources": {
///     "inventory": { ... },
///     "progress": { ... }
///   }
/// }
/// ```
library;

// Plugin
export 'src/plugin.dart';

// Config
export 'src/config/save_config.dart';

// Resources
export 'src/resources/save_manager.dart' hide SaveableWorldExtension;

// Traits
export 'src/traits/saveable.dart';
